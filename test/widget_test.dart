// test/widget_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prominal/environment_manager.dart';
import 'package:prominal/main.dart';
import 'package:prominal/session_manager.dart';

void main() {
  testWidgets('ProminalApp smoke test', (WidgetTester tester) async {
    // The real main() function performs asynchronous setup before running the app.
    // We must replicate that setup here to provide a valid EnvironmentManager
    // to the ProminalApp widget.
    // Note: This makes the test dependent on the file system via EnvironmentManager.
    final envManager = await EnvironmentManager.init();
    SessionManager.instance.initialize(envManager);

    // Build our app and trigger a frame.
    await tester.pumpWidget(ProminalApp(
      environmentManager: envManager,
      autoStartSession: false,
    ));

    // Avoid pumpAndSettle; it can hang if frames keep being scheduled.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify that the main UI elements are present after initialization.
    // 1. Check for the AppBar title.
    expect(find.text('prominal'), findsOneWidget);

    // 2. Check for the FloatingActionButton to add new sessions.
    expect(find.byIcon(Icons.add), findsOneWidget);

    // 3. Without auto-starting sessions, ensure the scaffold renders.
    expect(find.byType(Scaffold), findsOneWidget);
  });
}