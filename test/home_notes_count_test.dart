import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studymate/screens/home_screen.dart';

void main() {
  testWidgets('HomeScreen displays correct notes count in Quick Access and Stats',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Default note count is 3 (matches the 3 starter notes in NotesScreen)
    expect(find.text('3 items'), findsOneWidget);
    expect(find.text('3'), findsWidgets); // quick access & stats row
    expect(find.text('12 items'), findsNothing);
    expect(find.text('12'), findsNothing);
  });

  testWidgets('HomeScreen displays updated notes count when saved in storage',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'studymate_saved_notes': ['{"id":"1","title":"Test Note 1"}'],
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 item'), findsOneWidget);
    expect(find.text('12 items'), findsNothing);
  });

  testWidgets('HomeScreen displays updated tasks and timetable count when saved in storage',
      (WidgetTester tester) async {
    final now = DateTime.now();
    final todayDay = (now.weekday >= 1 && now.weekday <= 5)
        ? const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'][now.weekday - 1]
        : 'Mon';

    SharedPreferences.setMockInitialValues({
      'studymate_saved_notes': [
        '{"id":"1","title":"Note 1"}',
        '{"id":"2","title":"Note 2"}'
      ],
      'studymate_saved_tasks': [
        '{"id":"1","title":"Task 1","isCompleted":false,"due":"Today"}'
      ],
      'timetable_entries_v2':
          '[{"id":"1","subject":"Math","day":"$todayDay","startHour":9,"startMinute":0,"endHour":10,"endMinute":0},{"id":"2","subject":"Physics","day":"$todayDay","startHour":10,"startMinute":0,"endHour":11,"endMinute":0}]',
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Stat badges near top
    expect(find.text('2'), findsWidgets); // Notes & Classes badges
    expect(find.text('1'), findsWidgets); // Tasks badge

    // Notes: 2 items
    expect(find.text('2 items'), findsOneWidget);
    // Tasks: 1 item
    expect(find.text('1 item'), findsOneWidget);

    // Scroll down to make Timetable card fully visible
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();

    // Now Timetable quick card (2 items) is visible
    expect(find.text('2 items'), findsWidgets);
  });

  testWidgets('HomeScreen displays 0 classes and empty schedule card when all classes for today are deleted',
      (WidgetTester tester) async {
    // Only classes on other days exist, none for today
    final now = DateTime.now();
    final otherDay = (now.weekday == DateTime.friday) ? 'Mon' : 'Fri';

    SharedPreferences.setMockInitialValues({
      'studymate_notes_saved': true,
      'studymate_saved_notes': <String>['{"id":"1","title":"Note 1"}'],
      'studymate_tasks_saved': true,
      'studymate_saved_tasks': <String>['{"id":"1","title":"Task 1"}'],
      'studymate_timetable_saved': true,
      'timetable_entries_v2':
          '[{"id":"4","subject":"Data Structures","day":"$otherDay","startHour":10,"startMinute":0,"endHour":11,"endMinute":30}]',
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Classes badge shows 0 because no classes for today
    expect(find.text('0'), findsWidgets);
    // Hero card shows No Classes Scheduled
    expect(find.text('No Classes Scheduled'), findsOneWidget);
    expect(find.text('Calculus II'), findsNothing);
  });

  testWidgets('HomeScreen displays 0 items and empty schedule card when all items are deleted',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'studymate_notes_saved': true,
      'studymate_saved_notes': <String>[],
      'studymate_tasks_saved': true,
      'studymate_saved_tasks': <String>[],
      'studymate_timetable_saved': true,
      'timetable_entries_v2': '[]',
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Badges show 0
    expect(find.text('0'), findsNWidgets(3));
    // Hero card shows No Classes Scheduled
    expect(find.text('No Classes Scheduled'), findsOneWidget);
    // Quick access show 0 items
    expect(find.text('0 items'), findsWidgets);
  });
}
