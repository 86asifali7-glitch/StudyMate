import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

// ─── Default Sample Data matching reference image ────────────────────────────
List<TimetableEntry> _defaultEntries() => [
      TimetableEntry(
        id: '1',
        subject: 'Calculus II',
        day: 'Mon',
        startTime: const TimeOfDay(hour: 9, minute: 0),
        endTime: const TimeOfDay(hour: 10, minute: 30),
      ),
      TimetableEntry(
        id: '2',
        subject: 'Physics Mechanics',
        day: 'Mon',
        startTime: const TimeOfDay(hour: 11, minute: 0),
        endTime: const TimeOfDay(hour: 12, minute: 30),
      ),
      TimetableEntry(
        id: '3',
        subject: 'Computer Architecture',
        day: 'Mon',
        startTime: const TimeOfDay(hour: 14, minute: 0),
        endTime: const TimeOfDay(hour: 15, minute: 30),
      ),
      TimetableEntry(
        id: '4',
        subject: 'Data Structures',
        day: 'Tue',
        startTime: const TimeOfDay(hour: 10, minute: 0),
        endTime: const TimeOfDay(hour: 11, minute: 30),
      ),
      TimetableEntry(
        id: '5',
        subject: 'Technical Writing',
        day: 'Tue',
        startTime: const TimeOfDay(hour: 13, minute: 0),
        endTime: const TimeOfDay(hour: 14, minute: 30),
      ),
      TimetableEntry(
        id: '6',
        subject: 'Calculus II',
        day: 'Wed',
        startTime: const TimeOfDay(hour: 9, minute: 0),
        endTime: const TimeOfDay(hour: 10, minute: 30),
      ),
      TimetableEntry(
        id: '7',
        subject: 'Physics Lab',
        day: 'Wed',
        startTime: const TimeOfDay(hour: 13, minute: 0),
        endTime: const TimeOfDay(hour: 15, minute: 0),
      ),
      TimetableEntry(
        id: '8',
        subject: 'Linear Algebra',
        day: 'Thu',
        startTime: const TimeOfDay(hour: 14, minute: 0),
        endTime: const TimeOfDay(hour: 15, minute: 30),
      ),
      TimetableEntry(
        id: '9',
        subject: 'Computer Architecture',
        day: 'Fri',
        startTime: const TimeOfDay(hour: 9, minute: 30),
        endTime: const TimeOfDay(hour: 11, minute: 0),
      ),
    ];

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
const _kPrefsKey = 'timetable_entries_v2';

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
  static List<TimetableEntry> _cachedEntries = _defaultEntries();
  static bool _hasLoaded = false;

  static void resetStaticState() {
    _hasLoaded = false;
    _cachedEntries = _defaultEntries();
  }

  int _selectedDayIndex = 0;

  @override
  void initState() {
    super.initState();
    if (!_hasLoaded) {
      _loadEntries();
    }
  }

  Future<void> _loadEntries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPrefsKey);
      if (raw != null) {
        final List decoded = jsonDecode(raw) as List;
        final loaded = decoded
            .map((e) => TimetableEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        if (mounted) {
          setState(() {
            _cachedEntries = loaded;
            _hasLoaded = true;
          });
        } else {
          _cachedEntries = loaded;
          _hasLoaded = true;
        }
      } else {
        _hasLoaded = true;
      }
    } catch (_) {
      _hasLoaded = true;
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kPrefsKey,
        jsonEncode(_cachedEntries.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
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

  void _addEntry(TimetableEntry entry) {
    setState(() {
      _cachedEntries.add(entry);
    });
    _persist();
  }

  void _updateEntry(TimetableEntry updated) {
    setState(() {
      final idx = _cachedEntries.indexWhere((e) => e.id == updated.id);
      if (idx != -1) _cachedEntries[idx] = updated;
    });
    _persist();
  }

  void _deleteEntry(TimetableEntry entry) {
    final deletedIndex = _cachedEntries.indexOf(entry);
    if (deletedIndex == -1) return;

    setState(() {
      _cachedEntries.removeAt(deletedIndex);
    });
    _persist();

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed "${entry.subject}"'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'Undo',
          textColor: const Color(0xFF8298FF),
          onPressed: () {
            setState(() {
              _cachedEntries.insert(deletedIndex, entry);
            });
            _persist();
          },
        ),
      ),
    );
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
                          onPressed: () {
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
                              _updateEntry(entry);
                            } else {
                              _addEntry(entry);
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      child: Column(
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
              child: entries.isEmpty
                  ? _buildEmptyState()
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
                            onEdit: () => _openEntryDialog(existing: entry),
                            onDelete: () => _deleteEntry(entry),
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

  Widget _buildEmptyState() {
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
            const Text(
              'No classes scheduled',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _kTextHead,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap the + button to add a class for this day!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: _kTextMuted,
              ),
            ),
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
