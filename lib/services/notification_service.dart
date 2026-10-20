import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../screens/timetable_screen.dart';
import '../screens/tasks_screen.dart';
import 'sound_service.dart';

enum AlarmTone {
  urgent(
    key: 'urgent',
    label: 'Mobile Ringtone',
    subtitle: 'Ringtone 542 with urgent buzz',
    soundAsset: 'sounds/alam/soundreality-mobile-ringtone-542006.mp3',
    channelId: 'studymate_channel_urgent',
    channelName: 'StudyMate Urgent Alarms',
    importance: Importance.max,
    priority: Priority.max,
    audioUsage: AudioAttributesUsage.alarm,
    category: AndroidNotificationCategory.alarm,
    playSound: true,
    vibrationPattern: [0, 800, 250, 800, 250, 800],
  ),
  classic(
    key: 'classic',
    label: 'Classic Ringtone (023)',
    subtitle: 'Ringtone 023 with double buzz',
    soundAsset: 'sounds/alam/universfield-ringtone-023-376906.mp3',
    channelId: 'studymate_channel_classic',
    channelName: 'StudyMate Classic Chimes',
    importance: Importance.max,
    priority: Priority.high,
    audioUsage: AudioAttributesUsage.notification,
    category: AndroidNotificationCategory.reminder,
    playSound: true,
    vibrationPattern: [0, 500, 250, 500],
  ),
  energetic(
    key: 'energetic',
    label: 'Energetic Tone (030)',
    subtitle: 'Ringtone 030 with upbeat rhythm',
    soundAsset: 'sounds/alam/universfield-ringtone-030-437513.mp3',
    channelId: 'studymate_channel_energetic',
    channelName: 'StudyMate Energetic Alarms',
    importance: Importance.max,
    priority: Priority.high,
    audioUsage: AudioAttributesUsage.alarm,
    category: AndroidNotificationCategory.alarm,
    playSound: true,
    vibrationPattern: [0, 400, 200, 400, 200, 400],
  ),
  gentle(
    key: 'gentle',
    label: 'Gentle Pulse (088)',
    subtitle: 'Ringtone 088 with gentle buzz',
    soundAsset: 'sounds/alam/universfield-ringtone-088-496414.mp3',
    channelId: 'studymate_channel_gentle',
    channelName: 'StudyMate Gentle Reminders',
    importance: Importance.high,
    priority: Priority.defaultPriority,
    audioUsage: AudioAttributesUsage.notification,
    category: AndroidNotificationCategory.reminder,
    playSound: true,
    vibrationPattern: [0, 350],
  ),
  vibrateOnly(
    key: 'vibrate',
    label: 'Vibrate Only',
    subtitle: 'Silent alert with long vibration',
    soundAsset: null,
    channelId: 'studymate_channel_vibrate',
    channelName: 'StudyMate Vibrate Only',
    importance: Importance.high,
    priority: Priority.high,
    audioUsage: AudioAttributesUsage.notification,
    category: AndroidNotificationCategory.reminder,
    playSound: false,
    vibrationPattern: [0, 1000, 350, 1000],
  );

  final String key;
  final String label;
  final String subtitle;
  final String? soundAsset;
  final String channelId;
  final String channelName;
  final Importance importance;
  final Priority priority;
  final AudioAttributesUsage audioUsage;
  final AndroidNotificationCategory category;
  final bool playSound;
  final List<int> vibrationPattern;

  const AlarmTone({
    required this.key,
    required this.label,
    required this.subtitle,
    required this.soundAsset,
    required this.channelId,
    required this.channelName,
    required this.importance,
    required this.priority,
    required this.audioUsage,
    required this.category,
    required this.playSound,
    required this.vibrationPattern,
  });

  static AlarmTone fromKey(String? key) {
    return AlarmTone.values.firstWhere(
      (t) => t.key == key,
      orElse: () => AlarmTone.urgent,
    );
  }
}

class ScheduledReminderInfo {
  final int id;
  final String title;
  final String subtitle;
  final String type; // 'class' or 'task'
  final DateTime? scheduledTime;
  final String? recurringDay;

