import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:xterm/xterm.dart';
import 'package:prominal/environment_manager.dart';
import 'package:pty/pty.dart';

/// A data class to hold all components of a single terminal session.
class TerminalSession {
  final int id;
  final Terminal terminal;
  final PseudoTerminal pty;
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
    print("SessionManager: Creating session with command: \${command.join(' ')}");
    
    // If the first command is proot, try running it through shell as fallback
    List<String> actualCommand = command;
    if (command.first.contains('proot')) {
      // Try direct execution first, but prepare shell fallback
      print("SessionManager: Attempting proot session with direct execution");
    }
    
    final pty = await PseudoTerminal.start(
      actualCommand.first,
      actualCommand.length > 1 ? actualCommand.sublist(1) : [],
      workingDirectory: workingDirectory ?? _envManager.homePath,
      environment: {
        'TERM': 'xterm-256color',
        'HOME': _envManager.homePath,
        'PREFIX': _envManager.usrPath,
        'PATH': '\${_envManager.usrPath}/bin:/system/bin',
        'LD_LIBRARY_PATH': '\${_envManager.usrPath}/lib',
        'PROMINAL_VERSION': '1.0',
        'LANG': 'en_US.UTF-8',
      },
    );

    final terminal = Terminal(maxLines: 10000);

    // Decode the PTY's byte output into a String for the terminal.
    pty.out
        .cast<List<int>>()
        .transform(const Utf8Decoder())
        .listen((data) {
          print("SessionManager: Received output: \${data}");
          terminal.write(data);
        }, onError: (error) {
          print("SessionManager: Output error: \${error}");
        });

    // Encode the terminal's String output into bytes for the PTY.
    terminal.onOutput = (data) {
      print("SessionManager: Sending input: \${data}");
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
      title: title ?? 'Session \${sessionId}',
    );

    pty.exitCode.then((code) async {
      print("SessionManager: Session \${sessionId} exited with code: \${code}");
      final index = _sessions.indexWhere((s) => s.id == sessionId);
      if (index != -1) {
        final session = _sessions[index];
        session.terminal
            .write('\r\n\r\n[Process completed with exit code: \${code}]');
        session.title = '[Exited] \${session.title}';
        notifyListeners();
      }
      
      // If proot failed with permission denied, try shell approach
      if (code == -117 && command.first.contains('proot')) {
        print("SessionManager: Proot failed, trying shell approach...");
        await Future.delayed(const Duration(seconds: 1));
        await _createProotSessionWithShell(command);
      }
    }).catchError((error) {
      print("SessionManager: Session \${sessionId} error: \${error}");
    });

    _sessions.add(session);
    _activeSessionIndex = _sessions.length - 1;

    print("Created new session (ID: \${sessionId}) with command: \${actualCommand.join(' ')}");
    notifyListeners();
  }
  
  /// Create a proot session using shell as fallback
  Future<void> _createProotSessionWithShell(List<String> originalCommand) async {
    print("SessionManager: Creating proot session with shell fallback");
    
    // Convert the command to run through shell
    final shellCommand = ['sh', '-c', originalCommand.join(' ')];
    
    final pty = await PseudoTerminal.start(
      shellCommand.first,
      shellCommand.length > 1 ? shellCommand.sublist(1) : [],
      workingDirectory: _envManager.homePath,
      environment: {
        'TERM': 'xterm-256color',
        'HOME': _envManager.homePath,
        'PREFIX': _envManager.usrPath,
        'PATH': '\${_envManager.usrPath}/bin:/system/bin',
        'LD_LIBRARY_PATH': '\${_envManager.usrPath}/lib',
        'PROMINAL_VERSION': '1.0',
        'LANG': 'en_US.UTF-8',
      },
    );

    final terminal = Terminal(maxLines: 10000);

    pty.out
        .cast<List<int>>()
        .transform(const Utf8Decoder())
        .listen((data) {
          print("SessionManager: Shell session output: \${data}");
          terminal.write(data);
        }, onError: (error) {
          print("SessionManager: Shell session error: \${error}");
        });

    terminal.onOutput = (data) {
      print("SessionManager: Shell session input: \${data}");
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
      print("SessionManager: Shell session \${sessionId} exited with code: \${code}");
      final index = _sessions.indexWhere((s) => s.id == sessionId);
      if (index != -1) {
        final session = _sessions[index];
        session.terminal
            .write('\r\n\r\n[Shell session completed with exit code: \${code}]');
        session.title = '[Exited]  [Shell session]';
        notifyListeners();
      }
    }).catchError((error) {
      print("SessionManager: Shell session \${sessionId} error: \${error}");
    });

    _sessions.add(session);
    _activeSessionIndex = _sessions.length - 1;

    print("Created shell session (ID: \${sessionId})");
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