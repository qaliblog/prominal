import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

/// A Flutter widget that embeds a native Termux view on Android
class TermuxViewWidget extends StatefulWidget {
  final String sessionId;
  final Function(String) onOutput;
  final Function(int, int) onResize;
  final bool autofocus;
  final FocusNode? focusNode;

  const TermuxViewWidget({
    Key? key,
    required this.sessionId,
    required this.onOutput,
    required this.onResize,
    this.autofocus = true,
    this.focusNode,
  }) : super(key: key);

  @override
  State<TermuxViewWidget> createState() => _TermuxViewWidgetState();
}

class _TermuxViewWidgetState extends State<TermuxViewWidget> {
  static const MethodChannel _channel = MethodChannel('termux_view');
  late final FocusNode _focusNode;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _initializeTermuxView();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _initializeTermuxView() async {
    try {
      // Initialize the Termux view
      await _channel.invokeMethod('initialize', {
        'sessionId': widget.sessionId,
      });

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
      print('Failed to initialize Termux view: $e');
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
            if (event is KeyDownEvent) {
              _handleKeyEvent(event);
            }
            return KeyEventResult.handled;
          },
          child: AndroidView(
            viewType: 'termux_view',
            onPlatformViewCreated: _onPlatformViewCreated,
            creationParams: {
              'sessionId': widget.sessionId,
            },
            creationParamsCodec: const StandardMessageCodec(),
          ),
        ),
      ),
    );
  }

  void _onPlatformViewCreated(int id) {
    // Platform view created successfully
    print('Termux view created with id: $id');
  }

  void _handleKeyEvent(KeyDownEvent event) {
    // Handle special key combinations
    String? keySequence;
    
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      keySequence = '\x1b';
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      keySequence = '\n';
    } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
      keySequence = '\x08';
    } else if (event.logicalKey == LogicalKeyboardKey.tab) {
      keySequence = '\t';
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      keySequence = '\x1b[A';
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      keySequence = '\x1b[B';
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      keySequence = '\x1b[D';
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      keySequence = '\x1b[C';
    } else if (event.logicalKey == LogicalKeyboardKey.home) {
      keySequence = '\x1b[H';
    } else if (event.logicalKey == LogicalKeyboardKey.end) {
      keySequence = '\x1b[F';
    } else if (event.logicalKey == LogicalKeyboardKey.pageUp) {
      keySequence = '\x1b[5~';
    } else if (event.logicalKey == LogicalKeyboardKey.pageDown) {
      keySequence = '\x1b[6~';
    } else if (event.logicalKey == LogicalKeyboardKey.delete) {
      keySequence = '\x1b[3~';
    } else if (event.logicalKey == LogicalKeyboardKey.insert) {
      keySequence = '\x1b[2~';
    } else if (event.logicalKey == LogicalKeyboardKey.f1) {
      keySequence = '\x1bOP';
    } else if (event.logicalKey == LogicalKeyboardKey.f2) {
      keySequence = '\x1bOQ';
    } else if (event.logicalKey == LogicalKeyboardKey.f3) {
      keySequence = '\x1bOR';
    } else if (event.logicalKey == LogicalKeyboardKey.f4) {
      keySequence = '\x1bOS';
    } else if (event.logicalKey == LogicalKeyboardKey.f5) {
      keySequence = '\x1b[15~';
    } else if (event.logicalKey == LogicalKeyboardKey.f6) {
      keySequence = '\x1b[17~';
    } else if (event.logicalKey == LogicalKeyboardKey.f7) {
      keySequence = '\x1b[18~';
    } else if (event.logicalKey == LogicalKeyboardKey.f8) {
      keySequence = '\x1b[19~';
    } else if (event.logicalKey == LogicalKeyboardKey.f9) {
      keySequence = '\x1b[20~';
    } else if (event.logicalKey == LogicalKeyboardKey.f10) {
      keySequence = '\x1b[21~';
    } else if (event.logicalKey == LogicalKeyboardKey.f11) {
      keySequence = '\x1b[23~';
    } else if (event.logicalKey == LogicalKeyboardKey.f12) {
      keySequence = '\x1b[24~';
    } else if (event.character != null) {
      keySequence = event.character!;
    }

    if (keySequence != null) {
      _sendKeyToTermux(keySequence);
    }
  }

  Future<void> _sendKeyToTermux(String keySequence) async {
    try {
      await _channel.invokeMethod('sendKey', {
        'sessionId': widget.sessionId,
        'key': keySequence,
      });
    } catch (e) {
      print('Failed to send key to Termux: $e');
    }
  }

  /// Write data to the terminal
  Future<void> write(String data) async {
    try {
      await _channel.invokeMethod('write', {
        'sessionId': widget.sessionId,
        'data': data,
      });
    } catch (e) {
      print('Failed to write to Termux: $e');
    }
  }

  /// Resize the terminal
  Future<void> resize(int width, int height) async {
    try {
      await _channel.invokeMethod('resize', {
        'sessionId': widget.sessionId,
        'width': width,
        'height': height,
      });
    } catch (e) {
      print('Failed to resize Termux: $e');
    }
  }

  /// Clear the terminal
  Future<void> clear() async {
    try {
      await _channel.invokeMethod('clear', {
        'sessionId': widget.sessionId,
      });
    } catch (e) {
      print('Failed to clear Termux: $e');
    }
  }
}