  const ScheduledReminderInfo({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    this.scheduledTime,
    this.recurringDay,
  });
}

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool isTestMode = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  bool get _canUsePlugin => _isInitialized && !isTestMode;

  /// Test inspection hooks to verify scheduling and cancellation
  @visibleForTesting
  final List<Map<String, dynamic>> scheduledRecords = [];
  @visibleForTesting
  final List<int> cancelledRecordIds = [];

  @visibleForTesting
  void resetForTesting() {
    isTestMode = true;
    _isInitialized = true;
    scheduledRecords.clear();
    cancelledRecordIds.clear();
    classRemindersEnabled = true;
    classReminderLeadMinutes = 10;
    taskRemindersEnabled = true;
    selectedAlarmTone = AlarmTone.urgent;
    notificationSoundEnabled = true;
    taskDoneSoundEnabled = true;
    alarmSoundEnabled = true;
    SoundService.instance.resetForTesting();
    _ensureTimeZone();
  }

  // Settings
  bool classRemindersEnabled = true;
  int classReminderLeadMinutes = 10;
  bool taskRemindersEnabled = true;
  AlarmTone selectedAlarmTone = AlarmTone.urgent;
  bool notificationSoundEnabled = true;
  bool taskDoneSoundEnabled = true;
  bool alarmSoundEnabled = true;

  static const String _kPrefClassEnabled = 'studymate_class_reminders_enabled';
  static const String _kPrefClassLead = 'studymate_class_reminder_lead_minutes';
  static const String _kPrefTaskEnabled = 'studymate_task_reminders_enabled';
  static const String _kPrefAlarmTone = 'studymate_alarm_tone';
  static const String _kPrefNotificationSound = 'studymate_notification_sound_enabled';
  static const String _kPrefTaskDoneSound = 'studymate_task_done_sound_enabled';
  static const String _kPrefAlarmSound = 'studymate_alarm_sound_enabled';
  static const String _kPrefPermissionGranted = 'studymate_notifications_permission_granted';

  /// Build notification details tailored to the selected alarm tone
  NotificationDetails getNotificationDetails({AlarmTone? tone}) {
    final t = tone ?? selectedAlarmTone;
    final androidDetails = AndroidNotificationDetails(
      t.channelId,
      t.channelName,
      channelDescription: 'StudyMate ${t.label} notifications',
      importance: t.importance,
      priority: t.priority,
      playSound: t.playSound,
      enableVibration: true,
      vibrationPattern: Int64List.fromList(t.vibrationPattern),
      audioAttributesUsage: t.audioUsage,
      category: t.category,
      fullScreenIntent: true,
      ticker: 'StudyMate: ${t.label}',
      visibility: NotificationVisibility.public,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    return NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
  }

  /// Initialize notifications, channels and timezone database
  Future<void> initialize() async {
    if (_isInitialized) return;

    _ensureTimeZone();

    if (!isTestMode) {
      try {
        const AndroidInitializationSettings initializationSettingsAndroid =
            AndroidInitializationSettings('@mipmap/ic_launcher');

        const DarwinInitializationSettings initializationSettingsDarwin =
            DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );

        const InitializationSettings initializationSettings = InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

        await _plugin.initialize(
          settings: initializationSettings,
          onDidReceiveNotificationResponse: (NotificationResponse details) {
            debugPrint('Notification clicked: ${details.payload}');
          },
        );

        // Register all Android notification channels with their tone and vibration settings
        if (!kIsWeb && Platform.isAndroid) {
          final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
          if (androidPlugin != null) {
            for (final tone in AlarmTone.values) {
              await androidPlugin.createNotificationChannel(
                AndroidNotificationChannel(
                  tone.channelId,
                  tone.channelName,
                  description: 'StudyMate ${tone.label} notifications',
                  importance: tone.importance,
                  playSound: tone.playSound,
                  enableVibration: true,
                  vibrationPattern: Int64List.fromList(tone.vibrationPattern),
                  audioAttributesUsage: tone.audioUsage,
                ),
              );
            }
          }
        }

        _isInitialized = true;
      } catch (e) {
        debugPrint('NotificationService initialize error: $e');
      }
    } else {
      _isInitialized = true;
    }

    await loadSettings();
    await reconcileAllReminders();
  }

  void _ensureTimeZone() {
    try {
      tz.local;
    } catch (_) {
      _setupTimeZone();
    }
  }

  void _setupTimeZone() {
    tz.initializeTimeZones();
    try {
      final timeZoneName = DateTime.now().timeZoneName;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      try {
        final offset = DateTime.now().timeZoneOffset;
        final locationName = tz.timeZoneDatabase.locations.entries.firstWhere(
          (entry) => entry.value.currentTimeZone.offset == offset,
          orElse: () => tz.timeZoneDatabase.locations.entries.first,
        ).key;
        tz.setLocalLocation(tz.getLocation(locationName));
      } catch (_) {
        try {
          tz.setLocalLocation(tz.getLocation('UTC'));
        } catch (_) {}
      }
    }
  }

  /// Load persisted reminder settings
  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      classRemindersEnabled = prefs.getBool(_kPrefClassEnabled) ?? true;
      classReminderLeadMinutes = prefs.getInt(_kPrefClassLead) ?? 10;
      taskRemindersEnabled = prefs.getBool(_kPrefTaskEnabled) ?? true;
      final toneKey = prefs.getString(_kPrefAlarmTone);
      selectedAlarmTone = AlarmTone.fromKey(toneKey);
      notificationSoundEnabled = prefs.getBool(_kPrefNotificationSound) ?? true;
      taskDoneSoundEnabled = prefs.getBool(_kPrefTaskDoneSound) ?? true;
      alarmSoundEnabled = prefs.getBool(_kPrefAlarmSound) ?? true;
    } catch (e) {
      debugPrint('Error loading reminder settings: $e');
    }
  }

  /// Save reminder settings
  Future<void> saveSettings({
    bool? classEnabled,
    int? leadMinutes,
    bool? taskEnabled,
    AlarmTone? alarmTone,
    bool? notificationSound,
    bool? taskDoneSound,
    bool? alarmSound,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (classEnabled != null) {
        classRemindersEnabled = classEnabled;
        await prefs.setBool(_kPrefClassEnabled, classEnabled);
      }
      if (leadMinutes != null) {
        classReminderLeadMinutes = leadMinutes;
        await prefs.setInt(_kPrefClassLead, leadMinutes);
      }
      if (taskEnabled != null) {
        taskRemindersEnabled = taskEnabled;
        await prefs.setBool(_kPrefTaskEnabled, taskEnabled);
      }
      if (alarmTone != null) {
        selectedAlarmTone = alarmTone;
        await prefs.setString(_kPrefAlarmTone, alarmTone.key);
      }
      if (notificationSound != null) {
        notificationSoundEnabled = notificationSound;
        await prefs.setBool(_kPrefNotificationSound, notificationSound);
      }
      if (taskDoneSound != null) {
        taskDoneSoundEnabled = taskDoneSound;
        await prefs.setBool(_kPrefTaskDoneSound, taskDoneSound);
      }
      if (alarmSound != null) {
        alarmSoundEnabled = alarmSound;
        await prefs.setBool(_kPrefAlarmSound, alarmSound);
      }
    } catch (e) {
      debugPrint('Error saving reminder settings: $e');
    }
  }

  /// Request permissions on Android and iOS
  Future<bool> requestPermission() async {
    if (isTestMode) return true;
    bool granted = false;

    try {
      if (!_isInitialized) {
        await initialize();
      }

      if (!kIsWeb && Platform.isAndroid) {
        final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          final res = await androidPlugin.requestNotificationsPermission();
          granted = res ?? false;
        }
      } else if (!kIsWeb && Platform.isIOS) {
        final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        if (iosPlugin != null) {
          final res = await iosPlugin.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
          granted = res ?? false;
        }
      } else {
        granted = true;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPrefPermissionGranted, granted);
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
    }

    return granted;
  }

  /// Check if notification permissions are granted
  Future<bool> isPermissionGranted() async {
    if (isTestMode) return true;
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          final enabled = await androidPlugin.areNotificationsEnabled();
          return enabled ?? false;
        }
      }
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_kPrefPermissionGranted) ?? false;
    } catch (_) {
      return false;
    }
  }

  // ── ID Generators ──────────────────────────────────────────────────────────

  int classNotificationId(String classId) {
    return (classId.hashCode.abs() % 400000000) + 100000000;
  }

  int taskNotificationId(String taskId) {
    return (taskId.hashCode.abs() % 400000000) + 500000000;
  }

  static const int testNotificationId = 999999999;

  // ── Class Reminders ────────────────────────────────────────────────────────

  int? _dayToWeekday(String day) {
    switch (day.toLowerCase().trim()) {
      case 'mon':
      case 'monday':
        return DateTime.monday;
      case 'tue':
      case 'tuesday':
        return DateTime.tuesday;
      case 'wed':
      case 'wednesday':
        return DateTime.wednesday;
      case 'thu':
      case 'thursday':
        return DateTime.thursday;
      case 'fri':
      case 'friday':
        return DateTime.friday;
      case 'sat':
      case 'saturday':
        return DateTime.saturday;
      case 'sun':
      case 'sunday':
        return DateTime.sunday;
      default:
        return null;
    }
  }

  tz.TZDateTime _nextInstanceOfDayAndTime(int targetWeekday, int targetHour, int targetMinute) {
    _ensureTimeZone();
    final now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      targetHour,
      targetMinute,
    );

    while (scheduledDate.weekday != targetWeekday || scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  /// Schedule recurring weekly reminder for a timetable class
  Future<void> scheduleClassReminder(TimetableEntry entry, {int? leadMinutes}) async {
    if (!classRemindersEnabled) return;

    if (!_isInitialized && !isTestMode) {
      await initialize();
    }

    final lead = leadMinutes ?? classReminderLeadMinutes;
    final weekday = _dayToWeekday(entry.day);
    if (weekday == null) return;

    int totalMinutes = entry.startTime.hour * 60 + entry.startTime.minute - lead;
    int reminderWeekday = weekday;
    if (totalMinutes < 0) {
      totalMinutes += 24 * 60;
      reminderWeekday = (weekday == 1) ? 7 : weekday - 1;
    }
    final reminderHour = totalMinutes ~/ 60;
    final reminderMinute = totalMinutes % 60;

    final scheduledDate = _nextInstanceOfDayAndTime(reminderWeekday, reminderHour, reminderMinute);
    final id = classNotificationId(entry.id);

    final leadText = lead == 0
        ? 'is starting now'
        : 'starts in $lead minute${lead == 1 ? '' : 's'}';

    scheduledRecords.removeWhere((r) => r['id'] == id);
    scheduledRecords.add({
      'type': 'class',
      'id': id,
      'entryId': entry.id,
      'title': 'Class: ${entry.subject}',
      'body': '${entry.subject} $leadText (${entry.formattedTime})',
      'scheduledDate': scheduledDate,
      'weekday': reminderWeekday,
      'hour': reminderHour,
      'minute': reminderMinute,
      'leadMinutes': lead,
      'tone': selectedAlarmTone.key,
    });

    if (_canUsePlugin) {
      try {
        await _plugin.zonedSchedule(
          id: id,
          title: 'Class: ${entry.subject}',
          body: '${entry.subject} $leadText (${entry.formattedTime})',
          scheduledDate: scheduledDate,
          notificationDetails: getNotificationDetails(),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: 'class:${entry.id}',
        );
      } catch (_) {
        try {
          await _plugin.zonedSchedule(
            id: id,
            title: 'Class: ${entry.subject}',
            body: '${entry.subject} $leadText (${entry.formattedTime})',
            scheduledDate: scheduledDate,
            notificationDetails: getNotificationDetails(),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
            payload: 'class:${entry.id}',
          );
        } catch (e) {
          debugPrint('Failed to schedule class reminder: $e');
        }
      }
    }
  }

  /// Cancel reminder for a specific class
  Future<void> cancelClassReminder(String classId) async {
    final id = classNotificationId(classId);
    cancelledRecordIds.add(id);
    scheduledRecords.removeWhere((r) => r['id'] == id);

    if (_canUsePlugin) {
      try {
        await _plugin.cancel(id: id);
      } catch (e) {
        debugPrint('Error canceling class reminder: $e');
      }
    }
  }

  /// Cancel all class reminders
  Future<void> cancelAllClassReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('timetable_entries_v2');
      if (raw != null) {
        final List decoded = jsonDecode(raw) as List;
        for (final item in decoded) {
          if (item is Map && item['id'] != null) {
            await cancelClassReminder(item['id'].toString());
          }
        }
      }
      scheduledRecords.removeWhere((r) => r['type'] == 'class');
    } catch (e) {
      debugPrint('Error canceling all class reminders: $e');
    }
  }

  // ── Task Reminders ─────────────────────────────────────────────────────────

  /// Schedule one-shot reminder for a task if a valid date and time are available
  Future<void> scheduleTaskReminder(TaskItem task) async {
    final id = taskNotificationId(task.id);

    if (!taskRemindersEnabled || task.isCompleted) {
      await cancelTaskReminder(task.id);
      return;
    }

    if (!_isInitialized && !isTestMode) {
      await initialize();
    }

    // Requirement 4: Schedule task reminders only when a valid due date/time and reminder time are available. Do not invent missing times.
    final reminderTime = task.reminderDateTime ?? task.dueDateTime;
    if (reminderTime == null) {
      // Missing specific time -> do not invent missing times.
      return;
    }

    if (reminderTime.isBefore(DateTime.now())) {
      // Past time -> cancel any existing reminder and do not schedule
      await cancelTaskReminder(task.id);
      return;
    }

    _ensureTimeZone();
    final tzReminderTime = tz.TZDateTime.from(reminderTime, tz.local);

    scheduledRecords.removeWhere((r) => r['id'] == id);
    scheduledRecords.add({
      'type': 'task',
      'id': id,
      'taskId': task.id,
      'title': 'Task Due: ${task.title}',
      'body': 'Due: ${task.due}',
      'scheduledDate': tzReminderTime,
      'tone': selectedAlarmTone.key,
    });

    if (_canUsePlugin) {
      try {
        await _plugin.zonedSchedule(
          id: id,
          title: 'Task Due: ${task.title}',
          body: 'Due: ${task.due}',
          scheduledDate: tzReminderTime,
          notificationDetails: getNotificationDetails(),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: 'task:${task.id}',
        );
      } catch (_) {
        try {
          await _plugin.zonedSchedule(
            id: id,
            title: 'Task Due: ${task.title}',
            body: 'Due: ${task.due}',
            scheduledDate: tzReminderTime,
            notificationDetails: getNotificationDetails(),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: 'task:${task.id}',
          );
        } catch (e) {
          debugPrint('Failed to schedule task reminder: $e');
        }
      }
    }
  }

  /// Cancel reminder for a specific task
  Future<void> cancelTaskReminder(String taskId) async {
    final id = taskNotificationId(taskId);
    cancelledRecordIds.add(id);
    scheduledRecords.removeWhere((r) => r['id'] == id);

    if (_canUsePlugin) {
      try {
        await _plugin.cancel(id: id);
      } catch (e) {
        debugPrint('Error canceling task reminder: $e');
      }
    }
  }

  /// Cancel all task reminders
  Future<void> cancelAllTaskReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('studymate_tasks_json');
      if (raw != null) {
        final List decoded = jsonDecode(raw) as List;
        for (final item in decoded) {
          if (item is Map && item['id'] != null) {
            await cancelTaskReminder(item['id'].toString());
          }
        }
      }
      scheduledRecords.removeWhere((r) => r['type'] == 'task');
    } catch (e) {
      debugPrint('Error canceling all task reminders: $e');
    }
  }

  // ── Tone Preview ───────────────────────────────────────────────────────────

  /// Preview alarm ringtone audio and tactile buzz vibration corresponding to the chosen tone
  Future<void> previewTone(AlarmTone tone, {bool playAudio = true}) async {
    if (playAudio && alarmSoundEnabled) {
      await SoundService.instance.playAlarm(tone);
    }
    if (isTestMode) return;
    try {
      if (tone == AlarmTone.urgent) {
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 200));
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 200));
        await HapticFeedback.heavyImpact();
      } else if (tone == AlarmTone.classic) {
        await HapticFeedback.mediumImpact();
        await Future.delayed(const Duration(milliseconds: 220));
        await HapticFeedback.mediumImpact();
      } else if (tone == AlarmTone.energetic) {
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 150));
        await HapticFeedback.mediumImpact();
      } else if (tone == AlarmTone.gentle) {
        await HapticFeedback.lightImpact();
      } else {
        await HapticFeedback.vibrate();
      }
    } catch (_) {}
  }

  // ── Test Notification ──────────────────────────────────────────────────────

  /// Send an immediate notification to test audio, banner, and device setup
  Future<void> sendTestNotification() async {
    // 1. Play real alarm tone or notification SFX based on settings
    if (alarmSoundEnabled) {
      await SoundService.instance.playAlarm(selectedAlarmTone);
    } else if (notificationSoundEnabled) {
      await SoundService.instance.playNotification();
    }

    // 2. Physically buzz phone immediately for tactile feedback
    await previewTone(selectedAlarmTone, playAudio: false);

    // 2. Ensure service is initialized
    if (!_isInitialized && !isTestMode) {
      await initialize();
    }

    scheduledRecords.add({
      'type': 'test',
      'id': testNotificationId,
      'title': 'StudyMate Alarm Active',
      'body': 'Tone: ${selectedAlarmTone.label} - reminders and buzzing are working!',
      'tone': selectedAlarmTone.key,
    });

    if (_canUsePlugin) {
      try {
        await _plugin.show(
          id: testNotificationId,
          title: 'StudyMate Alarm Active',
          body: 'Tone: ${selectedAlarmTone.label} - reminders and buzzing are working!',
          notificationDetails: getNotificationDetails(),
          payload: 'test',
        );
      } catch (e) {
        debugPrint('Error sending test notification: $e');
      }
    }
  }

  // ── Reconcile Reminders (Startup / Sync) ───────────────────────────────────

  /// Reconcile scheduled notifications after app startup to ensure consistency with saved data
  Future<void> reconcileAllReminders() async {
    try {
      await loadSettings();
      final prefs = await SharedPreferences.getInstance();

      // 1. Classes reconciliation
      if (classRemindersEnabled) {
        final rawTimetable = prefs.getString('timetable_entries_v2');
        if (rawTimetable != null) {
          try {
            final List decoded = jsonDecode(rawTimetable) as List;
            for (final item in decoded) {
              if (item is Map) {
                final entry = TimetableEntry.fromJson(Map<String, dynamic>.from(item));
                await scheduleClassReminder(entry);
              }
            }
          } catch (_) {}
        }
      } else {
        await cancelAllClassReminders();
      }

      // 2. Tasks reconciliation
      if (taskRemindersEnabled) {
        final rawTasks = prefs.getString('studymate_tasks_json');
        if (rawTasks != null) {
          try {
            final List decoded = jsonDecode(rawTasks) as List;
            for (final item in decoded) {
              if (item is Map) {
                final task = TaskItem.fromMap(Map<String, dynamic>.from(item));
                await scheduleTaskReminder(task);
              }
            }
          } catch (_) {}
        }
      } else {
        await cancelAllTaskReminders();
      }
    } catch (e) {
      debugPrint('Error reconciling reminders: $e');
    }
  }

  /// Cancel all active notifications
  Future<void> cancelAll() async {
    scheduledRecords.clear();
    if (_canUsePlugin) {
      try {
        await _plugin.cancelAll();
      } catch (e) {
        debugPrint('Error canceling all notifications: $e');
      }
    }
  }

  /// Get scheduled reminders summary for UI display
  Future<List<ScheduledReminderInfo>> getScheduledRemindersSummary() async {
    final list = <ScheduledReminderInfo>[];
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Classes
      if (classRemindersEnabled) {
        final rawTimetable = prefs.getString('timetable_entries_v2');
        if (rawTimetable != null) {
          final List decoded = jsonDecode(rawTimetable) as List;
          for (final item in decoded) {
            if (item is Map) {
              final entry = TimetableEntry.fromJson(Map<String, dynamic>.from(item));
              final lead = classReminderLeadMinutes;
              final leadText = lead == 0 ? 'at start' : '$lead min before';
              list.add(ScheduledReminderInfo(
                id: classNotificationId(entry.id),
                title: entry.subject,
                subtitle: 'Every ${entry.day} at ${entry.formattedTime} ($leadText) • ${selectedAlarmTone.label}',
                type: 'class',
                recurringDay: entry.day,
              ));
            }
          }
        }
      }

      // 2. Tasks with valid reminders
      if (taskRemindersEnabled) {
        final rawTasks = prefs.getString('studymate_tasks_json');
        if (rawTasks != null) {
          final List decoded = jsonDecode(rawTasks) as List;
          for (final item in decoded) {
            if (item is Map) {
              final task = TaskItem.fromMap(Map<String, dynamic>.from(item));
              final reminder = task.reminderDateTime ?? task.dueDateTime;
              if (!task.isCompleted && reminder != null && reminder.isAfter(DateTime.now())) {
                list.add(ScheduledReminderInfo(
                  id: taskNotificationId(task.id),
                  title: task.title,
                  subtitle: 'Due: ${task.due} • ${selectedAlarmTone.label}',
                  type: 'task',
                  scheduledTime: reminder,
                ));
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting scheduled reminders summary: $e');
    }
    return list;
  }
}
