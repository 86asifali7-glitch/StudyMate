import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';

/// Centralized audio service for StudyMate.
/// Manages playback of real alarm sounds, notification SFX, and task done celebration SFX.
class SoundService {
  SoundService._internal();
  static final SoundService instance = SoundService._internal();

  AudioPlayer? _alarmPlayer;
  AudioPlayer? _sfxPlayer;
  AudioPlayer? _stopwatchPlayer;

  bool isTestMode = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  String? currentlyPlayingToneKey;
  bool isAlarmPlaying = false;
  bool isStopwatchTickingPlaying = false;
  String? lastPlayedAsset;

  // Asset paths relative to 'assets/'
  static const String notificationSfx = 'sounds/sfx/Notification Sfx.mp3';
  static const String taskDoneSfx = 'sounds/sfx/Task Done Sfx.mp3';
  static const String clockTickingSfx = 'sounds/sfx/clock_ticking.mp3';

  AudioPlayer? _getAlarmPlayer() {
    if (isTestMode) return null;
    try {
      return _alarmPlayer ??= AudioPlayer();
    } catch (e) {
      debugPrint('Error creating alarm AudioPlayer: $e');
      return null;
    }
  }

  AudioPlayer? _getSfxPlayer() {
    if (isTestMode) return null;
    try {
      return _sfxPlayer ??= AudioPlayer();
    } catch (e) {
      debugPrint('Error creating sfx AudioPlayer: $e');
      return null;
    }
  }

  AudioPlayer? _getStopwatchPlayer() {
    if (isTestMode) return null;
    try {
      return _stopwatchPlayer ??= AudioPlayer();
    } catch (e) {
      debugPrint('Error creating stopwatch AudioPlayer: $e');
      return null;
    }
  }

  /// Play the notification sound effect if enabled
  Future<void> playNotification() async {
    if (!NotificationService.instance.notificationSoundEnabled) return;
    lastPlayedAsset = notificationSfx;
    if (isTestMode) return;
    try {
      final player = _getSfxPlayer();
      if (player != null) {
        await player.stop();
        await player.play(AssetSource(notificationSfx));
      }
    } catch (e) {
      debugPrint('Error playing notification sound: $e');
    }
  }

  /// Play the task done sound effect if enabled
  Future<void> playTaskDone() async {
    if (!NotificationService.instance.taskDoneSoundEnabled) return;
    lastPlayedAsset = taskDoneSfx;
    if (isTestMode) return;
    try {
      final player = _getSfxPlayer();
      if (player != null) {
        await player.stop();
        await player.play(AssetSource(taskDoneSfx));
      }
    } catch (e) {
      debugPrint('Error playing task done sound: $e');
    }
  }

  /// Play an alarm tone if alarm sound is enabled
  Future<void> playAlarm(AlarmTone tone) async {
    if (!NotificationService.instance.alarmSoundEnabled) return;
    if (tone.soundAsset == null) {
      await stopAlarm();
      return;
    }

    lastPlayedAsset = tone.soundAsset;
    currentlyPlayingToneKey = tone.key;
    isAlarmPlaying = true;

    if (isTestMode) return;
    try {
      final player = _getAlarmPlayer();
      if (player != null) {
        await player.stop();
        await player.play(AssetSource(tone.soundAsset!));
        player.onPlayerComplete.listen((_) {
          isAlarmPlaying = false;
          currentlyPlayingToneKey = null;
        });
      }
    } catch (e) {
      debugPrint('Error playing alarm tone: $e');
      isAlarmPlaying = false;
      currentlyPlayingToneKey = null;
    }
  }

  /// Stop any active alarm tone playback
  Future<void> stopAlarm() async {
    isAlarmPlaying = false;
    currentlyPlayingToneKey = null;
    if (isTestMode) return;
    try {
      await _alarmPlayer?.stop();
    } catch (_) {}
  }

  /// Play looping clock ticking sound effect for stopwatch
  Future<void> startStopwatchTicking() async {
    lastPlayedAsset = clockTickingSfx;
    isStopwatchTickingPlaying = true;
    if (isTestMode) return;
    try {
      final player = _getStopwatchPlayer();
      if (player != null) {
        await player.setReleaseMode(ReleaseMode.loop);
        await player.stop();
        await player.play(AssetSource(clockTickingSfx));
      }
    } catch (e) {
      debugPrint('Error playing stopwatch ticking: $e');
      isStopwatchTickingPlaying = false;
    }
  }

  /// Stop stopwatch ticking sound
  Future<void> stopStopwatchTicking() async {
    isStopwatchTickingPlaying = false;
    if (isTestMode) return;
    try {
      await _stopwatchPlayer?.stop();
    } catch (_) {}
  }

  /// Reset state for testing
  void resetForTesting() {
    isAlarmPlaying = false;
    isStopwatchTickingPlaying = false;
    currentlyPlayingToneKey = null;
    lastPlayedAsset = null;
  }
}
