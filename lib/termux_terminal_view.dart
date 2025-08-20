import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';
import 'package:flutter/services.dart';
import 'dart:async';

/// A terminal view widget with enhanced UI for better Android terminal experience
class TermuxTerminalView extends StatefulWidget {
  final String sessionId;
  final Function(String) onOutput;
  final Function(int, int) onResize;
  final bool autofocus;
  final FocusNode? focusNode;

  const TermuxTerminalView({
    Key? key,
    required this.sessionId,
    required this.onOutput,
    required this.onResize,
    this.autofocus = true,
    this.focusNode,
  }) : super(key: key);

  @override
  State<TermuxTerminalView> createState() => _TermuxTerminalViewState();
}

class _TermuxTerminalViewState extends State<TermuxTerminalView> {
  late final Terminal _terminal;
  late final FocusNode _focusNode;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _initializeTerminal();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _initializeTerminal() async {
    try {
      _terminal = Terminal(
        maxLines: 10000,
      );
      
      // Set up terminal callbacks
      _terminal.onOutput = (data) {
        widget.onOutput(String.fromCharCodes(data));
      };

      _terminal.onResize = (width, height, _, __) {
        widget.onResize(width, height);
      };

      setState(() {
        _isInitialized = true;
      });

      // Request focus after initialization
      if (widget.autofocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _focusNode.requestFocus();
        });
      }
    } catch (e) {
      print('Failed to initialize enhanced terminal: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Focus(
          focusNode: _focusNode,
          autofocus: widget.autofocus,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              _handleKeyEvent(event);
            }
            return KeyEventResult.handled;
          },
          child: TerminalView(
            _terminal,
            theme: TerminalThemes.defaultTheme.copyWith(
              fontSize: 14,
              fontFamily: 'monospace',
              backgroundColor: Colors.black,
              foregroundColor: Colors.green,
              cursorColor: Colors.green,
              selectionColor: Colors.blue.withOpacity(0.3),
            ),
            focusNode: _focusNode,
            autofocus: true,
            readOnly: false,
            cursorType: TerminalCursorType.block,
            onTapUp: (details, offset) {
              _focusNode.requestFocus();
            },
          ),
        ),
      ),
    );
  }

  void _handleKeyEvent(KeyDownEvent event) {
    // Handle special key combinations
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _terminal.write('\x1b');
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      _terminal.write('\n');
    } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
      _terminal.write('\x08');
    } else if (event.logicalKey == LogicalKeyboardKey.tab) {
      _terminal.write('\t');
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _terminal.write('\x1b[A');
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _terminal.write('\x1b[B');
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _terminal.write('\x1b[D');
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _terminal.write('\x1b[C');
    } else if (event.logicalKey == LogicalKeyboardKey.home) {
      _terminal.write('\x1b[H');
    } else if (event.logicalKey == LogicalKeyboardKey.end) {
      _terminal.write('\x1b[F');
    } else if (event.logicalKey == LogicalKeyboardKey.pageUp) {
      _terminal.write('\x1b[5~');
    } else if (event.logicalKey == LogicalKeyboardKey.pageDown) {
      _terminal.write('\x1b[6~');
    } else if (event.logicalKey == LogicalKeyboardKey.delete) {
      _terminal.write('\x1b[3~');
    } else if (event.logicalKey == LogicalKeyboardKey.insert) {
      _terminal.write('\x1b[2~');
    } else if (event.logicalKey == LogicalKeyboardKey.f1) {
      _terminal.write('\x1bOP');
    } else if (event.logicalKey == LogicalKeyboardKey.f2) {
      _terminal.write('\x1bOQ');
    } else if (event.logicalKey == LogicalKeyboardKey.f3) {
      _terminal.write('\x1bOR');
    } else if (event.logicalKey == LogicalKeyboardKey.f4) {
      _terminal.write('\x1bOS');
    } else if (event.logicalKey == LogicalKeyboardKey.f5) {
      _terminal.write('\x1b[15~');
    } else if (event.logicalKey == LogicalKeyboardKey.f6) {
      _terminal.write('\x1b[17~');
    } else if (event.logicalKey == LogicalKeyboardKey.f7) {
      _terminal.write('\x1b[18~');
    } else if (event.logicalKey == LogicalKeyboardKey.f8) {
      _terminal.write('\x1b[19~');
    } else if (event.logicalKey == LogicalKeyboardKey.f9) {
      _terminal.write('\x1b[20~');
    } else if (event.logicalKey == LogicalKeyboardKey.f10) {
      _terminal.write('\x1b[21~');
    } else if (event.logicalKey == LogicalKeyboardKey.f11) {
      _terminal.write('\x1b[23~');
    } else if (event.logicalKey == LogicalKeyboardKey.f12) {
      _terminal.write('\x1b[24~');
    } else if (event.character != null) {
      _terminal.write(event.character!);
    }
  }

  /// Write data to the terminal
  void write(String data) {
    if (_isInitialized) {
      _terminal.write(data);
    }
  }

  /// Resize the terminal
  void resize(int width, int height) {
    if (_isInitialized) {
      _terminal.resize(width, height);
    }
  }

  /// Clear the terminal
  void clear() {
    if (_isInitialized) {
      _terminal.write('\x1b[2J\x1b[H');
    }
  }
}