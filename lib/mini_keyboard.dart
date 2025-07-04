import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

/// A compact, horizontal keyboard providing essential terminal keys.
///
/// This widget includes keys like ESC, CTRL, TAB, and arrow keys.
/// The CTRL key is stateful and acts as a toggle. When active, other
/// key presses from this widget are sent with the 'control' modifier.
class MiniKeyboard extends StatefulWidget {
  /// The terminal controller to which key events will be sent.
  final Terminal terminal;

  const MiniKeyboard({
    Key? key,
    required this.terminal,
  }) : super(key: key);

  @override
  State<MiniKeyboard> createState() => _MiniKeyboardState();
}

class _MiniKeyboardState extends State<MiniKeyboard> {
  /// Tracks the toggled state of the Control key.
  bool _isCtrlActive = false;

  /// Handles sending key events to the terminal.
  ///
  /// It checks if the Ctrl key is active and passes that state
  /// along with the key press to the terminal controller.
  void _sendKey(TerminalKey key) {
    widget.terminal.keyInput(key, ctrl: _isCtrlActive);

    // After a key is sent, we de-activate Ctrl for a more intuitive
    // single-press modifier experience, but this is a design choice.
    // To keep it toggled, comment out the following lines.
    // For this implementation, we will keep it toggled as requested.
    /*
    if (_isCtrlActive) {
      setState(() {
        _isCtrlActive = false;
      });
    }
    */
  }

  @override
  Widget build(BuildContext context) {
    // A dark, slightly transparent background for the keyboard bar.
    return Container(
      color: Colors.black.withOpacity(0.3),
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildKey(label: 'ESC', onTap: () => _sendKey(TerminalKey.escape)),
          _buildKey(
            label: 'CTRL',
            onTap: () {
              // Toggle the state of the Ctrl key.
              setState(() {
                _isCtrlActive = !_isCtrlActive;
              });
            },
            // The key is visually highlighted when active.
            isToggled: _isCtrlActive,
          ),
          _buildKey(label: 'TAB', onTap: () => _sendKey(TerminalKey.tab)),
          _buildKey(icon: Icons.arrow_back, onTap: () => _sendKey(TerminalKey.arrowLeft)),
          _buildKey(icon: Icons.arrow_upward, onTap: () => _sendKey(TerminalKey.arrowUp)),
          _buildKey(icon: Icons.arrow_downward, onTap: () => _sendKey(TerminalKey.arrowDown)),
          _buildKey(icon: Icons.arrow_forward, onTap: () => _sendKey(TerminalKey.arrowRight)),
        ],
      ),
    );
  }

  /// A helper method to build a single key, reducing code duplication.
  Widget _buildKey({
    String? label,
    IconData? icon,
    required VoidCallback onTap,
    bool isToggled = false,
  }) {
    // Keys should be flexible to fill the available space.
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3.0),
        // InkWell provides the ripple effect on tap.
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8.0),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              // The background color changes if the key is toggled.
              color: isToggled ? Colors.blue.withOpacity(0.9) : Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Center(
              child: label != null
                  ? Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    )
                  : Icon(
                      icon,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}