import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_settings_screen.dart';

// ─── Design tokens ─────────────────────────────────────────────────────────────
// Inspired by the reference screenshot's lavender + white card + purple-accent style.

const _kBg          = Color(0xFFEEF0FF); // soft lavender page background
const _kPrimary     = Color(0xFF5B6CF9); // indigo-purple primary
const _kPrimaryDark = Color(0xFF4152E8); // deeper indigo (gradient stop)
const _kCard        = Color(0xFFFFFFFF); // white card surface
const _kTextHead    = Color(0xFF1A1A2E); // near-black heading
const _kTextBody    = Color(0xFF6B7280); // muted body text
const _kPurpleTag   = Color(0xFF7C3AED); // purple pill badge
const _kBlueTag     = Color(0xFF3B82F6); // blue pill badge
const _kGreenTag    = Color(0xFF059669); // green pill badge

// ─── Screen ────────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  /// [tabIndex] → MainShell IndexedStack position: 1=Notes 2=Tasks 3=Timetable
  final void Function(int tabIndex)? onNavigate;
  const HomeScreen({super.key, this.onNavigate});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;
  int _noteCount = 3;
  int _taskCount = 4;
  int _timetableCount = 3;
  String? _firstTodaySubject;
  String? _firstTodayTime;

  static String _fmtTime(int hour, int minute) {
    final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final m = minute.toString().padLeft(2, '0');
    final period = hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  @override
  void initState() {
    super.initState();
    _loadNoteCount();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  Future<void> _loadNoteCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final hasSavedNotes = (prefs.getBool('studymate_notes_saved') ?? false) ||
          prefs.containsKey('studymate_saved_notes') ||
          prefs.containsKey('studymate_notes_json');
      int noteCount = 3;
      if (hasSavedNotes) {
        final rawJson = prefs.getString('studymate_notes_json');
        if (rawJson != null) {
          try {
            noteCount = (jsonDecode(rawJson) as List).length;
          } catch (_) {
            noteCount = 0;
          }
        } else {
          final savedData = prefs.getStringList('studymate_saved_notes');
          noteCount = savedData != null ? savedData.length : 0;
        }
      } else {
        final savedData = prefs.getStringList('studymate_saved_notes');
        noteCount = savedData != null ? savedData.length : 3;
      }

      final hasSavedTasks = (prefs.getBool('studymate_tasks_saved') ?? false) ||
          prefs.containsKey('studymate_saved_tasks') ||
          prefs.containsKey('studymate_tasks_json');
      int taskCount = 4;
      if (hasSavedTasks) {
        final rawJson = prefs.getString('studymate_tasks_json');
        if (rawJson != null) {
          try {
            taskCount = (jsonDecode(rawJson) as List).length;
          } catch (_) {
            taskCount = 0;
          }
        } else {
          final savedTasks = prefs.getStringList('studymate_saved_tasks');
          taskCount = savedTasks != null ? savedTasks.length : 0;
        }
      } else {
        final savedTasks = prefs.getStringList('studymate_saved_tasks');
        taskCount = savedTasks != null ? savedTasks.length : 4;
      }

      final hasSavedTimetable =
          (prefs.getBool('studymate_timetable_saved') ?? false) ||
              prefs.containsKey('timetable_entries_v2');
      int timetableCount = 3;
      String? firstTodaySubject;
      String? firstTodayTime;

      final now = DateTime.now();
      final weekday = now.weekday; // 1=Mon, ..., 5=Fri
      final todayDay = (weekday >= 1 && weekday <= 5)
          ? const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'][weekday - 1]
          : null;

      if (hasSavedTimetable) {
        final rawTimetable = prefs.getString('timetable_entries_v2');
        if (rawTimetable != null) {
          try {
            final decoded = jsonDecode(rawTimetable);
            if (decoded is List) {
              if (todayDay != null) {
                final todayEntries = decoded.where((e) {
                  if (e is Map) {
                    final d = e['day']?.toString();
                    return d?.toLowerCase() == todayDay.toLowerCase();
                  }
                  return false;
                }).toList();

                timetableCount = todayEntries.length;
                if (todayEntries.isNotEmpty) {
                  final first = todayEntries.first as Map;
                  firstTodaySubject = first['subject']?.toString();
                  final sH = first['startHour'] as int? ?? 9;
                  final sM = first['startMinute'] as int? ?? 0;
                  final eH = first['endHour'] as int? ?? 10;
                  final eM = first['endMinute'] as int? ?? 30;
                  firstTodayTime = '${_fmtTime(sH, sM)} – ${_fmtTime(eH, eM)}';
                }
              } else {
                timetableCount = 0;
              }
            }
          } catch (_) {
            timetableCount = 0;
          }
        } else {
          timetableCount = 0;
        }
      } else {
        timetableCount = (weekday >= 1 && weekday <= 5) ? 3 : 0;
        if (timetableCount > 0) {
          firstTodaySubject = 'Calculus II';
          firstTodayTime = '09:00 AM • Room 204';
        }
      }

      if (mounted &&
          (_noteCount != noteCount ||
              _taskCount != taskCount ||
              _timetableCount != timetableCount ||
              _firstTodaySubject != firstTodaySubject ||
              _firstTodayTime != firstTodayTime)) {
        setState(() {
          _noteCount = noteCount;
          _taskCount = taskCount;
          _timetableCount = timetableCount;
          _firstTodaySubject = firstTodaySubject;
          _firstTodayTime = firstTodayTime;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning!';
    if (h < 17) return 'Good afternoon!';
    return 'Good evening!';
  }

  String get _dateLabel {
    final now = DateTime.now();
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }

  void _go(int i) {
    widget.onNavigate?.call(i);
    _loadNoteCount();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadNoteCount();
    });
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
    );
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        bottom: false,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildTopBar()),
              SliverToBoxAdapter(child: _buildHero()),
              SliverToBoxAdapter(child: _buildStatsRow()),
              SliverToBoxAdapter(child: _buildSectionLabel('Quick Access')),
              SliverToBoxAdapter(child: _buildQuickCard(
                icon: Icons.menu_book_rounded,
                iconBg: _kPurpleTag,
                title: 'Notes',
                subtitle: 'Lecture & study notes',
                badge: 'Notes',
                badgeColor: _kPurpleTag,
                count: '$_noteCount',
                onTap: () => _go(1),
              )),
              SliverToBoxAdapter(child: _buildQuickCard(
                icon: Icons.check_circle_outline_rounded,
                iconBg: _kBlueTag,
                title: 'Tasks',
                subtitle: 'Assignments & to-dos',
                badge: 'Tasks',
                badgeColor: _kBlueTag,
                count: '$_taskCount',
                onTap: () => _go(2),
              )),
              SliverToBoxAdapter(child: _buildQuickCard(
                icon: Icons.calendar_month_rounded,
                iconBg: _kGreenTag,
                title: 'Timetable',
                subtitle: 'Weekly class schedule',
                badge: 'Timetable',
                badgeColor: _kGreenTag,
                count: '$_timetableCount',
                isLast: true,
                onTap: () => _go(3),
              )),
              const SliverToBoxAdapter(child: SizedBox(height: 36)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top bar ──────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Row(
        children: [
          // Gradient circle avatar / logo
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_kPrimary, _kPrimaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(Icons.auto_stories_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'StudyMate',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _kTextHead,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                _dateLabel,
                style: const TextStyle(
                  fontSize: 12,
                  color: _kTextBody,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Bell button
          _TopBarBtn(
            icon: Icons.notifications_none_rounded,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationSettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Hero section ─────────────────────────────────────────────────────────────

  Widget _buildHero() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _greeting,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: _kTextHead,
              letterSpacing: -0.4,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Your study space is ready.\nLet\'s make progress today.',
            style: TextStyle(
              fontSize: 14,
              color: _kTextBody,
              fontWeight: FontWeight.w400,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 20),
          // Hero card  ── gradient-outlined card with class info
          _HeroCard(
            onViewTimetable: () => _go(3),
            hasClasses: _timetableCount > 0,
            classSubject: _firstTodaySubject,
            classTime: _firstTodayTime,
          ),
        ],
      ),
    );
  }

  // ── Stats row ────────────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Row(
        children: [
          _StatBadge(label: 'Notes',   value: '$_noteCount', color: _kPurpleTag, onTap: () => _go(1)),
          const SizedBox(width: 12),
          _StatBadge(label: 'Tasks',   value: '$_taskCount',  color: _kBlueTag,   onTap: () => _go(2)),
          const SizedBox(width: 12),
          _StatBadge(label: 'Classes', value: '$_timetableCount',  color: _kGreenTag,  onTap: () => _go(3)),
        ],
      ),
    );
  }

  // ── Section label ────────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: _kTextHead,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  // ── Quick Access card ────────────────────────────────────────────────────────

  Widget _buildQuickCard({
    required IconData icon,
    required Color iconBg,
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required String count,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, isLast ? 0 : 12),
      child: _QuickCard(
        icon: icon,
        iconBg: iconBg,
        title: title,
        subtitle: subtitle,
        badge: badge,
        badgeColor: badgeColor,
        count: count,
        onTap: onTap,
      ),
    );
  }
}

