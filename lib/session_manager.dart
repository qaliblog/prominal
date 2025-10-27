import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:xterm/xterm.dart';
import 'package:prominal/environment_manager.dart';
import 'pty_adapter.dart';

/// A data class to hold all components of a single terminal session.
class TerminalSession {
  final int id;
  final Terminal terminal;
  final PlatformPty pty;
  String title;

  TerminalSession({
    required this.id,
    required this.terminal,
    required this.pty,
    required this.title,
  });
}

/// A singleton class that manages all active terminal sessions.
class SessionManager extends ChangeNotifier {
  // --- Singleton Setup ---
  SessionManager._();
  static final SessionManager instance = SessionManager._();

  // --- State ---
  late EnvironmentManager _envManager;
  final List<TerminalSession> _sessions = [];
  int _nextSessionId = 1;
  int _activeSessionIndex = -1;

  // --- Public Accessors ---
  List<TerminalSession> get sessions => List.unmodifiable(_sessions);
  TerminalSession? get activeSession =>
      _activeSessionIndex != -1 ? _sessions[_activeSessionIndex] : null;
  bool get hasSessions => _sessions.isNotEmpty;

  void initialize(EnvironmentManager envManager) {
    _envManager = envManager;
  }

  Future<void> createNewSession({
    required List<String> command,
    String? workingDirectory,
    String? title,
  }) async {
    print("SessionManager: Creating session with command: ${command.join(' ')}");
    // Detailed environment diagnostics
    try {
      print("SessionManager: Platform: ${Platform.operatingSystem} ${Platform.version}");
      print("SessionManager: HOME: ${Platform.environment['HOME']}");
      print("SessionManager: USER: ${Platform.environment['USER']}");
      print("SessionManager: PATH: ${Platform.environment['PATH']}");
    } catch (_) {}
    
    // If the first command is proot on Android, run via shell to avoid exec restrictions
    List<String> actualCommand = command;
    if (command.isNotEmpty && command.first.contains('proot')) {
      print("SessionManager: Detected proot invocation");
      if (Platform.isAndroid) {
        final joined = command.join(' ');
        actualCommand = ['sh', '-lc', joined];
        print("SessionManager: Routing proot via shell: ${actualCommand.join(' ')}");
      } else {
        print("SessionManager: Attempting proot session with direct execution");
      }
    }
    
    final bool isProotInvocation = command.isNotEmpty && command.first.contains('proot');

    // Environment differs on Android vs desktop
    final Map<String, String> env = Platform.isAndroid
        ? (isProotInvocation
            ? _envManager.getProotEnvironment()
            : {
                'TERM': 'xterm-256color',
                'HOME': _envManager.homePath,
                'PREFIX': _envManager.usrPath,
                'PATH': '${_envManager.usrPath}/bin:/system/bin',
                'LD_LIBRARY_PATH': '${_envManager.usrPath}/lib',
                'PROMINAL_VERSION': '1.0',
                'LANG': 'en_US.UTF-8',
              })
        : {
            ...Platform.environment,
            'TERM': 'xterm-256color',
          };

    // Working directory sensible default
    final String cwd = workingDirectory ??
        (Platform.isWindows
            ? (Platform.environment['USERPROFILE'] ?? _envManager.homePath)
            : (Platform.environment['HOME'] ?? _envManager.homePath));
    
    late final PlatformPty pty;
    try {
      pty = await startPlatformPty(
        actualCommand.first,
        actualCommand.length > 1 ? actualCommand.sublist(1) : [],
        workingDirectory: cwd,
        environment: env,
      );
    } catch (error) {
      print("SessionManager: PTY start failed: ${error}");
      // If direct exec fails with permission issues and we're invoking proot, try shell fallback immediately
      if (isProotInvocation) {
        await _createProotSessionWithShell(command);
        return;
      }
      rethrow;
    }

    final terminal = Terminal(maxLines: 10000);
    terminal.write('Prominal: starting session...\r\n');

    // Decode the PTY's byte output into a String for the terminal.
    pty.out
        .cast<List<int>>()
        .transform(const Utf8Decoder())
        .listen((data) {
          print("SessionManager: Received output: ${data}");
          terminal.write(data);
        }, onError: (error) {
          print("SessionManager: Output error: ${error}");
        });

    // Encode the terminal's String output into bytes for the PTY.
    terminal.onOutput = (data) {
      print("SessionManager: Sending input: ${data}");
      pty.write(data);
    };

    terminal.onResize = (w, h, pw, ph) {
      print('SessionManager: resize to cols=$w rows=$h');
      pty.resize(h, w);
    };

    final sessionId = _nextSessionId++;
    final session = TerminalSession(
      id: sessionId,
      terminal: terminal,
      pty: pty,
      title: title ?? 'Session ${sessionId}',
    );

    pty.exitCode.then((code) async {
      print("SessionManager: Session ${sessionId} exited with code: ${code}");
      if (code == 126) {
        print("SessionManager: Exit 126 indicates permission problem (exec). Consider shell fallback.");
      }
      final index = _sessions.indexWhere((s) => s.id == sessionId);
      if (index != -1) {
        final session = _sessions[index];
        session.terminal
            .write('\r\n\r\n[Process completed with exit code: ${code}]\r\n');
        // If there was no visible output, show command and env summary for debugging
        session.terminal.write('Command: ${actualCommand.join(' ')}\r\n');
        session.terminal.write('Env: TERM=${env['TERM']} HOME=${env['HOME']}\r\n');
        session.title = '[Exited ${code}] ${session.title}';
        notifyListeners();
      }
      
      // If proot failed with permission denied or transport errors, try shell approach
      if ((code == -117 || code == 126 || code == -6 || code == -120 || code == -121) && command.first.contains('proot')) {
        print("SessionManager: Proot failed, trying shell approach...");
        await Future.delayed(const Duration(milliseconds: 400));
        await _createProotSessionWithShell(command);
        return;
      }
      // If all else fails or quick-exit persists, try host Android shell as last resort
      if ((code == -120 || code == -121 || code == 126) && Platform.isAndroid) {
        print('SessionManager: Falling back to host Android shell');
        await Future.delayed(const Duration(milliseconds: 300));
        await createNewSession(
          command: _envManager.getAndroidHostShellCommand(),
          title: 'Android Shell',
        );
        return;
      }
      // If login shell exits immediately, try a simpler /bin/sh
      if ((code == 0 || code == 1) && (title == null || title == 'Shell')) {
        print('SessionManager: Login shell exited quickly; trying /bin/sh -l');
        await Future.delayed(const Duration(milliseconds: 300));
        await createNewSession(
          command: _envManager.getProotCommandWithFallback(
            rootfsPath: _envManager.getComputedRootfsPath(),
            shellPath: '/bin/sh',
            shellArgs: ['-l'],
          ),
          title: 'Shell (sh)',
        );
      }
    }).catchError((error) {
      print("SessionManager: Session ${sessionId} error: ${error}");
    });

    _sessions.add(session);
    _activeSessionIndex = _sessions.length - 1;

    print("Created new session (ID: ${sessionId}) with command: ${actualCommand.join(' ')}");
    terminal.write('Command: ${actualCommand.join(' ')}\r\nWorkingDir: ${cwd}\r\n');
    notifyListeners();
  }
  
