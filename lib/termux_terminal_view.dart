import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'termux_view_widget.dart';

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
  late final TermuxViewWidget _termuxWidget;
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
      _termuxWidget = TermuxViewWidget(
        sessionId: widget.sessionId,
        onOutput: widget.onOutput,
        onResize: widget.onResize,
        autofocus: widget.autofocus,
        focusNode: _focusNode,
      );

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
      print('Failed to initialize Termux terminal: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return _termuxWidget;
  }

  /// Write data to the terminal
  Future<void> write(String data) async {
    if (_isInitialized) {
      await _termuxWidget.write(data);
    }
  }

  /// Resize the terminal
  Future<void> resize(int width, int height) async {
    if (_isInitialized) {
      await _termuxWidget.resize(width, height);
    }
  }

  /// Clear the terminal
  Future<void> clear() async {
    if (_isInitialized) {
      await _termuxWidget.clear();
    }
  }
}