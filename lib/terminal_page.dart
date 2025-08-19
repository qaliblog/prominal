import 'package:flutter/material.dart';
import 'package:prominal/mini_keyboard.dart';
import 'package:prominal/workspace_page.dart';
import 'package:prominal/session_manager.dart';
import 'package:xterm/xterm.dart';
import 'dart:io';

/// The UI screen for a single terminal session.
///
/// This widget displays the terminal output using `TerminalView` and provides
/// our custom `MiniKeyboard` for special key inputs. It is responsible for
/// managing keyboard focus and displaying session-specific UI elements like the title.
class TerminalPage extends StatefulWidget {
  /// The specific session this page should display.
  final TerminalSession session;

  const TerminalPage({
    Key? key,
    required this.session,
  }) : super(key: key);

  @override
  State<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
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
    return WorkspacePage(session: widget.session);
  }
}