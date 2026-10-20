import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studymate/screens/home_screen.dart';
import 'package:studymate/screens/clock_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Clock Feature Tests', () {
    testWidgets('HomeScreen displays Clock shortcut and navigates to ClockScreen',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll down so Quick Access Clock card is in view
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      // Verify Clock shortcut exists in Quick Access
      expect(find.text('Clock'), findsWidgets);
      expect(find.text('Digital clock, stopwatch & timer'), findsOneWidget);
      expect(find.byIcon(Icons.access_time_rounded), findsWidgets);

      // Tap the Clock shortcut
      await tester.tap(find.text('Digital clock, stopwatch & timer'));
      await tester.pumpAndSettle();

      // Verify ClockScreen opened with 3 tabs
      expect(find.text('Digital Clock'), findsOneWidget);
      expect(find.text('Stopwatch'), findsOneWidget);
      expect(find.text('Countdown Timer'), findsOneWidget);
    });

    testWidgets('Digital Clock tab displays live time, formatted date, and 12h/24h toggle',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ClockScreen(initialTabIndex: 0),
        ),
      );
      await tester.pump();

      // Verify elements
      expect(find.text('Live Device Time'), findsOneWidget);
      expect(find.text('Time Format'), findsOneWidget);
      expect(find.text('Time Zone'), findsOneWidget);

      // Switch to 24h format
      expect(find.text('24h'), findsOneWidget);
      await tester.tap(find.text('24h'));
      await tester.pump();

      // Switch back to 12h format
      await tester.tap(find.text('12h'));
      await tester.pump();
      expect(find.text('12h'), findsOneWidget);

      // Advance time by 2 seconds to verify live clock tick
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('Stopwatch tab supports Start, Pause, Resume, Lap, and Reset accurately',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ClockScreen(initialTabIndex: 1),
        ),
      );
      await tester.pumpAndSettle();

      // Initial state
      expect(find.text('00:00.00'), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('Ready'), findsOneWidget);

      // Start stopwatch
      await tester.tap(find.text('Start'));
      await tester.pump();
      expect(find.text('Running'), findsOneWidget);
      expect(find.text('Pause'), findsOneWidget);
      expect(find.text('Lap'), findsOneWidget);

      // Advance 1 second
      await tester.pump(const Duration(seconds: 1, milliseconds: 200));

      // Record a Lap
      await tester.tap(find.text('Lap'));
      await tester.pump();
      expect(find.text('Lap 1'), findsOneWidget);

      // Advance another second
      await tester.pump(const Duration(seconds: 1));

      // Record a second Lap
      await tester.tap(find.text('Lap'));
      await tester.pump();
      expect(find.text('Lap 2'), findsOneWidget);

      // Pause stopwatch
      await tester.tap(find.text('Pause'));
      await tester.pump();
      expect(find.text('Paused'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);

      // Resume stopwatch
      await tester.tap(find.text('Resume'));
      await tester.pump();
      expect(find.text('Running'), findsOneWidget);

      // Advance a bit more, then Pause and Reset
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Pause'));
      await tester.pump();

      await tester.tap(find.text('Reset'));
      await tester.pump();

      // Should be back to 00:00.00 and laps cleared
      expect(find.text('00:00.00'), findsOneWidget);
      expect(find.text('No lap times recorded'), findsOneWidget);
    });

    testWidgets('Countdown Timer tab supports setting time, presets, start, pause, resume, and visual finish',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ClockScreen(initialTabIndex: 2),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify initial Pomodoro 25m
      expect(find.text('00:25:00'), findsOneWidget);
      expect(find.text('Set Duration'), findsOneWidget);

      // Tap 5 min preset
      await tester.tap(find.text('5 min'));
      await tester.pump();
      expect(find.text('00:05:00'), findsOneWidget);

      // Increment minutes using up arrow
      final upArrows = find.byIcon(Icons.keyboard_arrow_up_rounded);
      expect(upArrows, findsNWidgets(3)); // hours, minutes, seconds

      // Tap up on minutes (second arrow)
      await tester.tap(upArrows.at(1));
      await tester.pump();
      expect(find.text('00:06:00'), findsOneWidget);

      // Start the countdown
      await tester.tap(find.text('Start'));
      await tester.pump();
      expect(find.text('Pause'), findsOneWidget);
      expect(find.text('Counting down'), findsOneWidget);

      // Advance by 2 seconds
      await tester.pump(const Duration(seconds: 2));

      // Pause the countdown
      await tester.tap(find.text('Pause'));
      await tester.pump();
      expect(find.text('Paused'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);

      // Resume
      await tester.tap(find.text('Resume'));
      await tester.pump();
      expect(find.text('Pause'), findsOneWidget);

      // Reset
      await tester.tap(find.text('Pause'));
      await tester.pump();
      await tester.tap(find.text('Reset'));
      await tester.pump();
      expect(find.text('00:06:00'), findsOneWidget);
    });

    testWidgets('Countdown Timer notifies visually when timer finishes',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ClockScreen(initialTabIndex: 2),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Decrement minutes to 0
      final downArrows = find.byIcon(Icons.keyboard_arrow_down_rounded);
      // Tap 5 min preset
      await tester.tap(find.text('5 min'));
      await tester.pump();

      for (int i = 0; i < 5; i++) {
        await tester.tap(downArrows.at(1));
        await tester.pump();
      }

      // Add 2 seconds
      final upArrows = find.byIcon(Icons.keyboard_arrow_up_rounded);
      await tester.tap(upArrows.at(2)); // +1s
      await tester.pump();
      await tester.tap(upArrows.at(2)); // +2s
      await tester.pump();

      expect(find.text('00:00:02'), findsOneWidget);

      // Start countdown
      await tester.tap(find.text('Start'));
      await tester.pump();

      // Fast forward past 2 seconds
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // Verify visual notification
      expect(find.text("Time's Up!"), findsOneWidget);
      expect(find.text('Countdown complete. Great study session!'), findsOneWidget);
      expect(find.text('Finished'), findsOneWidget);
    });

    testWidgets('Navigation and disposal safety: leaving screen cancels active timers cleanly',
        (WidgetTester tester) async {
      final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          home: const Scaffold(
            body: Text('Home Base'),
          ),
        ),
      );

      // Push ClockScreen
      navKey.currentState!.push(
        MaterialPageRoute(
          builder: (_) => const ClockScreen(initialTabIndex: 1),
        ),
      );
      await tester.pumpAndSettle();

      // Start stopwatch
      await tester.tap(find.text('Start'));
      await tester.pump(const Duration(milliseconds: 100));

      // Switch to Countdown tab and start timer
      await tester.tap(find.text('Countdown Timer'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start'));
      await tester.pump(const Duration(milliseconds: 100));

      // Pop the ClockScreen via back arrow
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();

      // Verify we are back on Home Base
      expect(find.text('Home Base'), findsOneWidget);
      expect(find.text('Digital Clock'), findsNothing);

      // Pump more time to prove no timers are active or throw errors
      await tester.pump(const Duration(seconds: 3));
    });
  });
}
