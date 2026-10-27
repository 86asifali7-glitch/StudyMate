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
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const MaterialApp(
        home: TimetableScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify Header
    expect(find.text('My Timetable'), findsOneWidget);
    expect(find.text('Your week, planned clearly'), findsOneWidget);
    expect(find.byKey(const Key('add_class_header_button')), findsOneWidget);
    expect(find.byKey(const Key('clear_all_header_button')), findsOneWidget);

    // 2. Verify Day Tabs with class counts
    expect(find.text('Mon'), findsOneWidget);
    expect(find.text('Tue'), findsOneWidget);
    expect(find.text('Wed'), findsOneWidget);
    expect(find.text('Thu'), findsOneWidget);
    expect(find.text('Fri'), findsOneWidget);

    // 3. Verify Daily Summary Card
    expect(find.text('Monday schedule'), findsOneWidget);
    expect(find.text('3 classes · 9:00 AM – 3:30 PM'), findsOneWidget);

    // 4. Verify "Your classes" section header
    expect(find.text('Your classes'), findsOneWidget);
    expect(find.text('3 classes'), findsWidgets);

    // 5. Verify Monday classes match reference image
    expect(find.text('Calculus II'), findsOneWidget);
    expect(find.text('9:00 AM – 10:30 AM'), findsOneWidget);

    expect(find.text('Physics Mechanics'), findsOneWidget);
    expect(find.text('11:00 AM – 12:30 PM'), findsOneWidget);
    expect(find.text('Room 203'), findsOneWidget);

    expect(find.text('Computer Architecture'), findsOneWidget);
    expect(find.text('2:00 PM – 3:30 PM'), findsOneWidget);
    expect(find.text('Room 101'), findsOneWidget);

    // 6. Verify Clock icons, Edit icons, and Delete icons
    expect(find.byIcon(Icons.access_time_rounded), findsWidgets);
    expect(find.byIcon(Icons.edit_outlined), findsNWidgets(3));
    expect(find.byIcon(Icons.delete_outline_rounded), findsNWidgets(3));

    // 7. Test Switching Day Tab to Tuesday
    await tester.tap(find.byKey(const Key('day_tab_Tue')));
    await tester.pumpAndSettle();

    expect(find.text('Tuesday schedule'), findsOneWidget);
    expect(find.text('Data Structures'), findsOneWidget);
    expect(find.text('Technical Writing'), findsOneWidget);
    expect(find.text('Calculus II'), findsNothing);

    // Switch back to Monday
    await tester.tap(find.byKey(const Key('day_tab_Mon')));
    await tester.pumpAndSettle();
    expect(find.text('Calculus II'), findsOneWidget);

    // 8. Test Editing a Class
    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();

    expect(find.text('Edit Class'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('class_subject_field')), 'Advanced Calculus');
    await tester.tap(find.byKey(const Key('save_class_button')));
    await tester.pumpAndSettle();

    expect(find.text('Advanced Calculus'), findsOneWidget);
    expect(find.text('Calculus II'), findsNothing);

    // 9. Test Deleting a Class
    await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('Advanced Calculus'), findsNothing);
    expect(find.text('Undo'), findsOneWidget);

    // 10. Test Adding a Class via Header Button
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

  testWidgets('Weekday buttons show immediate selection and isolated styling',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    TimetableScreen.resetForTesting();

    await tester.pumpWidget(
      const MaterialApp(
        home: TimetableScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify initial state: Mon is selected (blue background), Tue is inactive (transparent)
    Material getDayMaterial(String day) {
      final inkWellFinder = find.byKey(Key('day_tab_$day'));
      return tester.widget<Material>(
        find.ancestor(of: inkWellFinder, matching: find.byType(Material)).first,
      );
    }

    Text getDayText(String day) {
      return tester.widget<Text>(find.descendant(
        of: find.byKey(Key('day_tab_$day')),
        matching: find.text(day),
      ));
    }

    expect(getDayMaterial('Mon').color, const Color(0xFF2563EB));
    expect(getDayText('Mon').style?.color, Colors.white);
    expect(getDayMaterial('Tue').color, Colors.transparent);
    expect(getDayText('Tue').style?.color, const Color(0xFF64748B));

    // Tap Tue -> Updates immediately
    await tester.tap(find.byKey(const Key('day_tab_Tue')));
    await tester.pumpAndSettle();

    expect(getDayMaterial('Tue').color, const Color(0xFF2563EB));
    expect(getDayText('Tue').style?.color, Colors.white);
    expect(getDayMaterial('Mon').color, Colors.transparent);
    expect(getDayText('Mon').style?.color, const Color(0xFF64748B));

    // Tap Wed -> Updates immediately
    await tester.tap(find.byKey(const Key('day_tab_Wed')));
    await tester.pumpAndSettle();

    expect(getDayMaterial('Wed').color, const Color(0xFF2563EB));
    expect(getDayText('Wed').style?.color, Colors.white);
    expect(getDayMaterial('Tue').color, Colors.transparent);

    // Tap Thu -> Updates immediately
    await tester.tap(find.byKey(const Key('day_tab_Thu')));
    await tester.pumpAndSettle();
    expect(getDayMaterial('Thu').color, const Color(0xFF2563EB));

    // Tap Fri -> Updates immediately
    await tester.tap(find.byKey(const Key('day_tab_Fri')));
    await tester.pumpAndSettle();
    expect(getDayMaterial('Fri').color, const Color(0xFF2563EB));
  });

  testWidgets('Class cards match reference design with slim blue left border and circular buttons',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    TimetableScreen.resetForTesting();

    await tester.pumpWidget(
      const MaterialApp(
        home: TimetableScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Monday class cards exist
    final cardFinder = find.byKey(const ValueKey('timetable_card_1'));
    expect(cardFinder, findsOneWidget);

    // Verify card uses IntrinsicHeight to stretch the slim left blue border stripe
    expect(
      find.descendant(of: cardFinder, matching: find.byType(IntrinsicHeight)),
      findsOneWidget,
    );

    // Verify class card elements
    expect(find.text('Calculus II'), findsOneWidget);
    expect(find.text('9:00 AM – 10:30 AM'), findsOneWidget);
    expect(find.byIcon(Icons.access_time_rounded), findsWidgets);
    expect(find.byIcon(Icons.edit_outlined), findsWidgets);
    expect(find.byIcon(Icons.delete_outline_rounded), findsWidgets);

    // Verify circular button backgrounds
    final editButtonMaterial = tester.widget<Material>(
      find.ancestor(
        of: find.byIcon(Icons.edit_outlined).first,
        matching: find.byType(Material),
      ).first,
    );
    expect(editButtonMaterial.color, const Color(0xFFF1F5F9));

    final deleteButtonMaterial = tester.widget<Material>(
      find.ancestor(
        of: find.byIcon(Icons.delete_outline_rounded).first,
        matching: find.byType(Material),
      ).first,
    );
    expect(deleteButtonMaterial.color, const Color(0xFFFEF2F2));
  });

  testWidgets(
      'Subject icons dynamically adapt to subject names with proper theme and fallbacks',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    TimetableScreen.resetForTesting();

    await tester.pumpWidget(
      const MaterialApp(
        home: TimetableScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Monday defaults:
    // 1. Calculus II -> Mathematics -> calculator icon
    expect(find.byIcon(Icons.calculate_rounded), findsOneWidget);

    // 2. Physics Mechanics -> atom icon custom painter
    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter.runtimeType.toString() == '_AtomIconPainter',
      ),
      findsOneWidget,
    );

    // 3. Computer Architecture -> laptop icon
    expect(find.byIcon(Icons.laptop_chromebook_rounded), findsOneWidget);

    // Switch to Tuesday
    await tester.tap(find.byKey(const Key('day_tab_Tue')));
    await tester.pumpAndSettle();

    // Tuesday defaults:
    // Data Structures -> laptop / CS icon
    // Technical Writing -> book / writing icon
    expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);

    // Add a class with "Organic Chemistry"
    await tester.tap(find.byKey(const Key('add_class_header_button')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('class_subject_field')), 'Organic Chemistry');
    await tester.tap(find.byKey(const Key('save_class_button')));
    await tester.pumpAndSettle();

    // Organic Chemistry -> flask / science icon
    expect(find.byIcon(Icons.science_rounded), findsOneWidget);

    // Add a class with "General Knowledge" -> fallback school icon
    await tester.tap(find.byKey(const Key('add_class_header_button')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('class_subject_field')), 'General Knowledge');
    await tester.tap(find.byKey(const Key('save_class_button')));
    await tester.pumpAndSettle();

    // General Knowledge -> fallback school icon
    expect(find.byIcon(Icons.school_rounded), findsOneWidget);
  });
}
