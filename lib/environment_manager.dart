import 'dart:io';
import 'dart:typed_data';
import 'dart:isolate';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter/services.dart';
import 'path_provider_native.dart';

/// Manages the Debian rootfs environment and proot setup
class EnvironmentManager {
  static const String _setupFlagFile = '.prominal_setup_complete';
  static const String _rootfsArchive = 'debian-bookworm-aarch64.tar.xz';
  static const String _prootBinary = 'proot-v5.3.0-aarch64-static';
  
  late final String _appDataPath;
  late final String _usrPath;
  late final String _homePath;
  late final String _prootPath;
  late final String _libPath;
  late final String _tmpPath;
  
  EnvironmentManager._();
  
  /// Initialize the environment manager
  static Future<EnvironmentManager> init() async {
    final instance = EnvironmentManager._();
    await instance._initializePaths();
    return instance;
  }
  
  /// Initialize all necessary paths
  Future<void> _initializePaths() async {
    // Use our native implementation to get application support directory
    final appSupportDir = await PathProviderNative.getApplicationSupportDirectoryAsync();
    // Avoid resolveSymbolicLinks on Android; keep the real internal path.
    _appDataPath = appSupportDir;
    // Place executable proot in code_cache which is more permissive for exec
    final execBase = await PathProviderNative.getExecutableCacheDirectoryAsync();
    _usrPath = '${_appDataPath}/usr';
    _homePath = '${_appDataPath}/home';
    _prootPath = '$execBase/proot';
    _libPath = '${_appDataPath}/lib';
    _tmpPath = '${_appDataPath}/tmp';
    
    // Create necessary directories
    await _createDirectories();
    print('EnvironmentManager: Paths initialized: app=$_appDataPath usr=$_usrPath home=$_homePath proot=$_prootPath lib=$_libPath tmp=$_tmpPath');
  }
  
  /// Create necessary directories
  Future<void> _createDirectories() async {
    final dirs = [_usrPath, _homePath, _prootPath, _libPath, _tmpPath];
    for (final dir in dirs) {
      final directory = Directory(dir);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
    }
  }
  
  /// Check if the environment setup is complete
  bool isSetupComplete() {
    // Android arm64 requires a one-time proot/rootfs setup.
    if (!Platform.isAndroid) {
      return true;
    }
    final setupFlag = File('${_appDataPath}/$_setupFlagFile');
    final flagExists = setupFlag.existsSync();
    // Consider setup incomplete if rootfs core bin directory is missing
    final hasRootfs = Directory('${_usrPath}/bin').existsSync();
    if (_isArm64DeviceSync()) {
      return flagExists && hasRootfs;
    }
    // Non-arm64 Android devices use host shell; no rootfs needed
    return true;
  }
  
  /// Get the home path for terminal sessions
  String get homePath => _homePath;
  
  /// Get the usr path (rootfs location)
  String get usrPath => _usrPath;
  
  /// Get the proot path
  String get prootPath => _prootPath;
  
  /// Get the lib path
  String get libPath => _libPath;
  
  /// Setup the complete environment
  Future<void> setupEnvironment() async {
    // Only Android arm64 needs the proot/rootfs bootstrap. Skip on desktop and non-arm64 Android.
    if (!Platform.isAndroid) {
      print('EnvironmentManager: Non-Android platform, skipping proot setup');
      return;
    }
    if (!_isArm64DeviceSync()) {
      print('EnvironmentManager: Non-arm64 Android device detected; skipping proot/rootfs setup');
      await _createSetupFlag();
      return;
    }

    print('EnvironmentManager: Starting environment setup...');
    try {
      await _extractProotAndLibs();
      await _extractRootfsInBackground();
      await _setupPermissions();
      await _createSetupFlag();
      // Validate rootfs was extracted
      final hasRootfs = Directory('${_usrPath}/bin').existsSync();
      if (!hasRootfs) {
        throw Exception('Rootfs extraction did not complete: ${_usrPath}/bin missing');
      }
      print('EnvironmentManager: Environment setup completed successfully');
    } catch (e) {
      print('EnvironmentManager: Setup failed: $e');
      rethrow;
    }
  }
  
