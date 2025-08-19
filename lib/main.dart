import 'package:flutter/material.dart';
import 'package:prominal/environment_manager.dart';
import 'package:prominal/session_manager.dart';
import 'package:prominal/terminal_page.dart';
import 'package:prominal/workspace_page.dart';
import 'package:prominal/settings_page.dart';
import 'dart:async';

void main() async {
  // Ensure that Flutter's widget binding is initialized before we do anything.
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize our environment manager to get system paths.
  final envManager = await EnvironmentManager.init();
  
  // Initialize the session manager and give it access to the environment manager.
  SessionManager.instance.initialize(envManager);

  runApp(ProminalApp(environmentManager: envManager));
}

class ProminalApp extends StatelessWidget {
  final EnvironmentManager environmentManager;
  final bool autoStartSession;

  const ProminalApp({
    Key? key,
    required this.environmentManager,
    this.autoStartSession = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Prominal',
      theme: ThemeData.dark().copyWith(
        // Use a dark theme that's suitable for a terminal.
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(primary: Colors.blue),
      ),
      debugShowCheckedModeBanner: false,
      // The HomePage is where the main logic resides.
      home: HomePage(
        environmentManager: environmentManager,
        autoStartSession: autoStartSession,
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final EnvironmentManager environmentManager;
  final bool autoStartSession;

  const HomePage({
    Key? key,
    required this.environmentManager,
    this.autoStartSession = true,
  }) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late final SessionManager _sessionManager;
  TabController? _tabController;
  
  // Track setup state
  bool _isSetupInProgress = false;
  String? _setupError;
  Timer? _setupTimeoutTimer;

  @override
  void initState() {
    super.initState();
    _sessionManager = SessionManager.instance;
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
      }
    }
    
    // Listen for changes in the session list (additions/removals).
    _sessionManager.addListener(_onSessionsChanged);
  }

  /// Performs the very first setup, which runs in a special terminal session.
  Future<void> _performInitialSetup() async {
    if (_isSetupInProgress) return; // Prevent multiple setup attempts
    
    setState(() {
      _isSetupInProgress = true;
      _setupError = null;
    });

    try {
      print("Prominal: Starting setup process...");
      
      // 1. Prepare the files on the Dart side (copying, unpacking, etc.).
      // Add timeout to prevent hanging
      await widget.environmentManager.setupEnvironment().timeout(
        const Duration(minutes: 30),
        onTimeout: () {
          throw Exception("Setup timed out after 30 minutes. Please check your device storage and try again.");
        },
      );
      
      print("Prominal: Environment prepared, creating setup session...");
      
      // 2. Create a special terminal session that runs the bootstrap script.
      // This session will close automatically when the script finishes.
      _sessionManager.createNewSession(
        command: widget.environmentManager.getInitialCommand(),
        title: 'Setup',
      );
      
      print("Prominal: Setup session created");
      
      // Start a timeout timer for the setup session
      _setupTimeoutTimer = Timer(const Duration(minutes: 30), () {
        if (_isSetupInProgress && mounted) {
          print("Prominal: Setup session timeout - session may be hanging");
          setState(() {
            _setupError = "Setup session is taking too long (30+ minutes). The bootstrap script may be hanging. Try resetting the environment.";
            _isSetupInProgress = false;
          });
        }
      });
      
    } catch (error) {
      print("Prominal: Setup failed with error: $error");
      setState(() {
        _setupError = error.toString();
        _isSetupInProgress = false;
      });
    }
  }
  
  /// Creates the first interactive shell session after setup is complete.
  void _createInitialSession() {
    _sessionManager.createNewSession(
      command: widget.environmentManager.getInitialCommand(),
      title: 'Shell',
    );
  }

  /// This is called whenever a session is added or removed.
  void _onSessionsChanged() {
    // If a session was closed (e.g., the setup script finished),
    // and now there are no sessions left, start a new one.
    if (!_sessionManager.hasSessions && mounted) {
      // Check if setup was in progress and is now complete
      if (_isSetupInProgress && widget.environmentManager.isSetupComplete()) {
        // Cancel the timeout timer since setup completed successfully
        _setupTimeoutTimer?.cancel();
        _setupTimeoutTimer = null;
        
        setState(() {
          _isSetupInProgress = false;
        });
        print("Prominal: Setup completed, creating initial session");
        _createInitialSession();
        return;
      } else if (_isSetupInProgress) {
        // Setup session closed but setup is not complete - this might indicate an error
        print("Prominal: Setup session closed but setup not complete");
        
        // Cancel the timeout timer
        _setupTimeoutTimer?.cancel();
        _setupTimeoutTimer = null;
        
        setState(() {
          _setupError = "Setup session closed unexpectedly. Please restart the app.";
          _isSetupInProgress = false;
        });
        return;
      }
      
      // Normal case: create a new session
      _createInitialSession();
      return;
    }
    
    // Rebuild the UI to reflect the new list of sessions.
    // We also need to manage the TabController here.
    // Maintain TabController only for TabBarView; we still keep it to page between sessions
    final sessionCount = _sessionManager.sessions.length;
    final newIndex = _sessionManager.sessions.indexOf(_sessionManager.activeSession!);
    if (_tabController != null && _tabController!.length != sessionCount) {
      _tabController?.removeListener(_onTabChanged);
      _tabController?.dispose();
      _tabController = null;
    }
    if (_tabController == null && sessionCount > 0) {
      _tabController = TabController(
        initialIndex: newIndex,
        length: sessionCount,
        vsync: this,
      );
      _tabController!.addListener(_onTabChanged);
    }
    if (_tabController != null && _tabController!.index != newIndex) {
      _tabController!.animateTo(newIndex);
    }

    setState(() {}); // Trigger a rebuild.
  }
  
  /// Called when the user swipes or taps a tab.
  void _onTabChanged() {
    if (_tabController != null && !_tabController!.indexIsChanging) {
      final activeSession = _sessionManager.sessions[_tabController!.index];
      _sessionManager.setActiveSession(activeSession.id);
    }
  }

  @override
  void dispose() {
    _sessionManager.removeListener(_onSessionsChanged);
    _tabController?.removeListener(_onTabChanged);
    _tabController?.dispose();
    _setupTimeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('prominal'),
        elevation: 0,
        actions: [
          if (_sessionManager.hasSessions)
            Builder(
              builder: (ctx) => IconButton(
                tooltip: 'Sessions',
                icon: const Icon(Icons.view_sidebar),
                onPressed: () => Scaffold.of(ctx).openEndDrawer(),
              ),
            ),
          IconButton(
            tooltip: 'Environment Status',
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              final status = widget.environmentManager.getEnvironmentStatus();
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Environment Status'),
                  content: SingleChildScrollView(
                    child: Text(status.entries.map((e) => '${e.key}: ${e.value}').join('\n')),
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
            },
          ),
        ],
        // Removed top TabBar; use right-side drawer like Termux for sessions
      ),
      // A floating action button to create new sessions with extra bottom padding.
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: FloatingActionButton(
          onPressed: _createInitialSession,
          child: const Icon(Icons.add),
        ),
      ),
      // The main content area with a right-side drawer for session list like Termux.
      body: _buildBody(),
      endDrawer: _buildSessionDrawer(),
      endDrawerEnableOpenDragGesture: true,
      drawerEdgeDragWidth: 24,
    );
  }

  Widget _buildBody() {
    // Show setup error if there was one
    if (_setupError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                "Setup Failed",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _setupError!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _setupError = null;
                      });
                      _performInitialSetup();
                    },
                    child: const Text("Retry Setup"),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton(
                    onPressed: () async {
                      try {
                        await widget.environmentManager.resetEnvironment();
                        setState(() {
                          _setupError = null;
                        });
                        _performInitialSetup();
                      } catch (error) {
                        setState(() {
                          _setupError = "Reset failed: $error";
                        });
                      }
                    },
                    child: const Text("Reset & Retry"),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton(
                    onPressed: () async {
                      try {
                        await widget.environmentManager.resetEnvironment();
                        setState(() {
                          _setupError = null;
                        });
                        _performInitialSetup();
                      } catch (error) {
                        setState(() {
                          _setupError = "Reset failed: $error";
                        });
                      }
                    },
                    child: const Text("Debug: Reset & Retry"),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton(
                    onPressed: () async {
                      try {
                        final success = await widget.environmentManager.fixProotPermissions();
                        if (success) {
                          setState(() {
                            _setupError = null;
                          });
                          _createInitialSession();
                        } else {
                          setState(() {
                            _setupError = "Failed to fix proot permissions";
                          });
                        }
                      } catch (error) {
                        setState(() {
                          _setupError = "Permission fix failed: $error";
                        });
                      }
                    },
                    child: const Text("Fix Permissions"),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Show setup progress
    if (_isSetupInProgress) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text("Performing one-time setup..."),
            const SizedBox(height: 8),
            const Text(
              "Extracting Debian rootfs (this may take 2-5 minutes)",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              "Please be patient - the app may appear unresponsive during extraction",
              style: TextStyle(fontSize: 10, color: Colors.orange),
            ),
            const SizedBox(height: 16),
            Text(
              'Status: ${widget.environmentManager.getEnvironmentStatus()['rootfsExists'] == true ? 'rootfs present' : 'rootfs missing'}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      );
    }
    
    // Once setup is done (or was not needed), show the terminal tabs.
    if (_sessionManager.hasSessions && _tabController != null) {
      return TabBarView(
        controller: _tabController,
        children: _sessionManager.sessions.map((session) {
          // Each tab shows the 4-pane workspace.
          return WorkspacePage(key: ValueKey(session.id), session: session);
        }).toList(),
      );
    }
    
    // Default/fallback view.
    return const Center(child: Text("Initializing session..."));
  }

  Widget? _buildSessionDrawer() {
    if (!_sessionManager.hasSessions) return null;
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Sessions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _sessionManager.sessions.length,
                itemBuilder: (context, index) {
                  final s = _sessionManager.sessions[index];
                  return ListTile(
                    title: Text(s.title),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => _sessionManager.closeSession(s.id),
                    ),
                    onTap: () {
                      Navigator.of(context).maybePop();
                      _tabController?.animateTo(index);
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: _createInitialSession,
                icon: const Icon(Icons.add),
                label: const Text('New Session'),
              ),
            )
          ],
        ),
      ),
    );
  }
}