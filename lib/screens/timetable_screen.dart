import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/colors.dart';

// ─── Data Model ──────────────────────────────────────────────────────────────

class TimetableEntry {
  final String id;
  final String subject;
  final String day;
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  TimetableEntry({
    required this.id,
    required this.subject,
    required this.day,
    required this.startTime,
    required this.endTime,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject': subject,
        'day': day,
        'startHour': startTime.hour,
        'startMinute': startTime.minute,
        'endHour': endTime.hour,
        'endMinute': endTime.minute,
      };

  factory TimetableEntry.fromJson(Map<String, dynamic> json) => TimetableEntry(
        id: json['id'] as String,
        subject: json['subject'] as String,
        day: json['day'] as String,
        startTime: TimeOfDay(
          hour: json['startHour'] as int,
          minute: json['startMinute'] as int,
        ),
        endTime: TimeOfDay(
          hour: json['endHour'] as int,
          minute: json['endMinute'] as int,
        ),
      );

  String get formattedTime =>
      '${_fmt(startTime)} – ${_fmt(endTime)}';

  static String _fmt(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }
}

// ─── Default seed data ───────────────────────────────────────────────────────

List<TimetableEntry> _defaultEntries() => [
      TimetableEntry(
        id: 'def1',
        subject: 'Calculus II',
        day: 'Monday',
        startTime: const TimeOfDay(hour: 9, minute: 0),
        endTime: const TimeOfDay(hour: 10, minute: 30),
      ),
      TimetableEntry(
        id: 'def2',
        subject: 'Physics Mechanics',
        day: 'Monday',
        startTime: const TimeOfDay(hour: 11, minute: 0),
        endTime: const TimeOfDay(hour: 12, minute: 30),
      ),
      TimetableEntry(
        id: 'def3',
        subject: 'Computer Architecture',
        day: 'Monday',
        startTime: const TimeOfDay(hour: 14, minute: 0),
        endTime: const TimeOfDay(hour: 15, minute: 30),
      ),
      TimetableEntry(
        id: 'def4',
        subject: 'Data Structures',
        day: 'Tuesday',
        startTime: const TimeOfDay(hour: 10, minute: 0),
        endTime: const TimeOfDay(hour: 11, minute: 30),
      ),
      TimetableEntry(
        id: 'def5',
        subject: 'Technical Writing',
        day: 'Tuesday',
        startTime: const TimeOfDay(hour: 13, minute: 0),
        endTime: const TimeOfDay(hour: 14, minute: 30),
      ),
      TimetableEntry(
        id: 'def6',
        subject: 'Calculus II',
        day: 'Wednesday',
        startTime: const TimeOfDay(hour: 9, minute: 0),
        endTime: const TimeOfDay(hour: 10, minute: 30),
      ),
      TimetableEntry(
        id: 'def7',
        subject: 'Physics Lab',
        day: 'Wednesday',
        startTime: const TimeOfDay(hour: 13, minute: 0),
        endTime: const TimeOfDay(hour: 15, minute: 0),
      ),
      TimetableEntry(
        id: 'def8',
        subject: 'Data Structures Lab',
        day: 'Thursday',
        startTime: const TimeOfDay(hour: 10, minute: 0),
        endTime: const TimeOfDay(hour: 12, minute: 0),
      ),
      TimetableEntry(
        id: 'def9',
        subject: 'Linear Algebra',
        day: 'Thursday',
        startTime: const TimeOfDay(hour: 14, minute: 0),
        endTime: const TimeOfDay(hour: 15, minute: 30),
      ),
      TimetableEntry(
        id: 'def10',
        subject: 'Computer Architecture',
        day: 'Friday',
        startTime: const TimeOfDay(hour: 9, minute: 30),
        endTime: const TimeOfDay(hour: 11, minute: 0),
      ),
      TimetableEntry(
        id: 'def11',
        subject: 'Group Study & Review',
        day: 'Friday',
        startTime: const TimeOfDay(hour: 14, minute: 0),
        endTime: const TimeOfDay(hour: 16, minute: 0),
      ),
    ];

// ─── Screen ──────────────────────────────────────────────────────────────────

const _days = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const _prefsKey = 'timetable_entries_v1';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<TimetableEntry> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _days.length, vsync: this);
    _loadEntries();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Persistence ────────────────────────────────────────────────────────────

  Future<void> _loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) {
      // First launch — seed defaults
      setState(() {
        _entries = _defaultEntries();
        _isLoading = false;
      });
      await _persist();
    } else {
      final List decoded = jsonDecode(raw) as List;
      setState(() {
        _entries = decoded
            .map((e) => TimetableEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        _isLoading = false;
      });
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(_entries.map((e) => e.toJson()).toList()),
    );
  }

  // ── CRUD helpers ───────────────────────────────────────────────────────────

  void _addEntry(TimetableEntry e) {
    setState(() => _entries.add(e));
    _persist();
  }

  void _updateEntry(TimetableEntry updated) {
    setState(() {
      final idx = _entries.indexWhere((e) => e.id == updated.id);
      if (idx != -1) _entries[idx] = updated;
    });
    _persist();
  }

  void _deleteEntry(String id) {
    setState(() => _entries.removeWhere((e) => e.id == id));
    _persist();
  }

  // ── Dialog ─────────────────────────────────────────────────────────────────

  Future<void> _openEntryDialog({
    TimetableEntry? existing,
    String? defaultDay,
  }) async {
    final isEdit = existing != null;
    final subjectCtrl =
        TextEditingController(text: isEdit ? existing.subject : '');
    String selectedDay = existing?.day ?? defaultDay ?? _days[0];
    TimeOfDay startTime =
        existing?.startTime ?? const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime =
        existing?.endTime ?? const TimeOfDay(hour: 10, minute: 0);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            Future<void> pickTime({required bool isStart}) async {
              final picked = await showTimePicker(
                context: ctx,
                initialTime: isStart ? startTime : endTime,
                helpText: isStart ? 'Pick start time' : 'Pick end time',
              );
              if (picked != null) {
                setLocal(() {
                  if (isStart) {
                    startTime = picked;
                  } else {
                    endTime = picked;
                  }
                });
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              titlePadding:
                  const EdgeInsets.fromLTRB(20, 20, 20, 0),
              contentPadding:
                  const EdgeInsets.fromLTRB(20, 12, 20, 0),
              title: Text(
                isEdit ? 'Edit Class' : 'Add Class',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppColors.textDark,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Subject
                    const _FieldLabel('Subject Name'),
                    TextField(
                      controller: subjectCtrl,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      decoration: _inputDecoration('e.g. Data Structures'),
                    ),
                    const SizedBox(height: 16),

                    // Day picker
                    const _FieldLabel('Day'),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 2),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: Colors.black.withValues(alpha: 0.12)),
                        borderRadius: BorderRadius.circular(10),
                        color: AppColors.background,
                      ),
                      child: DropdownButton<String>(
                        value: selectedDay,
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        borderRadius: BorderRadius.circular(12),
                        items: _days
                            .map((d) => DropdownMenuItem(
                                  value: d,
                                  child: Text(d),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setLocal(() => selectedDay = v ?? selectedDay),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Time row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _FieldLabel('Start Time'),
                              _TimeButton(
                                time: startTime,
                                onTap: () => pickTime(isStart: true),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _FieldLabel('End Time'),
                              _TimeButton(
                                time: endTime,
                                onTap: () => pickTime(isStart: false),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
              actionsPadding:
                  const EdgeInsets.fromLTRB(12, 8, 12, 12),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.textLight),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                  onPressed: () {
                    final subject = subjectCtrl.text.trim();
                    if (subject.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a subject name.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    // Validate end > start
                    final startMins =
                        startTime.hour * 60 + startTime.minute;
                    final endMins = endTime.hour * 60 + endTime.minute;
                    if (endMins <= startMins) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'End time must be after start time.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }

                    final entry = TimetableEntry(
                      id: isEdit
                          ? existing.id
                          : DateTime.now()
                              .millisecondsSinceEpoch
                              .toString(),
                      subject: subject,
                      day: selectedDay,
                      startTime: startTime,
                      endTime: endTime,
                    );

                    Navigator.pop(ctx);
                    if (isEdit) {
                      _updateEntry(entry);
                    } else {
                      _addEntry(entry);
                      // Switch to the tab of the newly added entry
                      final idx = _days.indexOf(selectedDay);
                      if (idx != -1) _tabController.animateTo(idx);
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isEdit
                            ? '\'$subject\' updated.'
                            : '\'$subject\' added to $selectedDay.'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  },
                  child: Text(isEdit ? 'Save Changes' : 'Add Class'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(TimetableEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Class'),
        content: Text(
          'Remove "${entry.subject}" from ${entry.day}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textLight)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _deleteEntry(entry.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${entry.subject}" removed.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Weekly Timetable'),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                'Add Class',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              onPressed: () => _openEntryDialog(
                defaultDay: _days[_tabController.index],
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: _days.map((d) => Tab(text: d)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _days.map((day) => _DayTab(
              day: day,
              entries: _entriesForDay(day),
              onEdit: (e) => _openEntryDialog(existing: e),
              onDelete: _confirmDelete,
              onAdd: () => _openEntryDialog(defaultDay: day),
            )).toList(),
      ),
    );
  }

  List<TimetableEntry> _entriesForDay(String day) {
    final list = _entries.where((e) => e.day == day).toList();
    list.sort((a, b) {
      final aMin = a.startTime.hour * 60 + a.startTime.minute;
      final bMin = b.startTime.hour * 60 + b.startTime.minute;
      return aMin.compareTo(bMin);
    });
    return list;
  }
}

// ─── Day Tab ─────────────────────────────────────────────────────────────────

class _DayTab extends StatelessWidget {
  final String day;
  final List<TimetableEntry> entries;
  final void Function(TimetableEntry) onEdit;
  final void Function(TimetableEntry) onDelete;
  final VoidCallback onAdd;

  const _DayTab({
    required this.day,
    required this.entries,
    required this.onEdit,
    required this.onDelete,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.calendar_today_outlined,
                size: 36,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No classes scheduled',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap "Add Class" to schedule a class for this day.',
              style: TextStyle(fontSize: 13, color: AppColors.textLight),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Class'),
              onPressed: onAdd,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return _EntryCard(
          entry: entry,
          onEdit: () => onEdit(entry),
          onDelete: () => onDelete(entry),
        );
      },
    );
  }
}

// ─── Entry Card ───────────────────────────────────────────────────────────────

class _EntryCard extends StatelessWidget {
  final TimetableEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EntryCard({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
      ),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Clock icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.access_time_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            // Subject + time
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.subject,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.formattedTime,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            // Edit button
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined,
                  size: 20, color: AppColors.textLight),
              onPressed: onEdit,
            ),
            // Delete button
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline,
                  size: 20, color: Colors.redAccent),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Small reusable helpers ───────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textLight,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  final TimeOfDay time;
  final VoidCallback onTap;

  const _TimeButton({required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black.withValues(alpha: 0.12)),
          borderRadius: BorderRadius.circular(10),
          color: AppColors.background,
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule_rounded,
                size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              TimetableEntry._fmt(time),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration _inputDecoration(String? hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 13),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
            const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      filled: true,
      fillColor: AppColors.background,
    );