  /// Extract proot binary and required libraries
  Future<void> _extractProotAndLibs() async {
    print('EnvironmentManager: Extracting proot and libraries...');
    
    // List of files to extract from assets
    final filesToExtract = [
      _prootBinary,
      'ld-linux-aarch64.so.1',
      'libanl.so.1',
      'libBrokenLocale.so.1',
      'libc.so.6',
      'libtalloc.so.2',
      'libtalloc.so.2.4.2',
      'loader',
      'loader32',
    ];
    
    for (final fileName in filesToExtract) {
      try {
        final bytes = await rootBundle.load('assets/$fileName');
        final file = File('${_prootPath}/$fileName');
        await file.writeAsBytes(bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
        
        // Make executable if it's the proot binary
        if (fileName == _prootBinary || fileName == 'loader' || fileName == 'loader32') {
          try {
            await Process.run('chmod', ['700', file.path]);
          } catch (e) {
            print('EnvironmentManager: chmod on proot failed: $e');
          }
        }
        
        print('EnvironmentManager: Extracted $fileName');
      } catch (e) {
        print('EnvironmentManager: Failed to extract $fileName: $e');
        rethrow;
      }
    }
    // Print ls -l for proot dir to debug permissions
    try {
      final listing = await Process.run('sh', ['-c', 'ls -l ${_prootPath} | sed -n "1,120p"']);
      print('EnvironmentManager: proot dir listing exit=${listing.exitCode}\n${listing.stdout}');
    } catch (e) {
      print('EnvironmentManager: Failed to list proot dir: $e');
    }
  }
  
  /// Extract the Debian rootfs archive in a background thread
  Future<void> _extractRootfsInBackground() async {
    print('EnvironmentManager: Extracting Debian rootfs in background...');
    
    // Load the asset data in the main thread first
    final bytes = await rootBundle.load('assets/$_rootfsArchive');
    final archiveBytes = bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
    
    // Use compute to run heavy extraction in background
    await compute(_extractRootfsIsolate, {
      'archiveBytes': archiveBytes,
      'usrPath': _usrPath,
    });
    
    print('EnvironmentManager: Rootfs extraction completed');
  }
  
  /// Static method for isolate to extract rootfs
  static Future<void> _extractRootfsIsolate(Map<String, dynamic> params) async {
    final archiveBytes = params['archiveBytes'] as Uint8List;
    final usrPath = params['usrPath'] as String;
    
    try {
      // Decompress XZ using the archive package
      final decompressed = XZDecoder().decodeBytes(archiveBytes);
      
      // Extract TAR
      final archive = TarDecoder().decodeBytes(decompressed);
      
      // Extract files to usr directory
      int fileCount = 0;
      for (final file in archive) {
        if (file.isFile) {
          final filePath = '$usrPath/${file.name}';
          final fileDir = Directory(filePath.substring(0, filePath.lastIndexOf('/')));
          
          if (!await fileDir.exists()) {
            await fileDir.create(recursive: true);
          }
          
          final fileFile = File(filePath);
          await fileFile.writeAsBytes(file.content as List<int>);
          
          // Set executable bit if the file is executable in the tar entry
          final mode = file.mode;
          if (mode != null && (mode & 0x49) != 0) { // 0x49 = 0o111 (any execute bit)
            try {
              await Process.run('chmod', ['+x', fileFile.path]);
            } catch (e) {
              // Ignore errors here
            }
          }
          
          fileCount++;
          if (fileCount % 100 == 0) {
            print('EnvironmentManager: Extracted $fileCount files...');
          }
        }
      }
      
      print('EnvironmentManager: Extracted $fileCount files total');
    } catch (e) {
      print('EnvironmentManager: Rootfs extraction failed: $e');
      rethrow;
    }
  }
  
  /// Set up proper permissions for the environment
  Future<void> _setupPermissions() async {
    print('EnvironmentManager: Setting up permissions...');
    
    try {
      // Make proot executable - try multiple approaches for Android compatibility
      final prootFile = File('${_prootPath}/$_prootBinary');
      if (await prootFile.exists()) {
        bool permissionsOk = false;
        
        // Method 1: Try chmod
        try {
          final result = await Process.run('chmod', ['700', prootFile.path]);
          if (result.exitCode == 0) {
            print('EnvironmentManager: Set proot binary permissions using chmod');
            permissionsOk = true;
          }
        } catch (e) {
          print('EnvironmentManager: chmod failed: $e');
        }

        // Print mount exec context for debugging
        try {
          final ctx = await Process.run('sh', ['-c', 'mount | head -n 20']);
          print('EnvironmentManager: mount output (first 20 lines):\n${ctx.stdout}');
        } catch (_) {}
        
        // Method 2: Test if the binary actually works
        if (permissionsOk) {
          try {
            final testResult = await Process.run(prootFile.path, ['--help']);
            if (testResult.exitCode == 0 || testResult.exitCode == 1) {
              print('EnvironmentManager: Proot binary is working correctly');
            } else {
              print('EnvironmentManager: Warning - proot binary test failed with exit code: ${testResult.exitCode}');
              permissionsOk = false;
            }
          } catch (e) {
            print('EnvironmentManager: Proot binary test failed: $e');
            permissionsOk = false;
          }
        }
        
        if (!permissionsOk) {
          print('EnvironmentManager: Warning - proot binary permissions may not be set correctly');
          // Try shell execution as fallback
          try {
            final shTest = await Process.run('sh', ['-c', '${prootFile.path} --help']);
            print('EnvironmentManager: Shell exec test exit=${shTest.exitCode}');
          } catch (e) {
            print('EnvironmentManager: Shell exec test failed: $e');
          }
        }
      }
      
      // Set up basic home directory structure
      final homeDir = Directory(_homePath);
      if (!await homeDir.exists()) {
        await homeDir.create(recursive: true);
      }

      // Ensure common rootfs bin directories have exec bits for user
      try {
        final cmd = 'chmod -R u+rx ${_usrPath}/bin ${_usrPath}/usr/bin ${_usrPath}/usr/sbin ${_usrPath}/sbin 2>/dev/null || true';
        final res = await Process.run('sh', ['-c', cmd]);
        print('EnvironmentManager: Ensured exec bits on rootfs bins (exit ${res.exitCode})');
      } catch (e) {
        print('EnvironmentManager: chmod rootfs bins failed: $e (non-fatal)');
      }
      
      print('EnvironmentManager: Permissions setup completed');
    } catch (e) {
      print('EnvironmentManager: Permission setup failed: $e');
      // Don't rethrow as this is not critical
    }
  }
  
  /// Create setup completion flag
  Future<void> _createSetupFlag() async {
    final flagFile = File('${_appDataPath}/$_setupFlagFile');
    await flagFile.writeAsString('Setup completed at ${DateTime.now().toIso8601String()}');
  }
  
  /// Get the initial command for the interactive shell
  List<String> getInitialCommand() {
    // On Android, launch the Debian environment via proot.
    if (Platform.isAndroid) {
      if (_isArm64DeviceSync()) {
        // Print debug info about proot paths
        print('EnvironmentManager: Initial proot cmd will use ${_prootPath}/$_prootBinary');
        return getProotCommandWithFallback(
          rootfsPath: _usrPath,
          shellPath: '/bin/bash',
          shellArgs: ['--login'],
        );
      }
      // Fallback: host Android shell on non-arm64 devices/emulators.
      return ['/system/bin/sh'];
    }

    // On desktop platforms, launch the host system shell directly.
    if (Platform.isWindows) {
      // Prefer PowerShell if available, otherwise fallback to cmd
      return ['powershell.exe'];
    }

    // macOS/Linux/iOS default to a POSIX shell
    final String shellPath = File('/bin/zsh').existsSync()
        ? '/bin/zsh'
        : (File('/bin/bash').existsSync() ? '/bin/bash' : '/bin/sh');
    return [shellPath, '--login'];
  }

  /// Best-effort synchronous detection of arm64 on Android
  static bool _isArm64DeviceSync() {
    if (!Platform.isAndroid) return false;
    try {
      final abi = Process.runSync('getprop', ['ro.product.cpu.abi']);
      final out = (abi.stdout is String) ? (abi.stdout as String).toLowerCase().trim() : '';
      if (out.contains('arm64') || out.contains('aarch64')) return true;
    } catch (_) {}
    try {
      final abis = Process.runSync('getprop', ['ro.product.cpu.abilist']);
      final out = (abis.stdout is String) ? (abis.stdout as String).toLowerCase() : '';
      if (out.contains('arm64') || out.contains('aarch64')) return true;
    } catch (_) {}
    try {
      final u = Process.runSync('uname', ['-m']);
      final out = (u.stdout is String) ? (u.stdout as String).toLowerCase().trim() : '';
      if (out.contains('aarch64') || out.contains('arm64')) return true;
    } catch (_) {}
    return false;
  }
  
  /// Get proot command with fallback options
  List<String> getProotCommandWithFallback({
    required String rootfsPath,
    required String shellPath,
    List<String> shellArgs = const [],
  }) {
    final prootBinary = '${_prootPath}/$_prootBinary';
    // On some Android versions, direct exec may be blocked. We'll still try direct,
    // and the session manager will fall back to `sh -lc` if exec fails.
    
    // Build the proot command
    final command = [
      prootBinary,
      '-S', rootfsPath,
      '-0',
      '-w', '/',
      '-b', '/dev',
      '-b', '/proc',
      '-b', '/sys',
      '-b', '$_tmpPath:/tmp',
      '-b', '/data',
      '-b', '/storage',
      '-b', '/sdcard',
      '-b', '/mnt',
      '-b', '${_homePath}:/home',
      '-b', '${_libPath}:/lib',
      '-b', '${_prootPath}:/proot',
      shellPath,
      ...shellArgs,
    ];
    
    return command;
  }
  
  /// Get environment variables for proot
  Map<String, String> getProotEnvironment() {
    return {
      'HOME': '/home',
      'PATH': '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/bin:/usr/bin',
      'TERM': 'xterm-256color',
      'LANG': 'en_US.UTF-8',
      'LC_ALL': 'en_US.UTF-8',
      'LD_LIBRARY_PATH': '/lib:/usr/lib',
      'PROOT_NO_SECCOMP': '1',
      'PROOT_LOADER': '/proot/loader',
      'PROOT_LOADER32': '/proot/loader32',
      'PROOT_TMP_DIR': '/tmp',
      // Unset LD_PRELOAD by setting it to empty
      'LD_PRELOAD': '',
      'PROMINAL_DEBUG': '1',
    };
  }
  
  /// Reset the environment (for troubleshooting)
  Future<void> resetEnvironment() async {
    print('EnvironmentManager: Resetting environment...');
    
    try {
      // Remove setup flag
      final flagFile = File('${_appDataPath}/$_setupFlagFile');
      if (await flagFile.exists()) {
        await flagFile.delete();
      }
      
      // Remove extracted directories
      final dirsToRemove = [_usrPath, _prootPath, _libPath];
      for (final dir in dirsToRemove) {
        final directory = Directory(dir);
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      }
      
      // Recreate directories
      await _createDirectories();
      
      print('EnvironmentManager: Environment reset completed');
    } catch (e) {
      print('EnvironmentManager: Reset failed: $e');
      rethrow;
    }
  }

  /// Ensure rootfs exists; if missing, clear setup flag so setup restarts
  Future<void> ensureRootfsOrClearFlag() async {
    try {
      final hasRootfs = Directory('${_usrPath}/bin').existsSync();
      if (!hasRootfs) {
        final flagFile = File('${_appDataPath}/$_setupFlagFile');
        if (await flagFile.exists()) {
          await flagFile.delete();
          print('EnvironmentManager: Cleared setup flag due to missing rootfs; setup will run again.');
        }
      }
    } catch (e) {
      print('EnvironmentManager: ensureRootfsOrClearFlag error: $e');
    }
  }
  
  /// Test if proot can be executed using system shell
  Future<bool> testProotWithShell() async {
    print('EnvironmentManager: Testing proot with system shell...');
    
    try {
      final prootFile = File('${_prootPath}/$_prootBinary');
      if (!await prootFile.exists()) {
        print('EnvironmentManager: Proot binary not found');
        return false;
      }
      
      // Try running proot through the system shell
      final result = await Process.run('sh', ['-c', '${prootFile.path} --help']);
      
      print('EnvironmentManager: Shell test result - exit code: ${result.exitCode}');
      if (result.exitCode == 0 || result.exitCode == 1) {
        print('EnvironmentManager: Proot works through shell');
        return true;
      } else {
        print('EnvironmentManager: Proot shell test failed');
        return false;
      }
    } catch (e) {
      print('EnvironmentManager: Proot shell test error: $e');
      return false;
    }
  }
  
  /// Manually fix permissions for the proot binary
  Future<bool> fixProotPermissions() async {
    print('EnvironmentManager: Manually fixing proot permissions...');
    
    try {
      final prootFile = File('${_prootPath}/$_prootBinary');
      if (!await prootFile.exists()) {
        print('EnvironmentManager: Proot binary not found');
        return false;
      }
      
      // Try multiple approaches to make it executable
      bool success = false;
      
      // Method 1: chmod
      try {
        final result = await Process.run('chmod', ['700', prootFile.path]);
        if (result.exitCode == 0) {
          print('EnvironmentManager: Successfully set permissions with chmod');
          success = true;
        }
      } catch (e) {
        print('EnvironmentManager: chmod failed: $e');
      }
      
      // Method 2: Test if it's already executable
      if (!success) {
        try {
          final testResult = await Process.run(prootFile.path, ['--help']);
          if (testResult.exitCode == 0 || testResult.exitCode == 1) {
            print('EnvironmentManager: Proot binary is already executable');
            success = true;
          }
        } catch (e) {
          print('EnvironmentManager: Proot binary test failed: $e');
        }
      }
      
      return success;
    } catch (e) {
      print('EnvironmentManager: Permission fix failed: $e');
      return false;
    }
  }
  
  /// Get environment status information
  Map<String, dynamic> getEnvironmentStatus() {
    return {
      'setupComplete': isSetupComplete(),
      'appDataPath': _appDataPath,
      'usrPath': _usrPath,
      'homePath': _homePath,
      'prootPath': _prootPath,
      'libPath': _libPath,
      'prootBinaryExists': File('${_prootPath}/$_prootBinary').existsSync(),
      'rootfsExists': Directory('${_usrPath}/bin').existsSync(),
    };
  }
}