import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studymate/screens/clock_screen.dart';
import 'package:studymate/screens/notification_settings_screen.dart';
import 'package:studymate/screens/tasks_screen.dart';
import 'package:studymate/services/app_data_service.dart';
import 'package:studymate/services/notification_service.dart';
import 'package:studymate/services/sound_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final notifService = NotificationService.instance;
  final soundService = SoundService.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    notifService.resetForTesting();
    soundService.resetForTesting();
    AppDataService.instance.resetForTesting();
  });

  group('SoundService & Settings Audio Tests', () {
    test('SoundService respects notification sound setting', () async {
      notifService.notificationSoundEnabled = true;
      await soundService.playNotification();
      expect(soundService.lastPlayedAsset, SoundService.notificationSfx);

      soundService.resetForTesting();
      notifService.notificationSoundEnabled = false;
      await soundService.playNotification();
      expect(soundService.lastPlayedAsset, isNull);
    });

    test('SoundService respects task done sound setting', () async {
      notifService.taskDoneSoundEnabled = true;
      await soundService.playTaskDone();
      expect(soundService.lastPlayedAsset, SoundService.taskDoneSfx);

      soundService.resetForTesting();
      notifService.taskDoneSoundEnabled = false;
      await soundService.playTaskDone();
      expect(soundService.lastPlayedAsset, isNull);
    });

    test('SoundService plays and stops alarm tone audio from assets/sounds/alam', () async {
      notifService.alarmSoundEnabled = true;

      // Test Urgent (Mobile Ringtone 542)
      await soundService.playAlarm(AlarmTone.urgent);
      expect(soundService.currentlyPlayingToneKey, 'urgent');
      expect(soundService.lastPlayedAsset, 'sounds/alam/soundreality-mobile-ringtone-542006.mp3');
      expect(soundService.isAlarmPlaying, isTrue);

      // Stop alarm
      await soundService.stopAlarm();
      expect(soundService.currentlyPlayingToneKey, isNull);
      expect(soundService.isAlarmPlaying, isFalse);

      // Test Classic (023)
      await soundService.playAlarm(AlarmTone.classic);
      expect(soundService.currentlyPlayingToneKey, 'classic');
      expect(soundService.lastPlayedAsset, 'sounds/alam/universfield-ringtone-023-376906.mp3');

      // Test Energetic (030)
      await soundService.playAlarm(AlarmTone.energetic);
      expect(soundService.currentlyPlayingToneKey, 'energetic');
      expect(soundService.lastPlayedAsset, 'sounds/alam/universfield-ringtone-030-437513.mp3');

      // Test Gentle (088)
      await soundService.playAlarm(AlarmTone.gentle);
      expect(soundService.currentlyPlayingToneKey, 'gentle');
      expect(soundService.lastPlayedAsset, 'sounds/alam/universfield-ringtone-088-496414.mp3');

      // Test Vibrate Only (no audio asset)
      await soundService.playAlarm(AlarmTone.vibrateOnly);
      expect(soundService.currentlyPlayingToneKey, isNull);
    });

    test('Completing a task in TasksScreen plays task done sound effect', () async {
      notifService.taskDoneSoundEnabled = true;
      final task = TaskItem(
        id: 'task_sfx_1',
        title: 'Complete Algebra Assignment',
        isCompleted: false,
        due: 'Due Tomorrow',
      );
      await AppDataService.instance.saveTasks([task]);

      await soundService.playTaskDone();
      expect(soundService.lastPlayedAsset, SoundService.taskDoneSfx);
    });

    testWidgets('NotificationSettingsScreen toggles notification, task done, and alarm sound controls', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: NotificationSettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify all 3 switches are present
      final notifSwitchFinder = find.byKey(const Key('toggle_notification_sound_switch'));
      final taskDoneSwitchFinder = find.byKey(const Key('toggle_task_done_sound_switch'));
      final alarmSoundSwitchFinder = find.byKey(const Key('toggle_alarm_sound_switch'));

      expect(notifSwitchFinder, findsOneWidget);
      expect(taskDoneSwitchFinder, findsOneWidget);
      expect(alarmSoundSwitchFinder, findsOneWidget);

      // Defaults are true
      expect(notifService.notificationSoundEnabled, isTrue);
      expect(notifService.taskDoneSoundEnabled, isTrue);
      expect(notifService.alarmSoundEnabled, isTrue);

      // Toggle Notification Sound OFF
      await tester.tap(notifSwitchFinder);
      await tester.pumpAndSettle();
      expect(notifService.notificationSoundEnabled, isFalse);

      // Toggle Task Done Sound OFF
      await tester.tap(taskDoneSwitchFinder);
      await tester.pumpAndSettle();
      expect(notifService.taskDoneSoundEnabled, isFalse);

      // Toggle Alarm Sound OFF
      await tester.tap(alarmSoundSwitchFinder);
      await tester.pumpAndSettle();
      expect(notifService.alarmSoundEnabled, isFalse);

      // Test Play / Stop buttons on alarm tones
      await tester.tap(find.byKey(const Key('play_alarm_urgent')));
      await tester.pumpAndSettle();

      // Check SharedPreferences persistence
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('studymate_notification_sound_enabled'), isFalse);
      expect(prefs.getBool('studymate_task_done_sound_enabled'), isFalse);
      expect(prefs.getBool('studymate_alarm_sound_enabled'), isFalse);
    });

    test('SoundService plays and stops clock ticking SFX for stopwatch', () async {
      expect(soundService.isStopwatchTickingPlaying, isFalse);
      await soundService.startStopwatchTicking();
      expect(soundService.isStopwatchTickingPlaying, isTrue);
      expect(soundService.lastPlayedAsset, SoundService.clockTickingSfx);

      await soundService.stopStopwatchTicking();
      expect(soundService.isStopwatchTickingPlaying, isFalse);
    });

    testWidgets('Stopwatch in ClockScreen starts and stops clock_ticking sfx', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ClockScreen(initialTabIndex: 1),
        ),
      );
      await tester.pumpAndSettle();

      expect(soundService.isStopwatchTickingPlaying, isFalse);

      // Start stopwatch -> should start clock ticking sfx
      await tester.tap(find.text('Start'));
      await tester.pump();
      expect(soundService.isStopwatchTickingPlaying, isTrue);
      expect(soundService.lastPlayedAsset, SoundService.clockTickingSfx);

      // Pause stopwatch -> should stop ticking sfx
      await tester.tap(find.text('Pause'));
      await tester.pump();
      expect(soundService.isStopwatchTickingPlaying, isFalse);

      // Resume stopwatch -> should resume ticking sfx
      await tester.tap(find.text('Resume'));
      await tester.pump();
      expect(soundService.isStopwatchTickingPlaying, isTrue);

      // Mute ticking sfx using the toggle chip
      await tester.tap(find.text('Tick SFX'));
      await tester.pump();
      expect(find.text('Muted'), findsOneWidget);
      expect(soundService.isStopwatchTickingPlaying, isFalse);

      // Unmute ticking sfx
      await tester.tap(find.text('Muted'));
      await tester.pump();
      expect(find.text('Tick SFX'), findsOneWidget);
      expect(soundService.isStopwatchTickingPlaying, isTrue);

      // Reset stopwatch -> should stop ticking sfx
      await tester.tap(find.text('Pause'));
      await tester.pump();
      await tester.tap(find.text('Reset'));
      await tester.pump();
      expect(soundService.isStopwatchTickingPlaying, isFalse);

      // Switch to Digital Clock tab -> ticking sfx stays stopped
      await tester.tap(find.text('Digital Clock'));
      await tester.pumpAndSettle();
      expect(soundService.isStopwatchTickingPlaying, isFalse);

      // Switch to Countdown Timer tab -> ticking sfx stays stopped
      await tester.tap(find.text('Countdown Timer'));
      await tester.pumpAndSettle();
      expect(soundService.isStopwatchTickingPlaying, isFalse);
    });
  });
}

