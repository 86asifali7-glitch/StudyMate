import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studymate/core/colors.dart';
import 'package:studymate/screens/main_shell.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Bottom navigation tab switching and interaction isolation test',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: MainShell()));
    await tester.pumpAndSettle();

    // Helper to check the background color of an item's Ink container by label
    Color getTabColor(String label) {
      final itemFinder = find.byKey(ValueKey<String>(label));
      expect(itemFinder, findsOneWidget);
      final inkFinder =
          find.descendant(of: itemFinder, matching: find.byType(Ink));
      expect(inkFinder, findsOneWidget);
      final inkWidget = tester.widget<Ink>(inkFinder);
      final decoration = inkWidget.decoration as BoxDecoration;
      return decoration.color ?? Colors.transparent;
    }

    // 1. Initial State: Home is selected
    expect(getTabColor('Home'), AppColors.primaryLight);
    expect(getTabColor('Notes'), Colors.transparent);
    expect(getTabColor('Tasks'), Colors.transparent);
    expect(getTabColor('Timetable'), Colors.transparent);

    // 2. Tap Tasks
    await tester.tap(find.byKey(const ValueKey<String>('Tasks')));
    await tester.pump(); // Immediate rebuild frame

    // Verify Tasks is selected immediately and Home has NO lingering active color
    expect(getTabColor('Tasks'), AppColors.primaryLight);
    expect(getTabColor('Home'), Colors.transparent);
    expect(getTabColor('Notes'), Colors.transparent);
    expect(getTabColor('Timetable'), Colors.transparent);
    await tester.pumpAndSettle();

    // 3. Tap Notes
    await tester.tap(find.byKey(const ValueKey<String>('Notes')));
    await tester.pump();
    expect(getTabColor('Notes'), AppColors.primaryLight);
    expect(getTabColor('Tasks'), Colors.transparent);
    expect(getTabColor('Home'), Colors.transparent);
    expect(getTabColor('Timetable'), Colors.transparent);
    await tester.pumpAndSettle();

    // 4. Tap Timetable
    await tester.tap(find.byKey(const ValueKey<String>('Timetable')));
    await tester.pump();
    expect(getTabColor('Timetable'), AppColors.primaryLight);
    expect(getTabColor('Notes'), Colors.transparent);
    expect(getTabColor('Tasks'), Colors.transparent);
    expect(getTabColor('Home'), Colors.transparent);
    await tester.pumpAndSettle();

    // 5. Tap Home again
    await tester.tap(find.byKey(const ValueKey<String>('Home')));
    await tester.pump();
    expect(getTabColor('Home'), AppColors.primaryLight);
    expect(getTabColor('Timetable'), Colors.transparent);
    expect(getTabColor('Notes'), Colors.transparent);
    expect(getTabColor('Tasks'), Colors.transparent);
    await tester.pumpAndSettle();

    // 6. Rapidly switch multiple times
    for (int i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const ValueKey<String>('Tasks')));
      await tester.pump();
      expect(getTabColor('Tasks'), AppColors.primaryLight);
      expect(getTabColor('Home'), Colors.transparent);

      await tester.tap(find.byKey(const ValueKey<String>('Notes')));
      await tester.pump();
      expect(getTabColor('Notes'), AppColors.primaryLight);
      expect(getTabColor('Tasks'), Colors.transparent);

      await tester.tap(find.byKey(const ValueKey<String>('Home')));
      await tester.pump();
      expect(getTabColor('Home'), AppColors.primaryLight);
      expect(getTabColor('Notes'), Colors.transparent);
    }
  });
}
