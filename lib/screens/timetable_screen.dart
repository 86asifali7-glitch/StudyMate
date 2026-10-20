import 'package:flutter/material.dart';
import '../services/app_data_service.dart';
import '../services/notification_service.dart';

// ─── Design Tokens matching reference image ─────────────────────────────────
const _kBgColor       = Color(0xFFF8F9FE); // clean light background
const _kCardBg        = Color(0xFFFFFFFF); // white card surface
const _kPurplePrimary = Color(0xFF7551FF); // primary purple accent
const _kLavenderSoft  = Color(0xFFF1EEFF); // soft lavender container
const _kTextHead      = Color(0xFF191D31); // dark navy heading
const _kTextMuted     = Color(0xFF8C93A8); // muted subtitle & icon
const _kCardBorder    = Color(0xFFF1F3F9); // subtle card border
const _kDeleteIcon    = Color(0xFFE56969); // coral trash icon

// ─── Data Model ──────────────────────────────────────────────────────────────
class TimetableEntry {
  final String id;
  final String subject;
  final String day; // 'Mon', 'Tue', 'Wed', 'Thu', 'Fri'
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
        day: _normalizeDay(json['day'] as String),
        startTime: TimeOfDay(
          hour: json['startHour'] as int,
          minute: json['startMinute'] as int,
        ),
        endTime: TimeOfDay(
          hour: json['endHour'] as int,
          minute: json['endMinute'] as int,
        ),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimetableEntry &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  static String _normalizeDay(String raw) {
    switch (raw.toLowerCase()) {
      case 'monday':
        return 'Mon';
      case 'tuesday':
        return 'Tue';
      case 'wednesday':
        return 'Wed';
      case 'thursday':
        return 'Thu';
      case 'friday':
        return 'Fri';
      default:
        return raw;
    }
  }

  String get formattedTime => '${_fmt(startTime)} – ${_fmt(endTime)}';

