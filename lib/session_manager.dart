import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:xterm/xterm.dart';
import 'environment_manager.dart';
import 'pty_adapter.dart';

/// Represents a single terminal session with its associated PTY and terminal widget.
class TerminalSession {
  final String id;
  final String title;
  final Terminal terminal;
  final PlatformPty pty;
  final DateTime createdAt;
  bool _isActive = false;

  TerminalSession({
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

/// Manages multiple terminal sessions and provides a unified interface for
/// creating, switching between, and managing terminal sessions.
class SessionManager extends ChangeNotifier {
  static final SessionManager _instance = SessionManager._internal();
  static SessionManager get instance => _instance;

  SessionManager._internal();

  final List<TerminalSession> _sessions = [];
  TerminalSession? _activeSession;
  EnvironmentManager? _environmentManager;

  /// Initialize the session manager with the environment manager
  void initialize(EnvironmentManager environmentManager) {
    _environmentManager = environmentManager;
  }

  /// Get all sessions
  List<TerminalSession> get sessions => List.unmodifiable(_sessions);

  /// Get the currently active session
  TerminalSession? get activeSession => _activeSession;

  /// Check if there are any sessions
  bool get hasSessions => _sessions.isNotEmpty;

  /// Create a new terminal session
  Future<TerminalSession> createNewSession({
    dynamic command, // Can be String or List<String>
    String? title,
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    if (_environmentManager == null) {
      throw StateError('SessionManager not initialized');
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
      env['PROOT_TMP_DIR'] = '/tmp';
      env['LD_PRELOAD'] = '';
    } catch (_) {}

    // Create terminal widget
    final terminal = Terminal(
      maxLines: 10000,
    );

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

    // Start PTY
    // If launching proot, wrap via system shell to avoid noexec issues
    String execPath = executable;
    List<String> execArgs = arguments;
    if (executable.contains('/proot') || executable.contains('proot')) {
      final joined = ([executable, ...arguments]).map((s) => _shellQuote(s)).join(' ');
      execPath = '/system/bin/sh';
      execArgs = ['-c', joined];
    }

    final pty = await startPlatformPty(
      execPath,
      execArgs,
      workingDirectory: workingDir,
      environment: env,
    );

    // Create session
    final session = TerminalSession(
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
  void _setupSessionDataFlow(TerminalSession session) {
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

    // Terminal input -> PTY
    session.terminal.onOutput = (data) {
      session.pty.write(data);
    };

    // Handle terminal resize
    session.terminal.onResize = (width, height, _, __) {
      session.pty.resize(height, width);
    };
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