  /// Create a proot session using shell as fallback
  Future<void> _createProotSessionWithShell(List<String> originalCommand) async {
    print("SessionManager: Creating proot session with shell fallback");
    
    // Convert the command to run through shell
    final shellCommand = ['sh', '-lc', originalCommand.join(' ')];
    
    final pty = await startPlatformPty(
      shellCommand.first,
      shellCommand.length > 1 ? shellCommand.sublist(1) : [],
      workingDirectory: Platform.environment['HOME'] ?? _envManager.homePath,
      environment: Platform.isAndroid
          ? _envManager.getProotEnvironment()
          : {
              ...Platform.environment,
              'TERM': 'xterm-256color',
            },
    );

    final terminal = Terminal(maxLines: 10000);

    pty.out
        .cast<List<int>>()
        .transform(const Utf8Decoder())
        .listen((data) {
          print("SessionManager: Shell session output: ${data}");
          terminal.write(data);
        }, onError: (error) {
          print("SessionManager: Shell session error: ${error}");
        });

    terminal.onOutput = (data) {
      print("SessionManager: Shell session input: ${data}");
      pty.write(data);
    };

    terminal.onResize = (w, h, pw, ph) {
      pty.resize(h, w);
    };

    final sessionId = _nextSessionId++;
    final session = TerminalSession(
      id: sessionId,
      terminal: terminal,
      pty: pty,
      title: 'Shell Session',
    );

    pty.exitCode.then((code) {
      print("SessionManager: Shell session ${sessionId} exited with code: ${code}");
      final index = _sessions.indexWhere((s) => s.id == sessionId);
      if (index != -1) {
        final session = _sessions[index];
        session.terminal
            .write('\r\n\r\n[Shell session completed with exit code: ${code}]');
        session.title = '[Exited]  [Shell session]';
        notifyListeners();
      }
    }).catchError((error) {
      print("SessionManager: Shell session ${sessionId} error: ${error}");
    });

    _sessions.add(session);
    _activeSessionIndex = _sessions.length - 1;

    print("Created shell session (ID: ${sessionId})");
    terminal.write('Shell fallback command: ${shellCommand.join(' ')}\r\n');
    notifyListeners();
  }

  void closeSession(int sessionId) {
    final index = _sessions.indexWhere((s) => s.id == sessionId);
    if (index == -1) return;

    final sessionToClose = _sessions[index];
    sessionToClose.pty.kill();
    _sessions.removeAt(index);

    if (_sessions.isEmpty) {
      _activeSessionIndex = -1;
    } else if (_activeSessionIndex >= index) {
      _activeSessionIndex = (_activeSessionIndex - 1).clamp(0, _sessions.length - 1);
    }

    print("Closed session (ID: $sessionId)");
    notifyListeners();
  }

  void setActiveSession(int sessionId) {
    final index = _sessions.indexWhere((s) => s.id == sessionId);
    if (index != -1 && index != _activeSessionIndex) {
      _activeSessionIndex = index;
      notifyListeners();
    }
  }
}