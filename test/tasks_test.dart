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

    // 1. Verify Top Header
    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('Stay organized. Get things done.'), findsOneWidget);
    expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);

    // 2. Verify Tab Selector
    expect(find.text('All Tasks'), findsOneWidget);
    expect(find.text('Completed'), findsWidgets);

    // 3. Verify Initial Tasks from reference image
    expect(find.text('Complete Calculus Problem Set 3'), findsOneWidget);
    expect(find.text('Due Tomorrow'), findsOneWidget);

    expect(find.text('Read Physics Chapter 5 Summary'), findsOneWidget);
    expect(find.text('Completed'), findsWidgets); // tab and task subtitle

    expect(find.text('Submit Chemistry Lab Report'), findsOneWidget);
    expect(find.text('Due Friday'), findsOneWidget);

    expect(find.text('Prepare Flashcards for History'), findsOneWidget);
    expect(find.text('Due Sunday'), findsOneWidget);

    // 4. Verify Delete Button (coral trash can on each card)
    expect(find.byIcon(Icons.delete_outline_rounded), findsNWidgets(4));

    // 5. Test Toggling Completion
    // Tap on the checkbox or title for "Complete Calculus Problem Set 3"
    await tester.tap(find.text('Complete Calculus Problem Set 3'));
    await tester.pumpAndSettle();

    // Now it should be completed
    // 6. Test Switching to "Completed" Tab
    await tester.tap(find.text('Completed').first);
    await tester.pumpAndSettle();

    // Both "Complete Calculus Problem Set 3" and "Read Physics Chapter 5 Summary" are completed
    expect(find.text('Complete Calculus Problem Set 3'), findsOneWidget);
    expect(find.text('Read Physics Chapter 5 Summary'), findsOneWidget);
    // Incomplete tasks are filtered out
    expect(find.text('Submit Chemistry Lab Report'), findsNothing);

    // Switch back to "All Tasks"
    await tester.tap(find.text('All Tasks'));
    await tester.pumpAndSettle();
    expect(find.text('Submit Chemistry Lab Report'), findsOneWidget);

    // 7. Test Deleting a Task
    await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
    await tester.pumpAndSettle();

    // First task was deleted
    expect(find.text('Complete Calculus Problem Set 3'), findsNothing);
    expect(find.text('Undo'), findsOneWidget);

    // 8. Test Adding a Task via (+) FAB
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('add_task_title_field')), findsOneWidget);
    await tester.enterText(
        find.byKey(const Key('add_task_title_field')), 'Biology Exam Study Guide');
    await tester.tap(find.text('Due Friday').last);
    await tester.tap(find.byKey(const Key('dialog_create_task_button')));
    await tester.pumpAndSettle();

    expect(find.text('Biology Exam Study Guide'), findsOneWidget);
    expect(find.text('Due Friday'), findsWidgets);
  });

  testWidgets('Saved empty tasks list remains empty and does not revert to sample data',
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
    // Empty state should be visible
    expect(find.text('No tasks to do'), findsOneWidget);
  });
}
