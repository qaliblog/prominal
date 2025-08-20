import 'package:flutter/material.dart';
import 'package:prominal/environment_manager.dart';
import 'package:prominal/termux_session_manager.dart';
import 'package:prominal/termux_terminal_page.dart';
import 'package:prominal/settings_page.dart';
import 'dart:async';

void main() async {
  // Ensure that Flutter's widget binding is initialized before we do anything.
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize our environment manager to get system paths.
  final envManager = await EnvironmentManager.init();
  
  // Initialize the Termux session manager and give it access to the environment manager.
  TermuxSessionManager.instance.initialize(envManager);

  runApp(TermuxProminalApp(environmentManager: envManager));
}

class TermuxProminalApp extends StatelessWidget {
  final EnvironmentManager environmentManager;
  final bool autoStartSession;

  const TermuxProminalApp({
    Key? key,
    required this.environmentManager,
    this.autoStartSession = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Prominal (Termux)',
      theme: ThemeData.dark().copyWith(
        // Use a dark theme that's suitable for a terminal.
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(primary: Colors.blue),
      ),
      debugShowCheckedModeBanner: false,
      // The HomePage is where the main logic resides.
      home: TermuxHomePage(
        environmentManager: environmentManager,
        autoStartSession: autoStartSession,
      ),
    );
  }
}

class TermuxHomePage extends StatefulWidget {
  final EnvironmentManager environmentManager;
  final bool autoStartSession;

  const TermuxHomePage({
    Key? key,
    required this.environmentManager,
    this.autoStartSession = true,
  }) : super(key: key);

  @override
  State<TermuxHomePage> createState() => _TermuxHomePageState();
}

class _TermuxHomePageState extends State<TermuxHomePage> with TickerProviderStateMixin {
  late final TermuxSessionManager _sessionManager;
  TabController? _tabController;
  
  // Track setup state
  bool _isSetupInProgress = false;
  String? _setupError;
  Timer? _setupTimeoutTimer;
  Timer? _startupFallbackTimer;

  @override
  void initState() {
    super.initState();
    _sessionManager = TermuxSessionManager.instance;
    // If setup flag is present but rootfs is missing, clear flag to trigger setup.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await widget.environmentManager.ensureRootfsOrClearFlag();
      if (!widget.environmentManager.isSetupComplete()) {
        if (mounted) setState(() {});
      }
    });

    // Check if the one-time setup needs to be run.
    if (!widget.environmentManager.isSetupComplete()) {
      _performInitialSetup();
    } else {
      // If setup is already done, create a normal session immediately unless disabled.
      if (widget.autoStartSession) {
        _createInitialSession();
        // If no session appears shortly, fall back to host shell automatically
        _startupFallbackTimer = Timer(const Duration(seconds: 3), () {
          if (mounted && !_sessionManager.hasSessions) {
            print('TermuxHomePage: No session started, launching Android host shell fallback');
            _sessionManager.createNewSession(
              command: widget.environmentManager.getAndroidHostShellCommand(),
              title: 'Android Shell',
            );
          }
        });
      }
    }

    // Listen for session changes
    _sessionManager.addListener(_onSessionsChanged);
  }

  @override
  void dispose() {
    _setupTimeoutTimer?.cancel();
    _startupFallbackTimer?.cancel();
    _sessionManager.removeListener(_onSessionsChanged);
    _tabController?.dispose();
    super.dispose();
  }

  void _onSessionsChanged() {
    if (mounted) {
      setState(() {});
      _updateTabController();
    }
  }

  void _updateTabController() {
    final sessionCount = _sessionManager.sessions.length;
    if (sessionCount == 0) {
      _tabController?.dispose();
      _tabController = null;
    } else if (_tabController == null || _tabController!.length != sessionCount) {
      _tabController?.dispose();
      _tabController = TabController(length: sessionCount, vsync: this);
      _tabController!.addListener(_onTabChanged);
    }
  }

  void _onTabChanged() {
    if (_tabController != null && _tabController!.indexIsChanging) {
      final activeSession = _sessionManager.sessions[_tabController!.index];
      _sessionManager.setActiveSession(activeSession.id);
    }
  }

  void _performInitialSetup() async {
    if (_isSetupInProgress) return;

    setState(() {
      _isSetupInProgress = true;
      _setupError = null;
    });

    try {
      // Set up a timeout for the setup process
      _setupTimeoutTimer = Timer(const Duration(minutes: 5), () {
        if (mounted && _isSetupInProgress) {
          setState(() {
            _isSetupInProgress = false;
            _setupError = 'Setup timed out after 5 minutes';
          });
        }
      });

      // Start the setup process
      await widget.environmentManager.performSetup();

      if (mounted) {
        setState(() {
          _isSetupInProgress = false;
        });

        // Create initial session after successful setup
        if (widget.autoStartSession) {
          _createInitialSession();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSetupInProgress = false;
          _setupError = e.toString();
        });
      }
    } finally {
      _setupTimeoutTimer?.cancel();
    }
  }

  void _createInitialSession() async {
    try {
      final isProot = widget.environmentManager.isSetupComplete();
      final setupCmd = widget.environmentManager.getInitialCommand();
      
      await _sessionManager.createNewSession(
        command: isProot ? setupCmd : widget.environmentManager.getAndroidHostShellCommand(),
        title: isProot ? 'Debian Shell' : 'Android Shell',
      );
    } catch (e) {
      print('Failed to create initial session: $e');
      // Fallback to Android shell
      try {
        await _sessionManager.createNewSession(
          command: widget.environmentManager.getInitialCommand(),
          title: 'Fallback Shell',
        );
      } catch (e2) {
        print('Failed to create fallback session: $e2');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.environmentManager.isSetupComplete()) {
      return _buildSetupScreen();
    }

    if (!_sessionManager.hasSessions) {
      return _buildNoSessionsScreen();
    }

    return _buildMainScreen();
  }

  Widget _buildSetupScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.terminal,
              size: 64,
              color: Colors.blue,
            ),
            const SizedBox(height: 24),
            const Text(
              'Setting up Prominal...',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            if (_isSetupInProgress) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text(
                'This may take a few minutes on first launch',
                style: TextStyle(color: Colors.grey),
              ),
            ] else if (_setupError != null) ...[
              Text(
                'Setup failed: $_setupError',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _performInitialSetup,
                child: const Text('Retry Setup'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNoSessionsScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Prominal (Termux)'),
        backgroundColor: Colors.grey[900],
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.terminal,
              size: 64,
              color: Colors.blue,
            ),
            const SizedBox(height: 24),
            const Text(
              'No Terminal Sessions',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Create a new terminal session to get started',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _createInitialSession(),
              icon: const Icon(Icons.add),
              label: const Text('New Terminal'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createInitialSession(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMainScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Prominal (Termux)'),
        backgroundColor: Colors.grey[900],
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _createInitialSession(),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsPage(),
                ),
              );
            },
          ),
        ],
        bottom: _tabController != null
            ? TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: _sessionManager.sessions.map((session) {
                  return Tab(
                    text: session.title,
                    icon: IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () => _sessionManager.closeSession(session.id),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  );
                }).toList(),
              )
            : null,
      ),
      body: _tabController != null
          ? TabBarView(
              controller: _tabController,
              children: _sessionManager.sessions.map((session) {
                return TermuxTerminalPage(session: session);
              }).toList(),
            )
          : const Center(
              child: Text(
                'No sessions available',
                style: TextStyle(color: Colors.white),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createInitialSession(),
        child: const Icon(Icons.add),
      ),
    );
  }
}