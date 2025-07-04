import 'package:flutter/material.dart';
import 'package:prominal/mini_keyboard.dart';
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
    // We wrap the page in a Scaffold to get standard app layout elements.
    return Scaffold(
      // The body is a column containing the terminal view and the mini keyboard.
      body: Column(
        children: [
          // The TerminalView must be wrapped in an Expanded widget.
          // This tells it to fill all available vertical space in the Column.
          Expanded(
            child: TerminalView(
              // FIX 1: The 'terminal' object is now the first positional argument.
              widget.session.terminal,
              // Theming the terminal for a classic look.
              theme: TerminalThemes.defaultTheme,
              // Connect the focus node.
              focusNode: _focusNode,
              // Ensure the terminal gets focus automatically.
              autofocus: true,
              // Allow user input.
              readOnly: false,
              // A nice, visible block cursor.
              cursorType: TerminalCursorType.block,
              // FIX 2: The 'showToolbar' parameter has been removed. The software
              // keyboard is shown automatically when the terminal has focus.
              // Handle text selection gestures
              onTapUp: (details, offset) {
                _focusNode.requestFocus();
              },
            ),
          ),
          // Our custom keyboard for special keys wrapped in SafeArea to avoid navigation bar.
          SafeArea(
            child: MiniKeyboard(
              terminal: widget.session.terminal,
            ),
          ),
        ],
      ),
    );
  }
}