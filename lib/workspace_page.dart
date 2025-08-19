import 'package:flutter/material.dart';
import 'package:prominal/mini_keyboard.dart';
import 'package:prominal/session_manager.dart';
import 'package:xterm/xterm.dart';
import 'file_manager.dart';
import 'editor_view.dart';
import 'chat_view.dart';

/// A 2x2 workspace showing Terminal, File Manager, Editor, and Chat.
class WorkspacePage extends StatefulWidget {
  final TerminalSession session;

  const WorkspacePage({
    Key? key,
    required this.session,
  }) : super(key: key);

  @override
  State<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends State<WorkspacePage> {
  late final FocusNode _terminalFocusNode;

  @override
  void initState() {
    super.initState();
    _terminalFocusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _terminalFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _terminalFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Grid layout: top row (Terminal, File Manager); bottom row (Editor, Chat)
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildTerminalPane()),
                const VerticalDivider(width: 1),
                const Expanded(child: FileManagerView()),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Row(
              children: [
                const Expanded(child: EditorView()),
                const VerticalDivider(width: 1),
                Expanded(child: ChatView()),
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
          child: TerminalView(
            widget.session.terminal,
            theme: TerminalThemes.defaultTheme,
            focusNode: _terminalFocusNode,
            autofocus: true,
            readOnly: false,
            cursorType: TerminalCursorType.block,
            onTapUp: (details, offset) {
              _terminalFocusNode.requestFocus();
            },
          ),
        ),
        MiniKeyboard(terminal: widget.session.terminal),
      ],
    );
  }
}