  static String _fmt(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }
}

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @visibleForTesting
  static void resetForTesting() {
    _TimetableScreenState.resetStaticState();
  }

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  static List<TimetableEntry> _cachedEntries = List.from(AppDataService.instance.timetableEntries);

  static void resetStaticState() {
    AppDataService.instance.resetForTesting();
    _cachedEntries = [];
  }

  int _selectedDayIndex = 0;

  @override
  void initState() {
    super.initState();
    AppDataService.instance.addListener(_onAppDataChanged);
    _cachedEntries = List.from(AppDataService.instance.timetableEntries);
    if (!AppDataService.instance.isInitialized) {
      _loadEntries();
    }
  }

  void _onAppDataChanged() {
    if (!mounted) return;
    setState(() {
      _cachedEntries = List.from(AppDataService.instance.timetableEntries);
    });
  }

  @override
  void dispose() {
    AppDataService.instance.removeListener(_onAppDataChanged);
    super.dispose();
  }

  Future<void> _loadEntries() async {
    try {
      await AppDataService.instance.initialize();
      if (mounted) {
        setState(() {
          _cachedEntries = List<TimetableEntry>.from(AppDataService.instance.timetableEntries);
        });
      } else {
        _cachedEntries = List<TimetableEntry>.from(AppDataService.instance.timetableEntries);
      }
    } catch (_) {}
  }

  Future<void> _persist() async {
    await AppDataService.instance.saveTimetable(_cachedEntries);
  }

  List<TimetableEntry> _entriesForSelectedDay() {
    final currentDay = _days[_selectedDayIndex];
    final list = _cachedEntries.where((e) => e.day == currentDay).toList();
    list.sort((a, b) {
      final aMin = a.startTime.hour * 60 + a.startTime.minute;
      final bMin = b.startTime.hour * 60 + b.startTime.minute;
      return aMin.compareTo(bMin);
    });
    return list;
  }

  Future<void> _addEntry(TimetableEntry entry) async {
    setState(() {
      _cachedEntries.add(entry);
    });
    await _persist();
    NotificationService.instance.scheduleClassReminder(entry);
  }

  Future<void> _updateEntry(TimetableEntry updated) async {
    setState(() {
      final idx = _cachedEntries.indexWhere((e) => e.id == updated.id);
      if (idx != -1) _cachedEntries[idx] = updated;
    });
    await _persist();
    NotificationService.instance.scheduleClassReminder(updated);
  }

  Future<void> _deleteEntry(TimetableEntry entry) async {
    final deletedIndex = _cachedEntries.indexWhere((e) => e.id == entry.id);
    if (deletedIndex == -1) return;

    setState(() {
      _cachedEntries.removeAt(deletedIndex);
    });
    await _persist();
    NotificationService.instance.cancelClassReminder(entry.id);

    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed "${entry.subject}"'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'Undo',
          textColor: const Color(0xFF8298FF),
          onPressed: () async {
            setState(() {
              _cachedEntries.insert(deletedIndex, entry);
            });
            await _persist();
            NotificationService.instance.scheduleClassReminder(entry);
          },
        ),
      ),
    );
  }

  Future<void> _confirmClearAll() async {
    final count = _cachedEntries.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Clear Timetable?',
          style: TextStyle(fontWeight: FontWeight.w700, color: _kTextHead),
        ),
        content: Text(
          'This will remove all $count classes from your weekly timetable.',
          style: const TextStyle(color: Color(0xFF6B7280), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            key: const Key('confirm_clear_all_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kDeleteIcon,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear All', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _cachedEntries.clear();
      });
      await _persist();
      NotificationService.instance.cancelAllClassReminders();
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('All classes cleared from timetable'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _openEntryDialog({TimetableEntry? existing}) async {
    final isEdit = existing != null;
    final subjectCtrl = TextEditingController(text: isEdit ? existing.subject : '');
    String selectedDay = existing?.day ?? _days[_selectedDayIndex];
    TimeOfDay startTime = existing?.startTime ?? const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = existing?.endTime ?? const TimeOfDay(hour: 10, minute: 30);

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: _kLavenderSoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.schedule_rounded,
                            color: _kPurplePrimary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          isEdit ? 'Edit Class' : 'Add Class',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _kTextHead,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      key: const Key('class_subject_field'),
                      controller: subjectCtrl,
                      autofocus: true,
                      style: const TextStyle(fontSize: 14, color: _kTextHead),
                      decoration: InputDecoration(
                        hintText: 'e.g. Calculus II, Physics Mechanics',
                        hintStyle: const TextStyle(fontSize: 13, color: _kTextMuted),
                        filled: true,
                        fillColor: const Color(0xFFF8F9FE),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E6F2)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E6F2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _kPurplePrimary, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Day of week',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _kTextMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: _days.map((day) {
                        final isSelected = selectedDay == day;
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => setDialogState(() => selectedDay = day),
                            mouseCursor: SystemMouseCursors.click,
                            borderRadius: BorderRadius.circular(10),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: isSelected ? _kPurplePrimary : const Color(0xFFF1F3F9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                day,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? Colors.white : const Color(0xFF4B5565),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Start Time',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _kTextMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () async {
                                  final picked = await showTimePicker(
                                    context: ctx,
                                    initialTime: startTime,
                                  );
                                  if (picked != null) {
                                    setDialogState(() => startTime = picked);
                                  }
                                },
                                mouseCursor: SystemMouseCursors.click,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8F9FE),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE2E6F2)),
                                  ),
                                  child: Text(
                                    TimetableEntry._fmt(startTime),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _kPurplePrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'End Time',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _kTextMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () async {
                                  final picked = await showTimePicker(
                                    context: ctx,
                                    initialTime: endTime,
                                  );
                                  if (picked != null) {
                                    setDialogState(() => endTime = picked);
                                  }
                                },
                                mouseCursor: SystemMouseCursors.click,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8F9FE),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE2E6F2)),
                                  ),
                                  child: Text(
                                    TimetableEntry._fmt(endTime),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _kPurplePrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          key: const Key('save_class_button'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kPurplePrimary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () async {
                            final rawSubject = subjectCtrl.text.trim();
                            if (rawSubject.isEmpty) return;

                            final entry = TimetableEntry(
                              id: isEdit ? existing.id : DateTime.now().millisecondsSinceEpoch.toString(),
                              subject: rawSubject,
                              day: selectedDay,
                              startTime: startTime,
                              endTime: endTime,
                            );

                            Navigator.pop(ctx);
                            if (isEdit) {
                              await _updateEntry(entry);
                            } else {
                              await _addEntry(entry);
                              final targetIndex = _days.indexOf(selectedDay);
                              if (targetIndex != -1) {
                                setState(() => _selectedDayIndex = targetIndex);
                              }
                            }
                          },
                          child: Text(
                            isEdit ? 'Save Changes' : 'Add Class',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entriesForSelectedDay();

    return Scaffold(
      backgroundColor: _kBgColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Header ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Timetable',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: _kTextHead,
                          letterSpacing: -0.6,
                          height: 1.1,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Your weekly class schedule',
                        style: TextStyle(
                          fontSize: 14,
                          color: _kTextMuted,
                          fontWeight: FontWeight.w400,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_cachedEntries.isNotEmpty) ...[
                        Tooltip(
                          message: 'Clear All Classes',
                          child: Container(
                            width: 44,
                            height: 44,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: _kLavenderSoft,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                key: const Key('clear_all_header_button'),
                                borderRadius: BorderRadius.circular(14),
                                mouseCursor: SystemMouseCursors.click,
                                onTap: _confirmClearAll,
                                hoverColor: _kDeleteIcon.withValues(alpha: 0.12),
                                child: const Center(
                                  child: Icon(
                                    Icons.delete_sweep_rounded,
                                    color: _kDeleteIcon,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      // Top right rounded lavender Add (+) button matching reference image
                      Tooltip(
                        message: 'Add Class',
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _kLavenderSoft,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              key: const Key('add_class_header_button'),
                              borderRadius: BorderRadius.circular(14),
                              mouseCursor: SystemMouseCursors.click,
                              onTap: () => _openEntryDialog(),
                              hoverColor: _kPurplePrimary.withValues(alpha: 0.12),
                              child: const Center(
                                child: Icon(
                                  Icons.add_rounded,
                                  color: _kPurplePrimary,
                                  size: 26,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // ── Day Selector (Mon, Tue, Wed, Thu, Fri) ───────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(_days.length, (i) {
                  final isSelected = _selectedDayIndex == i;
                  final day = _days[i];
                  final dayClassCount =
                      _cachedEntries.where((e) => e.day == day).length;

                  return InkWell(
                    key: Key('day_tab_$day'),
                    onTap: () {
                      if (_selectedDayIndex != i) {
                        setState(() => _selectedDayIndex = i);
                      }
                    },
                    mouseCursor: SystemMouseCursors.click,
                    borderRadius: BorderRadius.circular(8),
                    hoverColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    splashColor: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                day,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected ? _kPurplePrimary : _kTextMuted,
                                ),
                              ),
                              if (dayClassCount > 0) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? _kPurplePrimary.withValues(alpha: 0.15)
                                        : const Color(0xFFE8EAFD),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$dayClassCount',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected ? _kPurplePrimary : _kTextMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Active purple indicator bar
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            height: 3,
                            width: isSelected ? 32 : 0,
                            decoration: BoxDecoration(
                              color: isSelected ? _kPurplePrimary : Colors.transparent,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 16),

            // ── Classes List ─────────────────────────────────────────────────
            Expanded(
              child: _cachedEntries.isEmpty
                  ? _buildEmptyState(isTotalEmpty: true)
                  : entries.isEmpty
                      ? _buildEmptyState(isTotalEmpty: false)
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                          physics: const BouncingScrollPhysics(),
                          itemCount: entries.length,
                          itemBuilder: (context, index) {
                            final entry = entries[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _TimetableCard(
                                key: ValueKey(entry.id),
                                entry: entry,
                                onDelete: () => _deleteEntry(entry),
                                onEdit: () => _openEntryDialog(existing: entry),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({bool isTotalEmpty = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: const BoxDecoration(
                color: _kLavenderSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                color: _kPurplePrimary,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isTotalEmpty
                  ? 'No classes scheduled yet'
                  : 'No classes scheduled',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _kTextHead,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isTotalEmpty
                  ? 'Your timetable is empty. Tap "+ Add Class" to set up your weekly schedule!'
                  : 'No classes for ${_days[_selectedDayIndex]}. ${_cachedEntries.length} ${_cachedEntries.length == 1 ? "class" : "classes"} scheduled on other days.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: _kTextMuted,
              ),
            ),
            if (isTotalEmpty) ...[
              const SizedBox(height: 18),
              ElevatedButton.icon(
                key: const Key('empty_add_class_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPurplePrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  elevation: 0,
                ),
                onPressed: () => _openEntryDialog(),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text(
                  'Add Class',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ] else if (_cachedEntries.isNotEmpty) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                key: const Key('empty_clear_all_button'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kDeleteIcon,
                  side: const BorderSide(color: Color(0xFFFCDADA)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: _confirmClearAll,
                icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                label: Text(
                  'Clear All Classes (${_cachedEntries.length})',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Timetable Card matching reference image ─────────────────────────────────
class _TimetableCard extends StatelessWidget {
  final TimetableEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TimetableCard({
    super.key,
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kCardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          mouseCursor: SystemMouseCursors.click,
          highlightColor: Colors.transparent,
          hoverColor: const Color(0xFFF9F8FF),
          splashColor: const Color(0xFFF0EDFF),
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                // Left: Soft lavender container with clock icon
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: _kLavenderSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.access_time_rounded,
                      color: _kPurplePrimary,
                      size: 22,
                    ),
                  ),
                ),

                const SizedBox(width: 14),

                // Middle: Subject and Time
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.subject,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: _kTextHead,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.formattedTime,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _kPurplePrimary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Right: Edit pencil icon
                Tooltip(
                  message: 'Edit class',
                  child: Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      mouseCursor: SystemMouseCursors.click,
                      onTap: onEdit,
                      hoverColor: Colors.black.withValues(alpha: 0.05),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.edit_outlined,
                          size: 19,
                          color: _kTextMuted,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 4),

                // Right: Delete trash icon
                Tooltip(
                  message: 'Delete class',
                  child: Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      mouseCursor: SystemMouseCursors.click,
                      onTap: onDelete,
                      hoverColor: const Color(0xFFFFD9DC),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          size: 20,
                          color: _kDeleteIcon,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
