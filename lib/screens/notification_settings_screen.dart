import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/notification_service.dart';

const _kBgColor       = Color(0xFFF8F9FE);
const _kCardBg        = Color(0xFFFFFFFF);
const _kPrimaryBlue   = Color(0xFF4765FF);
const _kPurpleAccent  = Color(0xFF7551FF);
const _kTextHead      = Color(0xFF191D31);
const _kTextMuted     = Color(0xFF8C93A8);
const _kCardBorder    = Color(0xFFF1F3F9);
const _kSuccessGreen  = Color(0xFF10B981);
const _kWarningAmber  = Color(0xFFF59E0B);
const _kDangerCoral   = Color(0xFFEF4444);

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final NotificationService _notifService = NotificationService.instance;

  bool _isPermissionGranted = false;
  bool _isLoadingPermission = true;
  bool _classRemindersEnabled = true;
  int _classLeadMinutes = 10;
  bool _taskRemindersEnabled = true;
  AlarmTone _selectedTone = AlarmTone.urgent;
  List<ScheduledReminderInfo> _scheduledReminders = [];
  bool _isLoadingReminders = true;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    setState(() => _isLoadingPermission = true);
    await _notifService.loadSettings();

    final granted = await _notifService.isPermissionGranted();
    final summary = await _notifService.getScheduledRemindersSummary();

    if (mounted) {
      setState(() {
        _isPermissionGranted = granted;
        _isLoadingPermission = false;
        _classRemindersEnabled = _notifService.classRemindersEnabled;
        _classLeadMinutes = _notifService.classReminderLeadMinutes;
        _taskRemindersEnabled = _notifService.taskRemindersEnabled;
        _selectedTone = _notifService.selectedAlarmTone;
        _scheduledReminders = summary;
        _isLoadingReminders = false;
      });
    }
  }

  Future<void> _requestPermission() async {
    final granted = await _notifService.requestPermission();
    if (mounted) {
      setState(() {
        _isPermissionGranted = granted;
      });
      if (granted) {
        await _notifService.reconcileAllReminders();
        _refreshSummary();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Notifications permission granted!'),
              backgroundColor: _kSuccessGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } else {
        _showManualPermissionDialog();
      }
    }
  }

  void _showManualPermissionDialog() {
    final isIos = !kIsWeb && Platform.isIOS;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.notifications_off_rounded, color: _kDangerCoral, size: 24),
            SizedBox(width: 10),
            Text(
              'Permission Required',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: _kTextHead),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notifications are currently disabled. To receive reminders for your timetable classes and tasks, please enable notifications in your device settings:',
              style: TextStyle(fontSize: 13, color: Color(0xFF4B5565), height: 1.45),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FE),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E6F2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: isIos
                    ? const [
                        Text('1. Open iPhone Settings', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: _kTextHead)),
                        SizedBox(height: 4),
                        Text('2. Scroll down and tap StudyMate', style: TextStyle(fontSize: 12, color: Color(0xFF4B5565))),
                        SizedBox(height: 4),
                        Text('3. Tap Notifications and toggle Allow Notifications', style: TextStyle(fontSize: 12, color: Color(0xFF4B5565))),
                      ]
                    : const [
                        Text('1. Open Android Device Settings', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: _kTextHead)),
                        SizedBox(height: 4),
                        Text('2. Tap Apps & notifications > StudyMate', style: TextStyle(fontSize: 12, color: Color(0xFF4B5565))),
                        SizedBox(height: 4),
                        Text('3. Tap Notifications and turn on All StudyMate notifications', style: TextStyle(fontSize: 12, color: Color(0xFF4B5565))),
                        SizedBox(height: 4),
                        Text('4. Allow Alarms & Reminders permission if prompted', style: TextStyle(fontSize: 12, color: Color(0xFF4B5565))),
                      ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshSummary() async {
    final summary = await _notifService.getScheduledRemindersSummary();
    if (mounted) {
      setState(() {
        _scheduledReminders = summary;
      });
    }
  }

  Future<void> _toggleClassReminders(bool value) async {
    setState(() => _classRemindersEnabled = value);
    await _notifService.saveSettings(classEnabled: value);
    if (value) {
      await _notifService.reconcileAllReminders();
    } else {
      await _notifService.cancelAllClassReminders();
    }
    _refreshSummary();
  }

  Future<void> _toggleTaskReminders(bool value) async {
    setState(() => _taskRemindersEnabled = value);
    await _notifService.saveSettings(taskEnabled: value);
    if (value) {
      await _notifService.reconcileAllReminders();
    } else {
      await _notifService.cancelAllTaskReminders();
    }
    _refreshSummary();
  }

  Future<void> _changeLeadMinutes(int minutes) async {
    setState(() => _classLeadMinutes = minutes);
    await _notifService.saveSettings(leadMinutes: minutes);
    if (_classRemindersEnabled) {
      await _notifService.reconcileAllReminders();
    }
    _refreshSummary();
  }

  Future<void> _changeAlarmTone(AlarmTone tone) async {
    setState(() => _selectedTone = tone);
    await _notifService.saveSettings(alarmTone: tone);
    await _notifService.previewTone(tone);
    _refreshSummary();
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Alarm tone set to "${tone.label}"'),
          backgroundColor: _kPrimaryBlue,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _sendTestNotification() async {
    final granted = await _notifService.requestPermission();
    if (mounted) {
      setState(() => _isPermissionGranted = granted);
    }
    if (!granted) {
      _showManualPermissionDialog();
      return;
    }

    await _notifService.sendTestNotification();
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Buzzing and alerting with "${_selectedTone.label}". Check notification tray!'),
          backgroundColor: _kPrimaryBlue,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _kTextHead,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Notifications & Reminders',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _kTextHead,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: _kTextHead),
            onPressed: () {
              _loadState();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          children: [
            _buildPermissionCard(),
            const SizedBox(height: 16),
            _buildClassRemindersCard(),
            const SizedBox(height: 16),
            _buildTaskRemindersCard(),
            const SizedBox(height: 16),
            _buildAlarmTonesCard(),
            const SizedBox(height: 16),
            _buildTestNotificationCard(),
            const SizedBox(height: 20),
            _buildScheduledListHeader(),
            const SizedBox(height: 10),
            _buildScheduledRemindersList(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionCard() {
    if (_isLoadingPermission) {
      return Container(
        height: 72,
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kCardBorder),
        ),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final isGranted = _isPermissionGranted;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isGranted ? _kSuccessGreen.withValues(alpha: 0.25) : _kWarningAmber.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isGranted
                  ? _kSuccessGreen.withValues(alpha: 0.12)
                  : _kWarningAmber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isGranted ? Icons.check_circle_rounded : Icons.notifications_off_rounded,
              color: isGranted ? _kSuccessGreen : _kWarningAmber,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isGranted ? 'Notifications Allowed' : 'Notifications Disabled',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isGranted ? _kSuccessGreen : const Color(0xFFB45309),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isGranted
                      ? 'Local reminders for upcoming timetable classes and tasks are active offline.'
                      : 'Permission is needed to alert you before classes start or when tasks are due.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF4B5565),
                    height: 1.4,
                  ),
                ),
                if (!isGranted) ...[
                  const SizedBox(height: 10),
                  ElevatedButton(
                    key: const Key('enable_notifications_button'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimaryBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _requestPermission,
                    child: const Text('Enable Notifications', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassRemindersCard() {
    final leadOptions = [
      {'minutes': 0, 'label': 'At start'},
      {'minutes': 5, 'label': '5 min'},
      {'minutes': 10, 'label': '10 min'},
      {'minutes': 15, 'label': '15 min'},
      {'minutes': 30, 'label': '30 min'},
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _kPurpleAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.school_rounded, color: _kPurpleAccent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Timetable Class Reminders',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _kTextHead,
                      ),
                    ),
                    Text(
                      'Weekly recurring alerts for every scheduled class',
                      style: TextStyle(fontSize: 12, color: _kTextMuted),
                    ),
                  ],
                ),
              ),
              Switch(
                key: const Key('toggle_class_reminders_switch'),
                value: _classRemindersEnabled,
                activeTrackColor: _kPurpleAccent,
                activeThumbColor: Colors.white,
                onChanged: _toggleClassReminders,
              ),
            ],
          ),
          if (_classRemindersEnabled) ...[
            const Divider(height: 24, thickness: 1, color: Color(0xFFF1F3F9)),
            const Text(
              'Remind me before class:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _kTextHead,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: leadOptions.map((opt) {
                final mins = opt['minutes'] as int;
                final isSelected = _classLeadMinutes == mins;
                return ChoiceChip(
                  key: Key('lead_chip_$mins'),
                  label: Text(opt['label'] as String),
                  selected: isSelected,
                  selectedColor: _kPurpleAccent,
                  backgroundColor: const Color(0xFFF1F3F9),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF4B5565),
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      _changeLeadMinutes(mins);
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTaskRemindersCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _kPrimaryBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.check_circle_outline_rounded, color: _kPrimaryBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Task Due Reminders',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _kTextHead,
                      ),
                    ),
                    Text(
                      'Alerts scheduled for tasks with exact due date & time',
                      style: TextStyle(fontSize: 12, color: _kTextMuted),
                    ),
                  ],
                ),
              ),
              Switch(
                key: const Key('toggle_task_reminders_switch'),
                value: _taskRemindersEnabled,
                activeTrackColor: _kPrimaryBlue,
                activeThumbColor: Colors.white,
                onChanged: _toggleTaskReminders,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: const [
                Icon(Icons.info_outline_rounded, size: 16, color: _kPrimaryBlue),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'To schedule an alert, select an exact time when creating a task.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF4B5565)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlarmTonesCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.volume_up_rounded, color: Color(0xFF10B981), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Alarm Tones & Vibration',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _kTextHead,
                      ),
                    ),
                    Text(
                      'Choose alarm sound profile and buzzing pattern',
                      style: TextStyle(fontSize: 12, color: _kTextMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Column(
            children: AlarmTone.values.map((tone) {
              final isSelected = _selectedTone == tone;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFF0F4FF) : const Color(0xFFF8F9FE),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? _kPrimaryBlue : const Color(0xFFE2E6F2),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: InkWell(
                  key: Key('alarm_tone_${tone.key}'),
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _changeAlarmTone(tone),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                          color: isSelected ? _kPrimaryBlue : const Color(0xFF9CA3AF),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tone.label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? _kPrimaryBlue : _kTextHead,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tone.subtitle,
                                style: const TextStyle(fontSize: 11, color: _kTextMuted),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Test Buzz',
                          icon: Icon(
                            Icons.vibration_rounded,
                            size: 20,
                            color: isSelected ? _kPrimaryBlue : const Color(0xFF6B7280),
                          ),
                          onPressed: () => _notifService.previewTone(tone),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTestNotificationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kCardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Test Alarm & Buzz',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kTextHead),
                ),
                const SizedBox(height: 2),
                Text(
                  'Triggers immediate alarm alert with ${_selectedTone.label}',
                  style: const TextStyle(fontSize: 12, color: _kTextMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            key: const Key('send_test_notification_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimaryBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onPressed: _sendTestNotification,
            icon: const Icon(Icons.notifications_active_rounded, size: 16),
            label: const Text('Buzz Now', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduledListHeader() {
    return Row(
      children: [
        const Text(
          'Active Reminders',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _kTextHead,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF1F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${_scheduledReminders.length}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _kTextHead,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScheduledRemindersList() {
    if (_isLoadingReminders) {
      return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
    }

    if (_scheduledReminders.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kCardBorder),
        ),
        alignment: Alignment.center,
        child: Column(
          children: const [
            Icon(Icons.event_available_rounded, size: 36, color: _kTextMuted),
            SizedBox(height: 8),
            Text(
              'No active reminders scheduled',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _kTextHead),
            ),
            SizedBox(height: 4),
            Text(
              'Add classes in Timetable or tasks with exact dates to see them here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: _kTextMuted),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _scheduledReminders.map((info) {
        final isClass = info.type == 'class';
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _kCardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kCardBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isClass
                      ? _kPurpleAccent.withValues(alpha: 0.1)
                      : _kPrimaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isClass ? Icons.school_rounded : Icons.check_circle_outline_rounded,
                  color: isClass ? _kPurpleAccent : _kPrimaryBlue,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _kTextHead,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      info.subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: _kTextMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isClass ? const Color(0xFFF1EEFF) : const Color(0xFFE8EEFF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isClass ? 'Weekly' : 'One-time',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isClass ? _kPurpleAccent : _kPrimaryBlue,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
