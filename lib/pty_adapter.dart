import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

// Desktop PTY
import 'package:pty/pty.dart' as desktop_pty;

// Flutter PTY for Android/iOS
import 'package:flutter_pty/flutter_pty.dart' as mobile_pty;

/// A thin abstraction over platform-specific PTY implementations so the rest of
/// the app can interact with a unified interface.
abstract class PlatformPty {
  Stream<List<int>> get out;
  void write(String data);
  void resize(int rows, int cols);
  Future<int> get exitCode;
  void kill();
}

class DesktopPlatformPty implements PlatformPty {
  final desktop_pty.PseudoTerminal _pty;

  DesktopPlatformPty._(this._pty);

  static Future<DesktopPlatformPty> start(
    String executable,
    List<String> arguments, {
    required String workingDirectory,
    required Map<String, String> environment,
  }) async {
    final pty = await desktop_pty.PseudoTerminal.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
    );
    return DesktopPlatformPty._(pty);
  }

  @override
  Stream<List<int>> get out => _pty.out.cast<List<int>>();

  @override
  void write(String data) => _pty.write(data);

  @override
  void resize(int rows, int cols) => _pty.resize(rows, cols);

  @override
  Future<int> get exitCode => _pty.exitCode;

  @override
  void kill() => _pty.kill();
}

class MobilePlatformPty implements PlatformPty {
  final mobile_pty.Pty _pty;

  MobilePlatformPty._(this._pty);

  static Future<MobilePlatformPty> start(
    String executable,
    List<String> arguments, {
    required String workingDirectory,
    required Map<String, String> environment,
  }) async {
    final pty = mobile_pty.Pty.start(
      executable,
      arguments: arguments,
      environment: environment,
      workingDirectory: workingDirectory,
    );
    return MobilePlatformPty._(pty);
  }

  @override
  Stream<List<int>> get out => _pty.output;

  @override
  void write(String data) => _pty.writeString(data);

  @override
  void resize(int rows, int cols) => _pty.resize(cols, rows);

  @override
  Future<int> get exitCode => _pty.exitCode;

  @override
  void kill() => _pty.kill();
}

Future<PlatformPty> startPlatformPty(
  String executable,
  List<String> arguments, {
  required String workingDirectory,
  required Map<String, String> environment,
}) async {
  if (Platform.isAndroid || Platform.isIOS) {
    return MobilePlatformPty.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
    );
  }
  return DesktopPlatformPty.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
  );
}

