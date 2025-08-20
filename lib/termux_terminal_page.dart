import 'package:flutter/material.dart';
import 'package:prominal/mini_keyboard.dart';
import 'package:prominal/workspace_page.dart';
import 'package:prominal/termux_session_manager.dart';
import 'dart:io';

/// The UI screen for a single terminal session using Termux.
///
/// This widget displays the terminal output using `TermuxTerminalView` and provides
/// our custom `MiniKeyboard` for special key inputs. It is responsible for
/// managing keyboard focus and displaying session-specific UI elements like the title.
class TermuxTerminalPage extends StatefulWidget {
  /// The specific session this page should display.
  final TermuxTerminalSession session;

  const TermuxTerminalPage({
    Key? key,
    required this.session,
  }) : super(key: key);

  @override
  State<TermuxTerminalPage> createState() => _TermuxTerminalPageState();
}

class _TermuxTerminalPageState extends State<TermuxTerminalPage> {
  /// The focus node is essential for the terminal to receive keyboard events.
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();

    // Request focus for the terminal as soon as the widget is built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    // It's crucial to dispose of the focus node to prevent memory leaks.
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Delegate to full workspace view
    return TermuxWorkspacePage(session: widget.session);
  }
}

/// A 2x2 workspace showing Termux Terminal, File Manager, Editor, and Chat.
class TermuxWorkspacePage extends StatefulWidget {
  final TermuxTerminalSession session;

  const TermuxWorkspacePage({
    Key? key,
    required this.session,
  }) : super(key: key);

  @override
  State<TermuxWorkspacePage> createState() => _TermuxWorkspacePageState();
}

class _TermuxWorkspacePageState extends State<TermuxWorkspacePage> with SingleTickerProviderStateMixin {
  late final FocusNode _terminalFocusNode;
  Offset? _lastPressPosition;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _terminalFocusNode = FocusNode();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _terminalFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _terminalFocusNode.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Tab layout: Terminal | Files | Editor | Chat
    return SafeArea(
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: const [
              Tab(text: 'Terminal', icon: Icon(Icons.code)),
              Tab(text: 'Files', icon: Icon(Icons.folder)),
              Tab(text: 'Editor', icon: Icon(Icons.edit)),
              Tab(text: 'Chat', icon: Icon(Icons.chat_bubble_outline)),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTerminalPane(),
                const FileManagerView(),
                const EditorView(),
                ChatView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerminalPane() {
    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onLongPressStart: (details) {
              _lastPressPosition = details.globalPosition;
              _showSelectionMenu(details.globalPosition);
            },
            onSecondaryTapDown: (details) {
              _lastPressPosition = details.globalPosition;
              _showSelectionMenu(details.globalPosition);
            },
            child: Container(
              margin: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[800]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: widget.session.terminal,
              ),
            ),
          ),
        ),
        // Mini keyboard for special keys
        MiniKeyboard(
          onKeyPressed: (key) {
            _terminalFocusNode.requestFocus();
            // Handle special key presses
            switch (key) {
              case 'Ctrl+C':
                widget.session.terminal.write('\x03');
                break;
              case 'Ctrl+Z':
                widget.session.terminal.write('\x1a');
                break;
              case 'Ctrl+D':
                widget.session.terminal.write('\x04');
                break;
              case 'Ctrl+L':
                widget.session.terminal.write('\x0c');
                break;
              case 'Ctrl+U':
                widget.session.terminal.write('\x15');
                break;
              case 'Ctrl+K':
                widget.session.terminal.write('\x0b');
                break;
              case 'Ctrl+W':
                widget.session.terminal.write('\x17');
                break;
              case 'Ctrl+A':
                widget.session.terminal.write('\x01');
                break;
              case 'Ctrl+E':
                widget.session.terminal.write('\x05');
                break;
              case 'Ctrl+B':
                widget.session.terminal.write('\x02');
                break;
              case 'Ctrl+F':
                widget.session.terminal.write('\x06');
                break;
              case 'Ctrl+P':
                widget.session.terminal.write('\x10');
                break;
              case 'Ctrl+N':
                widget.session.terminal.write('\x0e');
                break;
              case 'Tab':
                widget.session.terminal.write('\t');
                break;
              case 'Escape':
                widget.session.terminal.write('\x1b');
                break;
            }
          },
        ),
      ],
    );
  }

  void _showSelectionMenu(Offset position) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: [
        PopupMenuItem(
          child: const Text('Copy'),
          onTap: () {
            // TODO: Implement copy functionality
          },
        ),
        PopupMenuItem(
          child: const Text('Paste'),
          onTap: () {
            // TODO: Implement paste functionality
          },
        ),
        PopupMenuItem(
          child: const Text('Select All'),
          onTap: () {
            // TODO: Implement select all functionality
          },
        ),
        PopupMenuItem(
          child: const Text('Clear Terminal'),
          onTap: () {
            widget.session.terminal.clear();
          },
        ),
      ],
    );
  }
}