import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studymate/screens/tasks_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TasksScreen.resetForTesting();
  });

  testWidgets('TasksScreen matches reference design and supports all interactions',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TasksScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify Top Header matching reference
    expect(find.text('My Tasks'), findsOneWidget);
    expect(find.text('Stay focused, one task at a time.'), findsOneWidget);
    expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);

    // 2. Verify Task Progress Card
    expect(find.text('Your progress'), findsOneWidget);
    // 1 of 4 default tasks is completed (Physics)
    expect(find.text('1 of 4 completed'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    // 3. Verify Filter Bar (All, Today, Upcoming, Completed)
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('Completed'), findsWidgets);

    // 4. Verify Section Header ("Due soon" & "See all")
    expect(find.text('Due soon'), findsOneWidget);
    expect(find.text('See all'), findsOneWidget);

    // 5. Verify Tasks and Priority badge
    expect(find.text('Complete Calculus Problem Set 3'), findsOneWidget);
    expect(find.text('High'), findsOneWidget); // Priority badge on Calculus task
    expect(find.text('Due Tomorrow'), findsOneWidget);
    expect(find.text('Submit Chemistry Lab Report'), findsOneWidget);
    expect(find.text('Prepare Flashcards for History'), findsOneWidget);

    // 6. Test Toggling Task Completion
    // Tap on the task title or checkbox to toggle "Complete Calculus Problem Set 3"
    await tester.tap(find.text('Complete Calculus Problem Set 3'));
    await tester.pumpAndSettle();

    // Progress updates immediately: now 2 of 4 completed (50%)
    expect(find.text('2 of 4 completed'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);

    // 7. Test Switching to "Completed" Filter
    await tester.tap(find.text('Completed').first);
    await tester.pumpAndSettle();

    // Both completed tasks are displayed in Completed filter
    expect(find.text('Complete Calculus Problem Set 3'), findsOneWidget);
    expect(find.text('Read Physics Chapter 5 Summary'), findsOneWidget);
    // Incomplete tasks are filtered out
    expect(find.text('Submit Chemistry Lab Report'), findsNothing);

    // 8. Test "See all" Action restores All Tasks filter
    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();
    expect(find.text('Submit Chemistry Lab Report'), findsOneWidget);

    // 9. Test "Upcoming" Filter
    await tester.tap(find.text('Upcoming'));
    await tester.pumpAndSettle();
    // Incomplete future tasks are displayed
    expect(find.text('Submit Chemistry Lab Report'), findsOneWidget);
    expect(find.text('Prepare Flashcards for History'), findsOneWidget);
    // Completed tasks are excluded from Upcoming
    expect(find.text('Read Physics Chapter 5 Summary'), findsNothing);

    // Switch back to "All"
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    // 10. Test Deleting a Task via card three-dot menu
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();

    expect(find.text('Delete task'), findsOneWidget);
    await tester.tap(find.text('Delete task'));
    await tester.pumpAndSettle();

    // Task was deleted and Undo snackbar is visible
    expect(find.text('Undo'), findsOneWidget);

    // 11. Test Adding a Task via (+) FAB
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('add_task_title_field')), findsOneWidget);
    await tester.enterText(
        find.byKey(const Key('add_task_title_field')), 'Biology Exam Study Guide');
    await tester.tap(find.text('Due Friday').last);
    await tester.tap(find.byKey(const Key('dialog_create_task_button')));
    await tester.pumpAndSettle();

    expect(find.text('Biology Exam Study Guide'), findsOneWidget);
  });

  testWidgets('Saved empty tasks list remains empty and handles progress correctly',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'studymate_saved_tasks': <String>[],
    });
    TasksScreen.resetForTesting();

    await tester.pumpWidget(
      const MaterialApp(
        home: TasksScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Default sample tasks should NOT appear
    expect(find.text('Complete Calculus Problem Set 3'), findsNothing);
    expect(find.text('Read Physics Chapter 5 Summary'), findsNothing);

    // Progress card handles empty state gracefully
    expect(find.text('0 of 0 completed'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);

    // Empty state should be visible
    expect(find.text('No tasks to do'), findsOneWidget);
  });

  testWidgets('Bug 1: Each filter option has its own independent tap and animation state',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TasksScreen(),
      ),
    );
    await tester.pumpAndSettle();

    final allKey = const ValueKey('filter_tab_all');
    final todayKey = const ValueKey('filter_tab_today');
    final upcomingKey = const ValueKey('filter_tab_upcoming');
    final completedKey = const ValueKey('filter_tab_completed');

    expect(find.byKey(allKey), findsOneWidget);
    expect(find.byKey(todayKey), findsOneWidget);
    expect(find.byKey(upcomingKey), findsOneWidget);
    expect(find.byKey(completedKey), findsOneWidget);

    // Helper to get Material color of a tab
    Color? getTabColor(Key key) {
      final materialWidget = tester.widget<Material>(find.byKey(key));
      return materialWidget.color;
    }

    const activeColor = Color(0xFFEFF6FF);
    const inactiveColor = Colors.transparent;

    // Initially "All" is selected
    expect(getTabColor(allKey), activeColor);
    expect(getTabColor(todayKey), inactiveColor);
    expect(getTabColor(upcomingKey), inactiveColor);
    expect(getTabColor(completedKey), inactiveColor);

    // Tap "Today"
    await tester.tap(find.byKey(todayKey));
    await tester.pumpAndSettle();

    expect(getTabColor(allKey), inactiveColor);
    expect(getTabColor(todayKey), activeColor);
    expect(getTabColor(upcomingKey), inactiveColor);
    expect(getTabColor(completedKey), inactiveColor);

    // Tap "Upcoming"
    await tester.tap(find.byKey(upcomingKey));
    await tester.pumpAndSettle();

    expect(getTabColor(allKey), inactiveColor);
    expect(getTabColor(todayKey), inactiveColor);
    expect(getTabColor(upcomingKey), activeColor);
    expect(getTabColor(completedKey), inactiveColor);

    // Tap "Completed"
    await tester.tap(find.byKey(completedKey));
    await tester.pumpAndSettle();

    expect(getTabColor(allKey), inactiveColor);
    expect(getTabColor(todayKey), inactiveColor);
    expect(getTabColor(upcomingKey), inactiveColor);
    expect(getTabColor(completedKey), activeColor);

    // Tap "All"
    await tester.tap(find.byKey(allKey));
    await tester.pumpAndSettle();

    expect(getTabColor(allKey), activeColor);
    expect(getTabColor(todayKey), inactiveColor);
    expect(getTabColor(upcomingKey), inactiveColor);
    expect(getTabColor(completedKey), inactiveColor);
  });

  testWidgets('Bug 2: Checkbox updates immediately on exact tapped task before reordering',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const MaterialApp(
        home: TasksScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Initial order of tasks:
    // 1. Complete Calculus Problem Set 3 (id: 1, incomplete)
    // 2. Submit Chemistry Lab Report (id: 3, incomplete)
    // 3. Prepare Flashcards for History (id: 4, incomplete)
    // 4. Read Physics Chapter 5 Summary (id: 2, completed)

    final calculusCheckboxFinder = find.byKey(const ValueKey('task_checkbox_1'));
    final calculusCheckbox = tester.widget<AnimatedContainer>(calculusCheckboxFinder);
    final boxDecor = calculusCheckbox.decoration as BoxDecoration;
    expect(boxDecor.color, Colors.white); // Unchecked initially

    // 1. Tap the first task (Calculus) checkbox
    await tester.tap(calculusCheckboxFinder);
    // Pump 1 frame without advancing the reorder timer
    await tester.pump();

    // Checkbox updates immediately to blue with checkmark in-place
    final updatedCalculusCheckbox = tester.widget<AnimatedContainer>(calculusCheckboxFinder);
    final updatedBoxDecor = updatedCalculusCheckbox.decoration as BoxDecoration;
    expect(updatedBoxDecor.color, const Color(0xFF2563EB)); // Ticked immediately!

    // Verify task is STILL at the top of the list in this frame (not yet moved to bottom)
    final taskItemsBeforeReorder = tester.widgetList<Padding>(find.byWidgetPredicate(
      (w) => w is Padding && w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('task_item_'),
    )).toList();
    expect((taskItemsBeforeReorder.first.key as ValueKey<String>).value, 'task_item_1');

    // 2. Now let the 400ms timer elapse to allow reordering
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    // Now it has reordered: incomplete tasks (History, Chemistry) are at top, completed (Calculus, Physics) at bottom
    final taskItemsAfterReorder = tester.widgetList<Padding>(find.byWidgetPredicate(
      (w) => w is Padding && w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('task_item_'),
    )).toList();
    // Incomplete tasks (id: 3, 4) are at top, completed (id: 1, 2) at bottom
    final topTwoKeys = [
      (taskItemsAfterReorder[0].key as ValueKey<String>).value,
      (taskItemsAfterReorder[1].key as ValueKey<String>).value,
    ];
    expect(topTwoKeys, containsAll(['task_item_3', 'task_item_4']));

    final bottomTwoKeys = [
      (taskItemsAfterReorder[2].key as ValueKey<String>).value,
      (taskItemsAfterReorder[3].key as ValueKey<String>).value,
    ];
    expect(bottomTwoKeys, containsAll(['task_item_1', 'task_item_2']));

    // 3. Test middle task: tap Chemistry (id: 3)
    final chemistryCheckboxFinder = find.byKey(const ValueKey('task_checkbox_3'));
    await tester.tap(chemistryCheckboxFinder);
    await tester.pump(); // immediate frame

    // Ticked immediately on Chemistry
    final updatedChemistryCheckbox = tester.widget<AnimatedContainer>(chemistryCheckboxFinder);
    expect((updatedChemistryCheckbox.decoration as BoxDecoration).color, const Color(0xFF2563EB));

    // Complete reorder
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    // 4. Test last incomplete task: History (id: 4)
    final historyCheckboxFinder = find.byKey(const ValueKey('task_checkbox_4'));
    await tester.tap(historyCheckboxFinder);
    await tester.pump();

    // Ticked immediately on History
    final updatedHistoryCheckbox = tester.widget<AnimatedContainer>(historyCheckboxFinder);
    expect((updatedHistoryCheckbox.decoration as BoxDecoration).color, const Color(0xFF2563EB));

    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    // All 4 tasks are now completed
    expect(find.text('4 of 4 completed'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('TasksScreen multi-selection, select all, and batch deletion test',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TasksScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify select tasks button in header
    expect(find.byTooltip('Select tasks'), findsOneWidget);
    await tester.tap(find.byTooltip('Select tasks'));
    await tester.pumpAndSettle();

    // Selection bar should appear
    expect(find.text('0 selected'), findsOneWidget);
    expect(find.text('Select all'), findsOneWidget);

    // Tap on task card to select it
    await tester.tap(find.text('Complete Calculus Problem Set 3'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);

    // Tap on another task
    await tester.tap(find.text('Submit Chemistry Lab Report'));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);

    // Tap "Select all"
    await tester.tap(find.text('Select all'));
    await tester.pumpAndSettle();
    expect(find.text('4 selected'), findsOneWidget);
    expect(find.text('Deselect all'), findsOneWidget);

    // Deselect one task
    await tester.tap(find.text('Submit Chemistry Lab Report'));
    await tester.pumpAndSettle();
    expect(find.text('3 selected'), findsOneWidget);

    // Tap delete button in selection bar
    await tester.tap(find.byTooltip('Delete selected'));
    await tester.pumpAndSettle();

    // Confirmation dialog
    expect(find.text('Delete 3 Tasks?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Now only 1 task remains ('Submit Chemistry Lab Report')
    expect(find.text('Submit Chemistry Lab Report'), findsOneWidget);
    expect(find.text('Complete Calculus Problem Set 3'), findsNothing);
    expect(find.text('1 of 1 completed'), findsNothing);
  });

  testWidgets('TasksScreen See all button opens All Tasks bottom sheet',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TasksScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // We are on "All" filter by default; tapping "See all" opens the overview sheet
    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();

    // Bottom sheet is displayed
    expect(find.text('All Tasks Overview'), findsOneWidget);
    expect(find.byKey(const Key('all_tasks_search_field')), findsOneWidget);

    // Close the sheet
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.text('All Tasks Overview'), findsNothing);
  });
}