// ─── Top bar button ───────────────────────────────────────────────────────────

class _TopBarBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _TopBarBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: _kTextHead),
      ),
    );
  }
}

// ─── Hero Card ────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final VoidCallback onViewTimetable;
  final bool hasClasses;
  final String? classSubject;
  final String? classTime;
  const _HeroCard({
    required this.onViewTimetable,
    this.hasClasses = true,
    this.classSubject,
    this.classTime,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF4F9FFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    hasClasses ? "Today's Class" : "Today's Schedule",
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  hasClasses
                      ? (classSubject ?? 'Calculus II')
                      : 'No Classes Scheduled',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasClasses
                      ? (classTime ?? '09:00 AM • Room 204')
                      : 'Your schedule is clear • Enjoy your day!',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: onViewTimetable,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      hasClasses ? 'View Schedule' : 'View Timetable',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6C63FF),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Right side decorative icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.school_rounded,
                color: Colors.white, size: 32),
          ),
        ],
      ),
    );
  }
}

// ─── Stat Badge ───────────────────────────────────────────────────────────────

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;
  const _StatBadge({
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _kTextBody,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Quick Card ───────────────────────────────────────────────────────────────

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final String count;
  final VoidCallback onTap;

  const _QuickCard({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Left: icon in tinted circle
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconBg.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconBg, size: 22),
                ),
                const SizedBox(width: 14),
                // Middle: title + subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _kTextHead,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _kTextBody,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Right: pill badge + count
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _PillBadge(label: badge, color: badgeColor),
                    const SizedBox(height: 4),
                    Text(
                      '$count ${count == '1' ? 'item' : 'items'}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: _kTextBody,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Pill Badge ───────────────────────────────────────────────────────────────

class _PillBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _PillBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}
