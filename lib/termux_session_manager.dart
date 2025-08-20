import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'environment_manager.dart';
import 'pty_adapter.dart';
import 'termux_terminal_view.dart';

/// Represents a single terminal session with its associated PTY and Termux terminal widget.
class TermuxTerminalSession {
  final String id;
  final String title;
  final TermuxTerminalView terminal;
  final PlatformPty pty;
  final DateTime createdAt;
  bool _isActive = false;

  TermuxTerminalSession({
    required this.id,
    required this.title,
    required this.terminal,
    required this.pty,
  }) : createdAt = DateTime.now();

  bool get isActive => _isActive;
  void setActive(bool active) => _isActive = active;

  void dispose() {
    pty.kill();
  }
}

/// Manages multiple terminal sessions using Termux for better Android experience
class TermuxSessionManager extends ChangeNotifier {
  static final TermuxSessionManager _instance = TermuxSessionManager._internal();
  static TermuxSessionManager get instance => _instance;

  TermuxSessionManager._internal();

  final List<TermuxTerminalSession> _sessions = [];
  TermuxTerminalSession? _activeSession;
  EnvironmentManager? _environmentManager;

  /// Initialize the session manager with the environment manager
  void initialize(EnvironmentManager environmentManager) {
    _environmentManager = environmentManager;
  }

  /// Get all sessions
  List<TermuxTerminalSession> get sessions => List.unmodifiable(_sessions);

  /// Get the currently active session
  TermuxTerminalSession? get activeSession => _activeSession;

  /// Check if there are any sessions
  bool get hasSessions => _sessions.isNotEmpty;

  /// Create a new terminal session
  Future<TermuxTerminalSession> createNewSession({
    dynamic command, // Can be String or List<String>
    String? title,
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    if (_environmentManager == null) {
      throw StateError('TermuxSessionManager not initialized');
    }

    final sessionId = _generateSessionId();
    final sessionTitle = title ?? 'Terminal ${_sessions.length + 1}';
    final workingDir = workingDirectory ?? _environmentManager!.homePath;
    final env = environment ?? _getDefaultEnvironment();
    // Ensure proot-related environment is present to avoid exec issues
    try {
      final em = _environmentManager!;
      env['LD_LIBRARY_PATH'] = '/lib:/usr/lib:/usr/local/lib:${em.prootPath}:${env['LD_LIBRARY_PATH'] ?? ''}';
      env['PROOT_NO_SECCOMP'] = '1';
      env['PROOT_LOADER'] = '/proot/loader';
      env['PROOT_LOADER32'] = '/proot/loader32';
      env['PROOT_TMP_DIR'] = em.tmpPath;
      env['TMPDIR'] = em.tmpPath;
      // Explicitly unset LD_PRELOAD to avoid inherited preloads
      env['LD_PRELOAD'] = '';
    } catch (_) {}

    // Parse command and arguments
    String executable;
    List<String> arguments;
    
    if (command == null) {
      executable = '/bin/bash';
      arguments = ['-l'];
    } else if (command is String) {
      executable = command;
      arguments = [];
    } else if (command is List<String>) {
      executable = command.first;
      arguments = command.skip(1).toList();
    } else {
      throw ArgumentError('Command must be String or List<String>');
    }

    // If launching proot, wrap via system shell to avoid noexec issues
    String execPath = executable;
    List<String> execArgs = arguments;
    if (executable.contains('/proot') || executable.contains('proot')) {
      final joined = ([executable, ...arguments]).map((s) => _shellQuote(s)).join(' ');
      execPath = '/system/bin/sh';
      execArgs = ['-c', joined];
    }

    // Start PTY
    final pty = await startPlatformPty(
      execPath,
      execArgs,
      workingDirectory: workingDir,
      environment: env,
    );

    // Create Termux terminal view
    final terminal = TermuxTerminalView(
      sessionId: sessionId,
      onOutput: (data) {
        // Send terminal output to PTY
        pty.write(data);
      },
      onResize: (width, height) {
        // Resize PTY when terminal size changes
        pty.resize(height, width);
      },
    );

    // Create session
    final session = TermuxTerminalSession(
      id: sessionId,
      title: sessionTitle,
      terminal: terminal,
      pty: pty,
    );

    // Add to sessions list
    _sessions.add(session);

    // Set as active if this is the first session
    if (_sessions.length == 1) {
      setActiveSession(sessionId);
    }

    // Set up data flow between PTY and terminal
    _setupSessionDataFlow(session);

    notifyListeners();
    return session;
  }

  String _shellQuote(String input) {
    if (input.isEmpty) return "''";
    if (!input.contains("'")) return "'" + input + "'";
    return "'" + input.replaceAll("'", "'\\''") + "'";
  }

  /// Set the active session
  void setActiveSession(String sessionId) {
    final session = _sessions.firstWhere(
      (s) => s.id == sessionId,
      orElse: () => throw ArgumentError('Session not found: $sessionId'),
    );

    if (_activeSession != null) {
      _activeSession!.setActive(false);
    }

    _activeSession = session;
    session.setActive(true);
    notifyListeners();
  }

  /// Close a session
  void closeSession(String sessionId) {
    final sessionIndex = _sessions.indexWhere((s) => s.id == sessionId);
    if (sessionIndex == -1) return;

    final session = _sessions[sessionIndex];
    session.dispose();
    _sessions.removeAt(sessionIndex);

    // If we closed the active session, switch to another one
    if (_activeSession?.id == sessionId) {
      if (_sessions.isNotEmpty) {
        setActiveSession(_sessions.first.id);
      } else {
        _activeSession = null;
      }
    }

    notifyListeners();
  }

  /// Get default environment variables
  Map<String, String> _getDefaultEnvironment() {
    final env = Map<String, String>.from(Platform.environment);
    
    // Set up basic environment for the terminal
    env['TERM'] = 'xterm-256color';
    env['HOME'] = _environmentManager?.homePath ?? '/home';
    env['PWD'] = _environmentManager?.homePath ?? '/home';
    env['USER'] = 'user';
    env['SHELL'] = '/bin/bash';
    
    return env;
  }

  /// Generate a unique session ID
  String _generateSessionId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// Set up data flow between PTY and terminal
  void _setupSessionDataFlow(TermuxTerminalSession session) {
    // PTY output -> Terminal
    session.pty.out.listen(
      (data) {
        session.terminal.write(String.fromCharCodes(data));
      },
      onError: (error) {
        print('PTY output error: $error');
      },
      onDone: () {
        print('PTY output stream closed');
      },
    );
  }

  /// Dispose all sessions
  void dispose() {
    for (final session in _sessions) {
      session.dispose();
    }
    _sessions.clear();
    _activeSession = null;
    super.dispose();
  }
}