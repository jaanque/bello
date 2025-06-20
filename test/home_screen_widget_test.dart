// test/home_screen_widget_test.dart
import 'package:bello/home_screen.dart'; // Adjust import if needed
import 'package:bello/main.dart'; // For BelloApp theme context
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// Mock NotificationService if its initialization is problematic in tests
// import 'package:mockito/mockito.dart';
// import 'package:bello/notification_service.dart';

// class MockNotificationService extends Mock implements NotificationService {}

void main() {
  // Mock setup if NotificationService.initialize() is an issue
  // setUp(() {
  //   // Mock NotificationService.initialize to do nothing or return success
  // });

  testWidgets('HomeScreen initial UI elements', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // We need to provide the MaterialApp ancestor for theme, mediaquery, etc.
    // For simplicity, wrapping HomeScreen directly. If it relies on inherited widgets from BelloApp,
    // then pumpWidget(BelloApp()) would be better, then find HomeScreen.

    // Since HomeScreen now does a lot in initState (async), including file system access
    // and camera, testing it in isolation is harder without extensive mocking.
    // A true widget test would mock services passed to HomeScreen or use a test version of HomeScreen.

    // For this subtask, let's assume we are testing a simplified version or
    // that critical async operations in initState can be handled/mocked.
    // Flutter test typically doesn't have real camera/file system access.

    // Simplest test: Pumping BelloApp which contains HomeScreen
    await tester.pumpWidget(const BelloApp()); // Assuming main.dart's BelloApp

    // Wait for async operations in initState to settle, if any that affect initial UI.
    // This might require multiple pumpAndSettle calls or specific timings.
    await tester.pumpAndSettle(const Duration(seconds: 1)); // Give some time for init

    // Verify AppBar title.
    expect(find.text('Bello'), findsOneWidget); // Checks AppBar title too

    // Verify initial record button text (assuming no video recorded today).
    // This depends on _hasRecordedToday which depends on file system access.
    // This test will likely fail or be flaky without mocking file system access.
    // For now, we'll assert what it *should* be if everything initializes cleanly and no video exists.
    expect(find.text('Grabar video de hoy'), findsOneWidget);

    // Verify month navigation buttons (icons).
    expect(find.byIcon(Icons.arrow_back_ios), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward_ios), findsOneWidget);

    // Verify "No hay videos grabados para este mes." or "Comienza grabando..." if no files/recap
    // This also depends on the mocked file system state.
    // Let's assume the most basic empty state:
    expect(find.text('Comienza grabando tu primer video.'), findsOneWidget);

  });
}
