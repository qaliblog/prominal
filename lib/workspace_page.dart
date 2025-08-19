import 'package:flutter/material.dart';
import 'package:prominal/mini_keyboard.dart';
import 'package:prominal/session_manager.dart';
import 'package:xterm/xterm.dart';
import 'package:flutter/services.dart';
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
  Offset? _lastPressPosition;

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
          child: GestureDetector(
            onLongPressStart: (details) {
              _lastPressPosition = details.globalPosition;
              _showSelectionMenu(details.globalPosition);
            },
            onSecondaryTapDown: (details) {
              _lastPressPosition = details.globalPosition;
              _showSelectionMenu(details.globalPosition);
            },
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
        ),
        MiniKeyboard(terminal: widget.session.terminal),
      ],
    );
  }

  void _showSelectionMenu(Offset globalPosition) async {
    final selected = _getSelectedText();
    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(globalPosition.dx, globalPosition.dy, globalPosition.dx, globalPosition.dy),
      items: [
        PopupMenuItem<String>(value: 'copy', child: Text(selected?.isNotEmpty == true ? 'Copy' : 'Copy (no selection)')),
        const PopupMenuItem<String>(value: 'paste', child: Text('Paste')),
        const PopupMenuItem<String>(value: 'select_all', child: Text('Select All')),
      ],
    );
    switch (value) {
      case 'copy':
        if (selected != null && selected.isNotEmpty) {
          await Clipboard.setData(ClipboardData(text: selected));
          _showSnack('Copied');
        } else {
          _showSnack('No selection');
        }
        break;
      case 'paste':
        final data = await Clipboard.getData('text/plain');
        final text = data?.text;
        if (text != null && text.isNotEmpty) {
          widget.session.pty.write(text);
        }
        break;
      case 'select_all':
        final ok = _selectAll();
        if (!ok) _showSnack('Select All not available');
        break;
    }
  }

  String? _getSelectedText() {
    try {
      final dyn = widget.session.terminal as dynamic;
      final res = dyn.getSelectedText?.call();
      if (res is String) return res;
    } catch (_) {}
    return null;
  }

  bool _selectAll() {
    try {
      final dyn = widget.session.terminal as dynamic;
      final fn = dyn.selectAll;
      if (fn is Function) {
        fn.call();
        return true;
      }
    } catch (_) {}
    return false;
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(milliseconds: 1200)));
  }
}

