# Prominal with Termux Integration

This branch contains an enhanced version of Prominal that uses Termux for better Android terminal experience.

## Features

### Termux Terminal View
- **Native Android Terminal**: Uses Termux's native terminal rendering for better performance
- **Better Key Handling**: Improved keyboard input handling with proper escape sequences
- **Enhanced UI**: Modern terminal interface with rounded corners and better styling
- **Session Management**: Full session management with multiple terminal tabs

### Key Improvements
- **Performance**: Better rendering performance on Android devices
- **Compatibility**: Better compatibility with Android terminal applications
- **User Experience**: Improved keyboard shortcuts and terminal interactions
- **Visual Design**: Modern, polished terminal interface

## Files Added/Modified

### New Files
- `lib/termux_terminal_view.dart` - Termux terminal widget
- `lib/termux_session_manager.dart` - Session manager for Termux sessions
- `lib/termux_terminal_page.dart` - Terminal page with Termux integration
- `lib/termux_main.dart` - Main app entry point for Termux version
- `TERMUX_README.md` - This documentation file

### Modified Files
- `pubspec.yaml` - Added `termux_view: ^0.1.0` dependency

## Usage

### Running the Termux Version

To run the Termux version of Prominal, use the `termux_main.dart` file as the entry point:

```bash
flutter run -t lib/termux_main.dart
```

### Building for Release

```bash
flutter build appbundle --release --no-tree-shake-icons -t lib/termux_main.dart
```

## Architecture

### TermuxTerminalView
The main terminal widget that wraps the Termux view:
- Handles keyboard input and output
- Manages terminal styling and appearance
- Provides methods for writing data and resizing

### TermuxSessionManager
Manages terminal sessions:
- Creates and manages multiple terminal sessions
- Handles session lifecycle (create, switch, close)
- Integrates with PTY for process management

### TermuxTerminalPage
The UI layer for terminal sessions:
- Provides the workspace interface
- Handles context menus and special key combinations
- Integrates with the mini keyboard

## Key Features

### Terminal Features
- **Multi-session Support**: Create and manage multiple terminal sessions
- **Tab Interface**: Switch between sessions using tabs
- **Session Persistence**: Sessions persist until manually closed
- **Keyboard Shortcuts**: Full support for terminal keyboard shortcuts

### UI Features
- **Dark Theme**: Optimized dark theme for terminal use
- **Responsive Design**: Adapts to different screen sizes
- **Touch-Friendly**: Optimized for touch input on mobile devices
- **Context Menus**: Right-click/long-press menus for terminal actions

### Integration Features
- **Environment Manager**: Full integration with the existing environment setup
- **PTY Support**: Uses the existing PTY adapter for process management
- **File Manager**: Integrated file manager and editor
- **Settings**: Full settings integration

## Dependencies

### Required
- `termux_view: ^0.1.0` - Termux terminal view widget
- `flutter_pty: ^0.4.0` - PTY process management
- `xterm: ^4.0.0` - Fallback terminal (if needed)

### Existing Dependencies
- All existing dependencies from the main branch are preserved

## Compatibility

### Android
- **Primary Target**: Android devices with Termux support
- **Minimum API**: Android 7.0 (API level 24)
- **Architecture**: ARM64, x86_64

### Fallback Support
- Falls back to xterm-based terminal if Termux is not available
- Maintains compatibility with existing session management

## Development

### Adding New Features
1. Extend `TermuxTerminalView` for new terminal features
2. Update `TermuxSessionManager` for session-related features
3. Modify `TermuxTerminalPage` for UI changes

### Testing
- Test on physical Android devices
- Verify keyboard input handling
- Check session management functionality
- Test with different terminal applications

## Migration from xterm

The Termux version maintains API compatibility with the xterm version:
- Same session management interface
- Compatible with existing environment setup
- Preserves all existing functionality

To migrate from xterm to Termux:
1. Replace imports from `session_manager.dart` to `termux_session_manager.dart`
2. Update terminal page imports
3. Change main entry point to `termux_main.dart`

## Troubleshooting

### Common Issues
1. **Termux not available**: Falls back to xterm automatically
2. **Keyboard not working**: Check focus management and key event handling
3. **Sessions not starting**: Verify PTY setup and environment configuration

### Debug Mode
Enable debug logging by setting:
```dart
debugPrint = (String? message, {int? wrapWidth}) {
  print('DEBUG: $message');
};
```

## Future Enhancements

### Planned Features
- **Terminal Themes**: Customizable terminal color schemes
- **Font Customization**: Adjustable terminal fonts
- **Gesture Support**: Touch gestures for terminal navigation
- **Split Panes**: Multiple terminal panes in single session

### Performance Optimizations
- **Rendering Optimization**: Improved terminal rendering performance
- **Memory Management**: Better memory usage for long-running sessions
- **Battery Optimization**: Reduced battery consumption

## Contributing

When contributing to the Termux version:
1. Follow the existing code style
2. Test on physical Android devices
3. Maintain backward compatibility
4. Update documentation for new features

## License

Same license as the main Prominal project.