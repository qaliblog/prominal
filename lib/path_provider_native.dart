import 'dart:io';
import 'dart:async';

/// Pure Dart implementation of path provider functionality
class PathProviderNative {
  /// Get the application support directory path for the current platform
  static String getApplicationSupportDirectory() {
    if (Platform.isAndroid) {
      // Android: Use external storage or internal app directory
      final externalStorage = Platform.environment['EXTERNAL_STORAGE'];
      if (externalStorage != null) {
        return '$externalStorage/Android/data/com.prominal.app/files';
      } else {
        // Fallback to internal storage
        return '/data/data/com.prominal.app/files';
      }
    } else if (Platform.isIOS) {
      // iOS: Use app's Documents directory
      final home = Platform.environment['HOME'];
      if (home != null) {
        return '$home/Documents';
      } else {
        return '/tmp/prominal';
      }
    } else if (Platform.isWindows) {
      // Windows: Use APPDATA environment variable
      final appData = Platform.environment['APPDATA'];
      if (appData != null) {
        return '$appData\\Prominal';
      } else {
        return 'C:\\Users\\${Platform.environment['USERNAME'] ?? 'User'}\\AppData\\Roaming\\Prominal';
      }
    } else if (Platform.isMacOS) {
      // macOS: Use standard app support directory
      final home = Platform.environment['HOME'];
      if (home != null) {
        return '$home/Library/Application Support/Prominal';
      } else {
        return '/tmp/prominal';
      }
    } else if (Platform.isLinux) {
      // Linux: Use XDG_DATA_HOME or fallback to ~/.local/share
      final xdgDataHome = Platform.environment['XDG_DATA_HOME'];
      if (xdgDataHome != null) {
        return '$xdgDataHome/prominal';
      } else {
        final home = Platform.environment['HOME'];
        if (home != null) {
          return '$home/.local/share/prominal';
        } else {
          return '/tmp/prominal';
        }
      }
    } else {
      // Fallback for other platforms
      return '/tmp/prominal';
    }
  }

  /// Create the directory if it doesn't exist
  static Future<void> ensureDirectoryExists() async {
    final path = getApplicationSupportDirectory();
    final directory = Directory(path);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
  }

  /// Get the application support directory and ensure it exists
  static Future<String> getApplicationSupportDirectoryAsync() async {
    final path = getApplicationSupportDirectory();
    await ensureDirectoryExists();
    return path;
  }
} 