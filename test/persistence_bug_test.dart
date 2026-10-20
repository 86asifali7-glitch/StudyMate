import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studymate/screens/main_shell.dart';
import 'package:studymate/screens/notes_screen.dart';
import 'package:studymate/screens/tasks_screen.dart';
import 'package:studymate/screens/timetable_screen.dart';
import 'package:studymate/services/app_data_service.dart';
import 'package:studymate/services/notification_service.dart';

void main() {
  setUp(() {
    NotificationService.instance.resetForTesting();
  });

  /// Helper to simulate a full app restart (process termination and relaunch)
  void simulateColdAppRestart() {
    AppDataService.instance.resetForTesting();
    NotesScreen.resetForTesting();
    TasksScreen.resetForTesting();
    TimetableScreen.resetForTesting();
  }

  group('StudyMate Permanent Data Persistence Tests (Requirement 9)', () {
    testWidgets('1. Fresh installation seeds sample data and establishes initialization marker',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      simulateColdAppRestart();

      await AppDataService.instance.initialize(forceReload: true);

      // Verify sample data seeded
      expect(AppDataService.instance.notes.length, 3);
      expect(AppDataService.instance.tasks.length, 4);
      expect(AppDataService.instance.timetableEntries.length, 9);

      // Verify initialization marker was saved to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AppDataService.kDataInitializedKey), true);
      expect(prefs.getBool(AppDataService.kNotesSavedKey), true);
      expect(prefs.getBool(AppDataService.kTasksSavedKey), true);
      expect(prefs.getBool(AppDataService.kTimetableSavedKey), true);
    });

    testWidgets(
        '2. Delete all notes, tasks, and timetable entries -> force-close and restart -> verify everything remains empty',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      simulateColdAppRestart();

      // Step A: Launch fresh app and verify initial sample data exists
      await AppDataService.instance.initialize(forceReload: true);
      await tester.pumpWidget(const MaterialApp(home: MainShell()));
      await tester.pumpAndSettle();

      // Home shows 3 notes, 4 tasks badges
      expect(find.text('3'), findsWidgets); // Notes
      expect(find.text('4'), findsWidgets); // Tasks

      // Step B: Clear all notes
      await AppDataService.instance.saveNotes([]);
      // Step C: Clear all tasks
      await AppDataService.instance.saveTasks([]);
      // Step D: Clear all timetable entries
      await AppDataService.instance.saveTimetable([]);

      // Verify storage holds empty lists
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppDataService.kNotesJsonKey), '[]');
      expect(prefs.getString(AppDataService.kTasksJsonKey), '[]');
      expect(prefs.getString(AppDataService.kTimetableKey), '[]');
      expect(prefs.getBool(AppDataService.kDataInitializedKey), true);

      // Step E: Simulate cold app restart (force-close and reopen)
      simulateColdAppRestart();
      await AppDataService.instance.initialize(forceReload: true);

      await tester.pumpWidget(MaterialApp(key: UniqueKey(), home: const MainShell()));
      await tester.pumpAndSettle();

      // Verify Home Screen counters are 0, 0, 0
      expect(find.text('0'), findsNWidgets(3)); // Badges
      expect(find.text('0 items'), findsWidgets); // Quick access
      expect(find.text('No Classes Scheduled'), findsOneWidget);
      expect(find.text('Calculus II'), findsNothing);

      // Step F: Switch to Notes tab -> verify empty state and sample notes DO NOT reappear
      await tester.tap(find.byIcon(Icons.menu_book_rounded).last);
      await tester.pumpAndSettle();
      expect(find.text('No notes yet'), findsOneWidget);
      expect(find.text('Calculus Derivatives & Integrals'), findsNothing);
      expect(find.text("Newton's Laws of Motion Summary"), findsNothing);
      expect(find.text('Organic Chemistry Reactions'), findsNothing);

      // Step G: Switch to Tasks tab -> verify empty state and sample tasks DO NOT reappear
      await tester.tap(find.byIcon(Icons.check_circle_outline_rounded).last);
      await tester.pumpAndSettle();
      expect(find.text('No tasks to do'), findsOneWidget);
      expect(find.text('Complete Calculus Problem Set 3'), findsNothing);
      expect(find.text('Read Physics Chapter 5 Summary'), findsNothing);
      expect(find.text('Submit Chemistry Lab Report'), findsNothing);
      expect(find.text('Prepare Flashcards for History'), findsNothing);

      // Step H: Switch to Timetable tab -> verify empty state and sample classes DO NOT reappear
      await tester.tap(find.byIcon(Icons.calendar_month_rounded).last);
      await tester.pumpAndSettle();
      expect(find.text('No classes scheduled yet'), findsOneWidget);
      expect(find.text('Calculus II'), findsNothing);
      expect(find.text('Physics Mechanics'), findsNothing);
    });

    testWidgets(
        '3. Add user entries after clearing everything -> restart app -> verify user entries persist and sample data never returns',
        (WidgetTester tester) async {
      // Start from an empty initialized state
      SharedPreferences.setMockInitialValues({
        AppDataService.kDataInitializedKey: true,
        AppDataService.kNotesSavedKey: true,
        AppDataService.kNotesJsonKey: '[]',
        AppDataService.kNotesListKey: <String>[],
        AppDataService.kTasksSavedKey: true,
        AppDataService.kTasksJsonKey: '[]',
        AppDataService.kTasksListKey: <String>[],
        AppDataService.kTimetableSavedKey: true,
        AppDataService.kTimetableKey: '[]',
      });
      simulateColdAppRestart();
      await AppDataService.instance.initialize(forceReload: true);

      // Add 1 Note
      final userNote = const NoteItem(
        id: 'user_note_101',
        title: 'Quantum Physics Lecture 4',
        subject: 'Physics',
        content: 'Wave particle duality notes and Schrödinger equation.',
        date: 'Oct 20, 2026',
      );
      await AppDataService.instance.saveNotes([userNote]);

      // Add 1 Task
      final userTask = TaskItem(
        id: 'user_task_202',
        title: 'Submit Machine Learning Project',
        isCompleted: false,
        due: 'Due Tomorrow',
        originalDue: 'Due Tomorrow',
      );
      await AppDataService.instance.saveTasks([userTask]);

      // Add 1 Class for Monday
      final userClass = TimetableEntry(
        id: 'user_class_303',
        subject: 'Machine Learning 101',
        day: 'Mon',
        startTime: const TimeOfDay(hour: 10, minute: 0),
        endTime: const TimeOfDay(hour: 11, minute: 30),
      );
      await AppDataService.instance.saveTimetable([userClass]);

      // Step B: Simulate cold app restart (force-close and reopen)
      simulateColdAppRestart();
      await AppDataService.instance.initialize(forceReload: true);

      await tester.pumpWidget(const MaterialApp(home: MainShell()));
      await tester.pumpAndSettle();

      // Verify Home Screen shows exact counts: 1 Note, 1 Task
      expect(find.text('1 item'), findsWidgets); // Notes & Tasks

      // Verify Notes Screen displays user note and NOT default sample notes
      await tester.tap(find.byIcon(Icons.menu_book_rounded).last);
      await tester.pumpAndSettle();
      expect(find.text('Quantum Physics Lecture 4'), findsOneWidget);
      expect(find.text('Calculus Derivatives & Integrals'), findsNothing);

      // Verify Tasks Screen displays user task and NOT default sample tasks
      await tester.tap(find.byIcon(Icons.check_circle_outline_rounded).last);
      await tester.pumpAndSettle();
      expect(find.text('Submit Machine Learning Project'), findsOneWidget);
      expect(find.text('Complete Calculus Problem Set 3'), findsNothing);

      // Verify Timetable Screen displays user class on Monday and NOT default sample classes
      await tester.tap(find.byIcon(Icons.calendar_month_rounded).last);
      await tester.pumpAndSettle();
      expect(find.text('Machine Learning 101'), findsOneWidget);
      expect(find.text('10:00 AM – 11:30 AM'), findsOneWidget);
      expect(find.text('Calculus II'), findsNothing);
    });

    testWidgets(
        '4. Interactive UI workflow: delete all entries -> reload page -> verify empty -> add entries -> reload -> verify persist',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      simulateColdAppRestart();

      await AppDataService.instance.initialize(forceReload: true);
      await tester.pumpWidget(const MaterialApp(home: MainShell()));
      await tester.pumpAndSettle();

      // 1. Delete all notes via AppDataService (awaited write)
      await AppDataService.instance.saveNotes([]);
      await tester.pumpAndSettle();

      // 2. Delete all tasks via AppDataService (awaited write)
      await AppDataService.instance.saveTasks([]);
      await tester.pumpAndSettle();

      // 3. Clear all timetable entries via AppDataService (awaited write)
      await AppDataService.instance.saveTimetable([]);
      await tester.pumpAndSettle();

      // 4. Simulate full page reload (Chrome page refresh: memory reset, reading browser storage)
      simulateColdAppRestart();
      await AppDataService.instance.initialize(forceReload: true);
      await tester.pumpWidget(MaterialApp(key: UniqueKey(), home: const MainShell()));
      await tester.pumpAndSettle();

      // Verify all sections remain empty after reload
      expect(find.text('0'), findsNWidgets(3));
      expect(find.text('No Classes Scheduled'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.menu_book_rounded).last);
      await tester.pumpAndSettle();
      expect(find.text('No notes yet'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.check_circle_outline_rounded).last);
      await tester.pumpAndSettle();
      expect(find.text('No tasks to do'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.calendar_month_rounded).last);
      await tester.pumpAndSettle();
      expect(find.text('No classes scheduled yet'), findsOneWidget);

      // 5. Add new entries
      await AppDataService.instance.saveNotes([
        const NoteItem(
          id: 'reloaded_note_1',
          title: 'Advanced Algorithms',
          subject: 'Computer Science',
          content: 'Graph algorithms, Dijkstra, and Bellman-Ford.',
          date: 'Oct 21, 2026',
        ),
      ]);
      await AppDataService.instance.saveTasks([
        TaskItem(
          id: 'reloaded_task_1',
          title: 'Complete Homework 4',
          isCompleted: false,
          due: 'Due Tomorrow',
        ),
      ]);
      await AppDataService.instance.saveTimetable([
        TimetableEntry(
          id: 'reloaded_entry_1',
          subject: 'Algorithms Lecture',
          day: 'Mon',
          startTime: const TimeOfDay(hour: 14, minute: 0),
          endTime: const TimeOfDay(hour: 15, minute: 30),
        ),
      ]);
      await tester.pumpAndSettle();

      // 6. Reload page again
      simulateColdAppRestart();
      await AppDataService.instance.initialize(forceReload: true);
      await tester.pumpWidget(MaterialApp(key: UniqueKey(), home: const MainShell()));
      await tester.pumpAndSettle();

      // 7. Verify all added entries remain after second reload
      expect(find.text('1 item'), findsWidgets);

      await tester.tap(find.byIcon(Icons.menu_book_rounded).last);
      await tester.pumpAndSettle();
      expect(find.text('Advanced Algorithms'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.check_circle_outline_rounded).last);
      await tester.pumpAndSettle();
      expect(find.text('Complete Homework 4'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.calendar_month_rounded).last);
      await tester.pumpAndSettle();
      expect(find.text('Algorithms Lecture'), findsOneWidget);
    });
  });
}
