import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studymate/screens/timetable_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TimetableScreen.resetForTesting();
  });

  testWidgets('TimetableScreen matches reference layout and supports CRUD',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TimetableScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify Header
    expect(find.text('Timetable'), findsOneWidget);
    expect(find.text('Your weekly class schedule'), findsOneWidget);
    expect(find.byKey(const Key('add_class_header_button')), findsOneWidget);

    // 2. Verify Day Tabs
    expect(find.text('Mon'), findsOneWidget);
    expect(find.text('Tue'), findsOneWidget);
    expect(find.text('Wed'), findsOneWidget);
    expect(find.text('Thu'), findsOneWidget);
    expect(find.text('Fri'), findsOneWidget);

    // 3. Verify Monday classes match reference image
    expect(find.text('Calculus II'), findsOneWidget);
    expect(find.text('9:00 AM – 10:30 AM'), findsOneWidget);

    expect(find.text('Physics Mechanics'), findsOneWidget);
    expect(find.text('11:00 AM – 12:30 PM'), findsOneWidget);

    expect(find.text('Computer Architecture'), findsOneWidget);
    expect(find.text('2:00 PM – 3:30 PM'), findsOneWidget);

    // 4. Verify Clock icons, Edit icons, and Delete icons
    expect(find.byIcon(Icons.access_time_rounded), findsNWidgets(3));
    expect(find.byIcon(Icons.edit_outlined), findsNWidgets(3));
    expect(find.byIcon(Icons.delete_outline_rounded), findsNWidgets(3));

    // 5. Test Switching Day Tab to Tuesday
    await tester.tap(find.byKey(const Key('day_tab_Tue')));
    await tester.pumpAndSettle();

    expect(find.text('Data Structures'), findsOneWidget);
    expect(find.text('Technical Writing'), findsOneWidget);
    expect(find.text('Calculus II'), findsNothing);

    // Switch back to Monday
    await tester.tap(find.byKey(const Key('day_tab_Mon')));
    await tester.pumpAndSettle();
    expect(find.text('Calculus II'), findsOneWidget);

    // 6. Test Deleting a Class
    await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('Calculus II'), findsNothing);
    expect(find.text('Undo'), findsOneWidget);

    // 7. Test Adding a Class via Header Button
    await tester.tap(find.byKey(const Key('add_class_header_button')));
    await tester.pumpAndSettle();

    expect(find.text('Add Class'), findsWidgets);
    expect(find.byKey(const Key('class_subject_field')), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('class_subject_field')), 'Discrete Mathematics');
    await tester.tap(find.byKey(const Key('save_class_button')));
    await tester.pumpAndSettle();

    expect(find.text('Discrete Mathematics'), findsOneWidget);
  });

  testWidgets('Saved empty timetable displays empty timetable screen with add button',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'timetable_entries_v2': '[]',
      'studymate_timetable_saved': true,
    });
    TimetableScreen.resetForTesting();

    await tester.pumpWidget(
      const MaterialApp(
        home: TimetableScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Default sample classes should NOT appear
    expect(find.text('Calculus II'), findsNothing);
    expect(find.text('Physics Mechanics'), findsNothing);
    // Dedicated empty timetable screen is shown
    expect(find.text('No classes scheduled yet'), findsOneWidget);
    expect(find.text('Your timetable is empty. Tap "+ Add Class" to set up your weekly schedule!'), findsOneWidget);
    expect(find.byKey(const Key('empty_add_class_button')), findsOneWidget);
  });

  testWidgets('Clear all classes removes all entries across all days and persists empty state',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    TimetableScreen.resetForTesting();

    await tester.pumpWidget(
      const MaterialApp(
        home: TimetableScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Clear All button is present in header
    expect(find.byKey(const Key('clear_all_header_button')), findsOneWidget);

    // Tap Clear All in header
    await tester.tap(find.byKey(const Key('clear_all_header_button')));
    await tester.pumpAndSettle();

    // Verify dialog appears
    expect(find.text('Clear Timetable?'), findsOneWidget);
    expect(find.byKey(const Key('confirm_clear_all_button')), findsOneWidget);

    // Confirm Clear All
    await tester.tap(find.byKey(const Key('confirm_clear_all_button')));
    await tester.pumpAndSettle();

    // Verify empty state is displayed
    expect(find.text('No classes scheduled yet'), findsOneWidget);
    expect(find.text('Calculus II'), findsNothing);

    // Verify shared preferences is updated with empty list
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('timetable_entries_v2'), '[]');
    expect(prefs.getBool('studymate_timetable_saved'), true);
  });
}
