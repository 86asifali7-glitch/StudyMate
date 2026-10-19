import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studymate/screens/home_screen.dart';
import 'package:studymate/screens/notification_settings_screen.dart';
import 'package:studymate/screens/tasks_screen.dart';
import 'package:studymate/screens/timetable_screen.dart';
import 'package:studymate/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = NotificationService.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    service.resetForTesting();
  });

  group('NotificationService - Class Reminders', () {
    test('schedules recurring weekly class reminder with lead time offset', () async {
      final entry = TimetableEntry(
        id: 'class_1',
        subject: 'Calculus II',
        day: 'Mon',
        startTime: const TimeOfDay(hour: 9, minute: 0),
        endTime: const TimeOfDay(hour: 10, minute: 30),
      );

      // Default lead time is 10 minutes -> expected 8:50 AM
      await service.scheduleClassReminder(entry);

      expect(service.scheduledRecords.length, 1);
      final record = service.scheduledRecords.first;
      expect(record['type'], 'class');
      expect(record['id'], service.classNotificationId('class_1'));
      expect(record['title'], 'Class: Calculus II');
      expect(record['weekday'], DateTime.monday);
      expect(record['hour'], 8);
      expect(record['minute'], 50);
      expect(record['leadMinutes'], 10);
    });

    test('schedules class reminder with custom lead time (0 min and 15 min)', () async {
      final entry = TimetableEntry(
        id: 'class_2',
        subject: 'Physics Mechanics',
        day: 'Wed',
        startTime: const TimeOfDay(hour: 11, minute: 15),
        endTime: const TimeOfDay(hour: 12, minute: 45),
      );

      // Lead 0 min -> starts at 11:15 AM
      await service.scheduleClassReminder(entry, leadMinutes: 0);
      expect(service.scheduledRecords.last['hour'], 11);
      expect(service.scheduledRecords.last['minute'], 15);
      expect(service.scheduledRecords.last['leadMinutes'], 0);

      // Lead 15 min -> starts at 11:00 AM
      await service.scheduleClassReminder(entry, leadMinutes: 15);
      expect(service.scheduledRecords.last['hour'], 11);
      expect(service.scheduledRecords.last['minute'], 0);
      expect(service.scheduledRecords.last['leadMinutes'], 15);
    });

    test('canceling a class reminder removes it and logs cancelled ID', () async {
      final entry = TimetableEntry(
        id: 'class_to_cancel',
        subject: 'Linear Algebra',
        day: 'Thu',
        startTime: const TimeOfDay(hour: 14, minute: 0),
        endTime: const TimeOfDay(hour: 15, minute: 30),
      );

      await service.scheduleClassReminder(entry);
      expect(service.scheduledRecords.any((r) => r['entryId'] == 'class_to_cancel'), isTrue);

      await service.cancelClassReminder('class_to_cancel');
      expect(service.scheduledRecords.any((r) => r['entryId'] == 'class_to_cancel'), isFalse);
      expect(service.cancelledRecordIds.contains(service.classNotificationId('class_to_cancel')), isTrue);
    });

    test('disabling class reminders prevents scheduling', () async {
      service.classRemindersEnabled = false;

      final entry = TimetableEntry(
        id: 'class_disabled',
        subject: 'Data Structures',
        day: 'Tue',
        startTime: const TimeOfDay(hour: 10, minute: 0),
        endTime: const TimeOfDay(hour: 11, minute: 30),
      );

      await service.scheduleClassReminder(entry);
      expect(service.scheduledRecords, isEmpty);
    });
  });

  group('NotificationService - Task Reminders & Missing Times (Requirement 4)', () {
    test('does NOT schedule reminder when task has no exact date/time (preserves presets without inventing times)', () async {
      final taskWithoutExactTime = TaskItem(
        id: 'task_preset_1',
        title: 'Complete Calculus Problem Set 3',
        isCompleted: false,
        due: 'Due Tomorrow',
        dueDateTime: null,
        reminderDateTime: null,
      );

      await service.scheduleTaskReminder(taskWithoutExactTime);
      expect(service.scheduledRecords, isEmpty,
          reason: 'Requirement 4: Do not invent missing times for tasks without specific date/time');
    });

    test('does NOT schedule reminder when task due date/time is in the past', () async {
      final pastTask = TaskItem(
        id: 'task_past',
        title: 'Past Assignment',
        isCompleted: false,
        due: 'Yesterday',
        dueDateTime: DateTime.now().subtract(const Duration(hours: 2)),
      );

      await service.scheduleTaskReminder(pastTask);
      expect(service.scheduledRecords, isEmpty);
      expect(service.cancelledRecordIds.contains(service.taskNotificationId('task_past')), isTrue);
    });

    test('schedules reminder when task has a valid future date/time', () async {
      final futureTime = DateTime.now().add(const Duration(hours: 3));
      final futureTask = TaskItem(
        id: 'task_future_1',
        title: 'Submit Lab Report',
        isCompleted: false,
        due: 'Due in 3 hours',
        dueDateTime: futureTime,
        reminderDateTime: futureTime,
      );

      await service.scheduleTaskReminder(futureTask);
      expect(service.scheduledRecords.length, 1);
      final record = service.scheduledRecords.first;
      expect(record['type'], 'task');
      expect(record['taskId'], 'task_future_1');
      expect(record['id'], service.taskNotificationId('task_future_1'));
      expect(record['title'], 'Task Due: Submit Lab Report');
    });

    test('cancels task reminder when completed, reschedules when uncompleted', () async {
      final futureTime = DateTime.now().add(const Duration(days: 1));
      final task = TaskItem(
        id: 'task_toggle',
        title: 'Study Physics',
        isCompleted: false,
        due: 'Tomorrow at 4 PM',
        dueDateTime: futureTime,
        reminderDateTime: futureTime,
      );

      // 1. Schedule
      await service.scheduleTaskReminder(task);
      expect(service.scheduledRecords.length, 1);

      // 2. Mark completed -> cancel
      task.isCompleted = true;
      await service.scheduleTaskReminder(task);
      expect(service.scheduledRecords.isEmpty, isTrue);
      expect(service.cancelledRecordIds.contains(service.taskNotificationId('task_toggle')), isTrue);

      // 3. Unmark completed -> reschedule
      task.isCompleted = false;
      await service.scheduleTaskReminder(task);
      expect(service.scheduledRecords.length, 1);
      expect(service.scheduledRecords.first['taskId'], 'task_toggle');
    });

    test('deleting a task cancels its reminder', () async {
      final futureTime = DateTime.now().add(const Duration(hours: 5));
      final task = TaskItem(
        id: 'task_to_delete',
        title: 'Delete Me',
        isCompleted: false,
        due: 'Today',
        dueDateTime: futureTime,
      );

      await service.scheduleTaskReminder(task);
      expect(service.scheduledRecords.length, 1);

      await service.cancelTaskReminder('task_to_delete');
      expect(service.scheduledRecords.isEmpty, isTrue);
      expect(service.cancelledRecordIds.contains(service.taskNotificationId('task_to_delete')), isTrue);
    });
  });

  group('NotificationService - Persistence, Reconciliation & Startup (Requirements 6 & 7)', () {
    test('persists and reloads notification settings locally', () async {
      await service.saveSettings(
        classEnabled: false,
        leadMinutes: 30,
        taskEnabled: false,
        alarmTone: AlarmTone.gentle,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('studymate_class_reminders_enabled'), false);
      expect(prefs.getInt('studymate_class_reminder_lead_minutes'), 30);
      expect(prefs.getBool('studymate_task_reminders_enabled'), false);
      expect(prefs.getString('studymate_alarm_tone'), 'gentle');

      // Reload
      await service.loadSettings();
      expect(service.classRemindersEnabled, false);
      expect(service.classReminderLeadMinutes, 30);
      expect(service.taskRemindersEnabled, false);
      expect(service.selectedAlarmTone, AlarmTone.gentle);
    });

    test('reconciles saved classes and tasks on app startup', () async {
      final futureTaskTime = DateTime.now().add(const Duration(days: 2));

      final testTimetable = [
        {
          'id': 'recon_class_1',
          'subject': 'Data Structures',
          'day': 'Tue',
          'startHour': 10,
          'startMinute': 0,
          'endHour': 11,
          'endMinute': 30,
        },
        {
          'id': 'recon_class_2',
          'subject': 'Calculus',
          'day': 'Fri',
          'startHour': 14,
          'startMinute': 0,
          'endHour': 15,
          'endMinute': 30,
        },
      ];

      final testTasks = [
        {
          'id': 'recon_task_1',
          'title': 'Task with Exact Date',
          'isCompleted': false,
          'due': 'In 2 days',
          'dueDateTime': futureTaskTime.toIso8601String(),
          'reminderDateTime': futureTaskTime.toIso8601String(),
        },
        {
          'id': 'recon_task_no_time',
          'title': 'Task Without Exact Time',
          'isCompleted': false,
          'due': 'Due Tomorrow',
        },
        {
          'id': 'recon_task_completed',
          'title': 'Completed Task',
          'isCompleted': true,
          'due': 'Completed',
          'dueDateTime': futureTaskTime.toIso8601String(),
        },
      ];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('timetable_entries_v2', jsonEncode(testTimetable));
      await prefs.setString('studymate_tasks_json', jsonEncode(testTasks));

      // Reconcile
      await service.reconcileAllReminders();

      // Scheduled should contain: 2 classes + 1 valid task = 3 items
      expect(service.scheduledRecords.length, 3);
      final classRecords = service.scheduledRecords.where((r) => r['type'] == 'class').toList();
      final taskRecords = service.scheduledRecords.where((r) => r['type'] == 'task').toList();

      expect(classRecords.length, 2);
      expect(classRecords.any((c) => c['entryId'] == 'recon_class_1'), isTrue);
      expect(classRecords.any((c) => c['entryId'] == 'recon_class_2'), isTrue);

      expect(taskRecords.length, 1);
      expect(taskRecords.first['taskId'], 'recon_task_1');

      // Summary list should also return the 3 items
      final summary = await service.getScheduledRemindersSummary();
      expect(summary.length, 3);
    });

    test('sendTestNotification triggers test alert without crashing', () async {
      await service.sendTestNotification();
      expect(service.scheduledRecords.any((r) => r['type'] == 'test'), isTrue);
    });
  });

  group('UI Flow & Notification Button (Requirement 8)', () {
    testWidgets('Home screen bell button opens NotificationSettingsScreen', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Find bell icon button
      final bellButton = find.byIcon(Icons.notifications_none_rounded);
      expect(bellButton, findsOneWidget);

      await tester.tap(bellButton);
      await tester.pumpAndSettle();

      // Should be on NotificationSettingsScreen
      expect(find.text('Notifications & Reminders'), findsOneWidget);
      expect(find.text('Timetable Class Reminders'), findsOneWidget);
      expect(find.text('Task Due Reminders'), findsOneWidget);
      expect(find.text('Alarm Tones & Vibration'), findsOneWidget);
    });

    testWidgets('NotificationSettingsScreen toggles switches, selects tone, and changes lead time', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: NotificationSettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('toggle_class_reminders_switch')), findsOneWidget);
      expect(find.byKey(const Key('toggle_task_reminders_switch')), findsOneWidget);

      // Select 'Classic Chime' tone
      await tester.tap(find.byKey(const Key('alarm_tone_classic')));
      await tester.pumpAndSettle();
      expect(service.selectedAlarmTone, AlarmTone.classic);

      // Tap Send Test button
      await tester.tap(find.byKey(const Key('send_test_notification_button')));
      await tester.pumpAndSettle();

      expect(service.scheduledRecords.any((r) => r['type'] == 'test'), isTrue);

      // Select 15 min lead time chip
      await tester.tap(find.byKey(const Key('lead_chip_15')));
      await tester.pumpAndSettle();
      expect(service.classReminderLeadMinutes, 15);

      // Toggle class reminders off
      await tester.tap(find.byKey(const Key('toggle_class_reminders_switch')));
      await tester.pumpAndSettle();
      expect(service.classRemindersEnabled, false);
    });
  });
}
