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

      _terminal.onResize = (width, height) {
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
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Focus(
          focusNode: _focusNode,
          autofocus: widget.autofocus,
          onKeyEvent: (node, event) {
            // Handle special key events
            if (event is KeyDownEvent) {
              _handleKeyEvent(event);
            }
            return KeyEventResult.handled;
          },
          child: TermuxView(
            controller: _controller,
            style: const TermuxViewStyle(
              fontSize: 14,
              fontFamily: 'monospace',
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              cursorColor: Colors.white,
              selectionColor: Colors.blue,
            ),
          ),
        ),
      ),
    );
  }

  void _handleKeyEvent(KeyDownEvent event) {
    // Handle special key combinations
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _controller.write('\x1b');
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      _controller.write('\n');
    } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
      _controller.write('\x08');
    } else if (event.logicalKey == LogicalKeyboardKey.tab) {
      _controller.write('\t');
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _controller.write('\x1b[A');
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _controller.write('\x1b[B');
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _controller.write('\x1b[D');
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _controller.write('\x1b[C');
    } else if (event.logicalKey == LogicalKeyboardKey.home) {
      _controller.write('\x1b[H');
    } else if (event.logicalKey == LogicalKeyboardKey.end) {
      _controller.write('\x1b[F');
    } else if (event.logicalKey == LogicalKeyboardKey.pageUp) {
      _controller.write('\x1b[5~');
    } else if (event.logicalKey == LogicalKeyboardKey.pageDown) {
      _controller.write('\x1b[6~');
    } else if (event.logicalKey == LogicalKeyboardKey.delete) {
      _controller.write('\x1b[3~');
    } else if (event.logicalKey == LogicalKeyboardKey.insert) {
      _controller.write('\x1b[2~');
    } else if (event.logicalKey == LogicalKeyboardKey.f1) {
      _controller.write('\x1bOP');
    } else if (event.logicalKey == LogicalKeyboardKey.f2) {
      _controller.write('\x1bOQ');
    } else if (event.logicalKey == LogicalKeyboardKey.f3) {
      _controller.write('\x1bOR');
    } else if (event.logicalKey == LogicalKeyboardKey.f4) {
      _controller.write('\x1bOS');
    } else if (event.logicalKey == LogicalKeyboardKey.f5) {
      _controller.write('\x1b[15~');
    } else if (event.logicalKey == LogicalKeyboardKey.f6) {
      _controller.write('\x1b[17~');
    } else if (event.logicalKey == LogicalKeyboardKey.f7) {
      _controller.write('\x1b[18~');
    } else if (event.logicalKey == LogicalKeyboardKey.f8) {
      _controller.write('\x1b[19~');
    } else if (event.logicalKey == LogicalKeyboardKey.f9) {
      _controller.write('\x1b[20~');
    } else if (event.logicalKey == LogicalKeyboardKey.f10) {
      _controller.write('\x1b[21~');
    } else if (event.logicalKey == LogicalKeyboardKey.f11) {
      _controller.write('\x1b[23~');
    } else if (event.logicalKey == LogicalKeyboardKey.f12) {
      _controller.write('\x1b[24~');
    } else if (event.character != null) {
      _controller.write(event.character!);
    }
  }

  /// Write data to the terminal
  void write(String data) {
    if (_isInitialized) {
      _controller.write(data);
    }
  }

  /// Resize the terminal
  void resize(int width, int height) {
    if (_isInitialized) {
      _controller.resize(width, height);
    }
  }

  /// Clear the terminal
  void clear() {
    if (_isInitialized) {
      _controller.write('\x1b[2J\x1b[H');
    }
  }

  /// Get terminal size
  Future<Size> getSize() async {
    if (_isInitialized) {
      return await _controller.getSize();
    }
    return const Size(80, 24);
  }
}