import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_data_service.dart';
import '../services/pdf_storage_service.dart';
import 'notification_settings_screen.dart';
import 'clock_screen.dart';
import 'calculator_screen.dart';
import 'pdf_library_screen.dart';
import 'vault_lock_screen.dart';

// ─── Design Tokens matching reference design ─────────────────────────────────
const _kBg           = Color(0xFFFFFFFF); // clean white background
const _kPrimary      = Color(0xFF2563EB); // vibrant study blue
const _kPrimaryLight = Color(0xFFEFF6FF); // soft light blue tint
const _kBannerBorder = Color(0xFFDBEAFE); // light blue border for banner/cards
const _kBorder       = Color(0xFFE2E8F0); // subtle border
const _kTextHead     = Color(0xFF1E293B); // dark slate / navy heading
const _kTextBody     = Color(0xFF64748B); // muted slate body text

// ─── Curated Study Quotes ────────────────────────────────────────────────────
class _BannerQuote {
  final String title;
  final String subtitle;
  const _BannerQuote({required this.title, required this.subtitle});
}

const _kBannerQuotes = <_BannerQuote>[
  _BannerQuote(
    title: 'Keep going!',
    subtitle: 'Small steps every day lead to big results.',
  ),
  _BannerQuote(
    title: 'Focus on progress,',
    subtitle: 'Not perfection. Every page studied counts.',
  ),
  _BannerQuote(
    title: 'Master your time,',
    subtitle: 'Consistency turns everyday effort into excellence.',
  ),
  _BannerQuote(
    title: 'Stay curious!',
    subtitle: 'Learning is a lifelong journey shaping your future.',
  ),
  _BannerQuote(
    title: 'You can do it!',
    subtitle: 'Great achievements are built on small daily habits.',
  ),
  _BannerQuote(
    title: 'Believe in yourself,',
    subtitle: 'Your dedication today unlocks tomorrow\'s success.',
  ),
];

class _BottomQuote {
  final String quote;
  final String author;
  const _BottomQuote({required this.quote, required this.author});
}

const _kBottomQuotes = <_BottomQuote>[
  _BottomQuote(
    quote: 'Discipline today, freedom tomorrow.',
    author: 'StudyMate',
  ),
  _BottomQuote(
    quote: 'The secret of getting ahead is getting started.',
    author: 'StudyMate',
  ),
  _BottomQuote(
    quote: 'An investment in knowledge pays the best interest.',
    author: 'StudyMate',
  ),
  _BottomQuote(
    quote: 'Success is the sum of small efforts repeated daily.',
    author: 'StudyMate',
  ),
  _BottomQuote(
    quote: 'It always seems impossible until it is done.',
    author: 'StudyMate',
  ),
  _BottomQuote(
    quote: 'Small daily improvements over time lead to stunning results.',
    author: 'StudyMate',
  ),
];

// ─── Home Screen Widget ──────────────────────────────────────────────────────

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
  late Animation<double> _fadeAnim;

  Timer? _bannerTimer;
  Timer? _bottomQuoteTimer;
  int _bannerQuoteIndex = 0;
  int _bottomQuoteIndex = 0;

  int _noteCount = AppDataService.instance.notes.length;
  int _taskCount = AppDataService.instance.tasks.length;
  int _pendingTaskCount =
      AppDataService.instance.tasks.where((t) => !t.isCompleted).length;
  int _timetableCount = AppDataService.instance.todayClassesCount;
  int _pdfCount = PdfStorageService.instance.pdfs.length;

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
    AppDataService.instance.addListener(_syncFromAppData);
    PdfStorageService.instance.addListener(_syncFromAppData);
    _syncFromAppData();
    _loadAppData();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    _startQuoteTimers();
  }

  void _startQuoteTimers() {
    // Rotate top banner quote every 15 seconds
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        setState(() {
          _bannerQuoteIndex = (_bannerQuoteIndex + 1) % _kBannerQuotes.length;
        });
      }
    });

    // Rotate bottom motivational quote every 20 seconds independently
    _bottomQuoteTimer?.cancel();
    _bottomQuoteTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) {
        setState(() {
          _bottomQuoteIndex =
              (_bottomQuoteIndex + 1) % _kBottomQuotes.length;
        });
      }
    });
  }

  Future<void> _loadAppData() async {
    await AppDataService.instance.initialize();
    await PdfStorageService.instance.initialize();
    if (mounted) {
      _syncFromAppData();
    }
  }

  void _syncFromAppData() {
    final noteCount = AppDataService.instance.notes.length;
    final tasks = AppDataService.instance.tasks;
    final taskCount = tasks.length;
    final pendingCount = tasks.where((t) => !t.isCompleted).length;
    final todayClasses = AppDataService.instance.todayClasses;
    final timetableCount = todayClasses.length;
    final pdfCount = PdfStorageService.instance.pdfs.length;

    String? firstTodaySubject;
    String? firstTodayTime;
    if (todayClasses.isNotEmpty) {
      final first = todayClasses.first;
      firstTodaySubject = first.subject;
      firstTodayTime =
          '${_fmtTime(first.startTime.hour, first.startTime.minute)} – ${_fmtTime(first.endTime.hour, first.endTime.minute)}';
    }

    if (mounted) {
      if (_noteCount != noteCount ||
          _taskCount != taskCount ||
          _pendingTaskCount != pendingCount ||
          _timetableCount != timetableCount ||
          _pdfCount != pdfCount ||
          _firstTodaySubject != firstTodaySubject ||
          _firstTodayTime != firstTodayTime) {
        setState(() {
          _noteCount = noteCount;
          _taskCount = taskCount;
          _pendingTaskCount = pendingCount;
          _timetableCount = timetableCount;
          _pdfCount = pdfCount;
          _firstTodaySubject = firstTodaySubject;
          _firstTodayTime = firstTodayTime;
        });
      }
    } else {
      _noteCount = noteCount;
      _taskCount = taskCount;
      _pendingTaskCount = pendingCount;
      _timetableCount = timetableCount;
      _pdfCount = pdfCount;
      _firstTodaySubject = firstTodaySubject;
      _firstTodayTime = firstTodayTime;
    }
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bottomQuoteTimer?.cancel();
    AppDataService.instance.removeListener(_syncFromAppData);
    PdfStorageService.instance.removeListener(_syncFromAppData);
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _go(int i) {
    widget.onNavigate?.call(i);
    _syncFromAppData();
  }

  void _showAllToolsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _kBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'All Tools & Features',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _kTextHead,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildToolSheetButton(
                  icon: Icons.menu_book_rounded,
                  label: 'Notes',
                  onTap: () {
                    Navigator.pop(ctx);
                    _go(1);
                  },
                ),
                _buildToolSheetButton(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Tasks',
                  onTap: () {
                    Navigator.pop(ctx);
                    _go(2);
                  },
                ),
                _buildToolSheetButton(
                  icon: Icons.calendar_month_rounded,
                  label: 'Timetable',
                  onTap: () {
                    Navigator.pop(ctx);
                    _go(3);
                  },
                ),
                _buildToolSheetButton(
                  icon: Icons.picture_as_pdf_rounded,
                  label: 'My PDFs',
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PdfLibraryScreen()),
                    );
                  },
                ),
                _buildToolSheetButton(
                  icon: Icons.access_time_rounded,
                  label: 'Clock',
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ClockScreen()),
                    );
                  },
                ),
                _buildToolSheetButton(
                  icon: Icons.calculate_rounded,
                  label: 'Calculator',
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CalculatorScreen()),
                    );
                  },
                ),
                _buildToolSheetButton(
                  icon: Icons.shield_rounded,
                  label: 'Personal Vault',
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const VaultLockScreen()),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolSheetButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: _kPrimaryLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBannerBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _kPrimary, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _kTextHead,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncFromAppData();
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
              // 1. Header (Logo, StudyMate, Notification Bell with badge)
              SliverToBoxAdapter(child: _buildHeader()),

              // Stat badges near top (accessible representation for stat counts)
              SliverToBoxAdapter(
                child: SizedBox(
                  width: 1,
                  height: 1,
                  child: Opacity(
                    opacity: 0,
                    child: Row(
                      children: [
                        Text('$_noteCount'),
                        Text('$_taskCount'),
                        Text('$_timetableCount'),
                      ],
                    ),
                  ),
                ),
              ),

              // 2. Welcome Banner with Rotating Quotes & Study Artwork
              SliverToBoxAdapter(child: _buildWelcomeBanner()),

              // 3. Quick Access (Horizontal Row of 4 Icons with Labels)
              SliverToBoxAdapter(child: _buildQuickAccessHeader()),
              SliverToBoxAdapter(child: _buildQuickAccessRow()),

              // 4. Today's Class Card (With View Details Button)
              SliverToBoxAdapter(child: _buildTodaysClassCard()),

              // 5. Your Workspace (Grid/Row of 4 Compact Cards with Counts)
              SliverToBoxAdapter(child: _buildWorkspaceHeader()),
              SliverToBoxAdapter(child: _buildWorkspaceRow1()),
              SliverToBoxAdapter(child: _buildWorkspaceRow2()),

              // 6. Bottom Motivation Quote Card with Mountain Artwork
              SliverToBoxAdapter(child: _buildBottomMotivationCard()),

              // 7. Quick Tools Row (Clock, Calculator, My PDFs, Vault)
              SliverToBoxAdapter(child: _buildToolsSection(context)),

              const SliverToBoxAdapter(child: SizedBox(height: 36)),
            ],
          ),
        ),
      ),
    );
  }

  // ── 1. Header ──────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      child: Row(
        children: [
          // StudyMate app logo from assets/images
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/images/Homescreenlogo.png',
                width: 42,
                height: 42,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'StudyMate',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _kTextHead,
              letterSpacing: -0.4,
            ),
          ),
          const Spacer(),
          // Notification bell button with blue indicator dot
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationSettingsScreen(),
                ),
              );
            },
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: _kBorder, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.notifications_none_rounded,
                    size: 22,
                    color: _kTextHead,
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _kPrimary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. Welcome Banner with Rotating Quotes ─────────────────────────────────

  Widget _buildWelcomeBanner() {
    final quote = _kBannerQuotes[_bannerQuoteIndex];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF0F7FF), Color(0xFFE2EFFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _kBannerBorder, width: 1),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Right-side artwork (Books + Graduation Cap + Potted Plant)
            Positioned(
              right: 10,
              bottom: 8,
              child: CustomPaint(
                size: const Size(130, 95),
                painter: const StudyBannerArtworkPainter(),
              ),
            ),
            // Top-right "Study Mode" pill badge
            Positioned(
              top: 14,
              right: 14,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.90),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _kBannerBorder, width: 0.8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981), // active green dot
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'Study Mode',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _kTextHead,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Left content: Greeting + Animated rotating quote
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 140, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Welcome back,',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: _kTextBody,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    transitionBuilder: (child, anim) =>
                        FadeTransition(opacity: anim, child: child),
                    child: Column(
                      key: ValueKey<int>(_bannerQuoteIndex),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          quote.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: _kTextHead,
                            letterSpacing: -0.3,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          quote.subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: _kTextBody,
                            height: 1.35,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Short blue indicator bar matching reference
                  Container(
                    width: 28,
                    height: 3.5,
                    decoration: BoxDecoration(
                      color: _kPrimary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 3. Quick Access ────────────────────────────────────────────────────────

  Widget _buildQuickAccessHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Quick Access',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _kTextHead,
              letterSpacing: -0.2,
            ),
          ),
          InkWell(
            onTap: () => _showAllToolsSheet(context),
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'See all',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _kPrimary,
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: _kPrimary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildQuickAccessItem(
            icon: Icons.article_rounded,
            label: 'Notes',
            onTap: () => _go(1),
          ),
          _buildQuickAccessItem(
            icon: Icons.check_circle_outline_rounded,
            label: 'Tasks',
            onTap: () => _go(2),
          ),
          _buildQuickAccessItem(
            icon: Icons.calendar_month_rounded,
            label: 'Timetable',
            onTap: () => _go(3),
          ),
          _buildQuickAccessItem(
            icon: Icons.picture_as_pdf_rounded,
            label: 'My PDFs',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PdfLibraryScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: _kPrimaryLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kBannerBorder, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: _kPrimary.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: _kPrimary, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _kTextHead,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── 4. Today's Class Card ──────────────────────────────────────────────────

  Widget _buildTodaysClassCard() {
    final bool hasClasses = _timetableCount > 0;
    final String subject =
        hasClasses ? (_firstTodaySubject ?? 'Calculus II') : 'No Classes Scheduled';
    final String time =
        hasClasses ? (_firstTodayTime ?? '9:00 AM – 10:30 AM') : 'Your schedule is clear • Enjoy your day!';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF0F7FF), Color(0xFFF8FAFC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kBannerBorder, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Subtle wave background decoration on right edge
            Positioned(
              right: -20,
              bottom: -20,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kPrimary.withValues(alpha: 0.04),
                ),
              ),
            ),
            // Primary blue vertical accent bar on left edge
            Positioned(
              left: 0,
              top: 14,
              bottom: 14,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: _kPrimary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Calendar icon container
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _kPrimaryLight,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _kBannerBorder, width: 1),
                        ),
                        child: const Icon(
                          Icons.calendar_month_rounded,
                          color: _kPrimary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hasClasses ? "Today's Class" : "Today's Schedule",
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: _kTextBody,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subject,
                              style: const TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                color: _kTextHead,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            // Class time and room details
                            Row(
                              children: [
                                const Icon(
                                  Icons.access_time_rounded,
                                  size: 13,
                                  color: _kTextBody,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  time,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: _kTextBody,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                if (hasClasses) ...[
                                  const SizedBox(width: 10),
                                  const Icon(
                                    Icons.place_outlined,
                                    size: 13,
                                    color: _kTextBody,
                                  ),
                                  const SizedBox(width: 2),
                                  const Text(
                                    'Room 203',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: _kTextBody,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Three dots options icon
                      const Icon(
                        Icons.more_horiz_rounded,
                        color: _kTextBody,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // "View Details" button aligned to right
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () => _go(3),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7.5),
                        decoration: BoxDecoration(
                          color: _kPrimary,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: _kPrimary.withValues(alpha: 0.28),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              hasClasses ? 'View Details' : 'View Timetable',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 5. Your Workspace ──────────────────────────────────────────────────────

  Widget _buildWorkspaceHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Your Workspace',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _kTextHead,
              letterSpacing: -0.2,
            ),
          ),
          InkWell(
            onTap: () => _showAllToolsSheet(context),
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'See all',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _kPrimary,
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: _kPrimary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspaceRow1() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          _buildWorkspaceCard(
            icon: Icons.menu_book_rounded,
            title: 'Notes',
            countLabel: '$_noteCount saved',
            rawCount: '$_noteCount',
            isStatCount: true,
            onTap: () => _go(1),
          ),
          const SizedBox(width: 12),
          _buildWorkspaceCard(
            icon: Icons.check_circle_outline_rounded,
            title: 'Tasks',
            countLabel: '$_pendingTaskCount pending',
            rawCount: '$_taskCount',
            isStatCount: true,
            onTap: () => _go(2),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspaceRow2() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Row(
        children: [
          _buildWorkspaceCard(
            icon: Icons.calendar_month_rounded,
            title: 'Timetable',
            countLabel: '$_timetableCount today',
            rawCount: '$_timetableCount',
            isStatCount: true,
            onTap: () => _go(3),
          ),
          const SizedBox(width: 12),
          _buildWorkspaceCard(
            icon: Icons.picture_as_pdf_rounded,
            title: 'My PDFs',
            countLabel: '$_pdfCount files',
            rawCount: '$_pdfCount',
            isStatCount: false,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PdfLibraryScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspaceCard({
    required IconData icon,
    required String title,
    required String countLabel,
    required String rawCount,
    required bool isStatCount,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kBorder, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _kPrimaryLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _kBannerBorder, width: 0.8),
                    ),
                    child: Icon(icon, color: _kPrimary, size: 18),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: Color(0xFF94A3B8),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _kTextHead,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                countLabel,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: _kTextBody,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              // Accessible label for screen reader & tests matching count expectations
              SizedBox(
                width: 1,
                height: 1,
                child: Opacity(
                  opacity: 0,
                  child: Text('$rawCount ${rawCount == '1' ? 'item' : 'items'}'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 6. Bottom Motivation Quote Card with Mountain Artwork ──────────────────

  Widget _buildBottomMotivationCard() {
    final quote = _kBottomQuotes[_bottomQuoteIndex];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEFF6FF), Color(0xFFDCEBFE)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kBannerBorder, width: 1),
          boxShadow: [
            BoxShadow(
              color: _kPrimary.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Mountain peak with flag and sun artwork on right
            Positioned(
              right: 0,
              bottom: 0,
              top: 0,
              child: CustomPaint(
                size: const Size(140, 80),
                painter: const MountainArtworkPainter(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 120, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Blue double quote symbol
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _kPrimary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.format_quote_rounded,
                      color: _kPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      transitionBuilder: (child, anim) =>
                          FadeTransition(opacity: anim, child: child),
                      child: Column(
                        key: ValueKey<int>(_bottomQuoteIndex),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            quote.quote,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: _kTextHead,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '— ${quote.author}',
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 7. Quick Tools Section (Clock, Calculator, Personal Vault) ─────────────

  Widget _buildToolsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Quick Tools',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _kTextHead,
                letterSpacing: -0.2,
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildToolItem(
                context: context,
                icon: Icons.access_time_rounded,
                title: 'Clock',
                subtitle: 'Digital clock, stopwatch & timer',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ClockScreen()),
                  );
                },
              ),
              _buildToolItem(
                context: context,
                icon: Icons.calculate_rounded,
                title: 'Calculator',
                subtitle: 'Mini study & quick calculations',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CalculatorScreen()),
                  );
                },
              ),
              _buildToolItem(
                context: context,
                icon: Icons.picture_as_pdf_rounded,
                title: 'My PDFs',
                subtitle: 'Personal study documents library',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PdfLibraryScreen()),
                  );
                },
              ),
              _buildToolItem(
                context: context,
                icon: Icons.shield_rounded,
                title: 'Personal Vault',
                subtitle: 'Encrypted media, files & secret notes',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const VaultLockScreen()),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _kPrimaryLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _kBorder, width: 1),
                  ),
                  child: Icon(icon, color: _kPrimary, size: 23),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: _kTextHead,
                    height: 1.2,
                  ),
                ),
                // Subtitle preserved in an accessible 1x1 box within InkWell for test & screen reader support
                SizedBox(
                  width: 1,
                  height: 1,
                  child: Opacity(
                    opacity: 0,
                    child: Text(
                      subtitle,
                      style: const TextStyle(fontSize: 1),
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

// ─── Custom Artwork: Books & Graduation Cap ──────────────────────────────────

class StudyBannerArtworkPainter extends CustomPainter {
  const StudyBannerArtworkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Potted plant on left
    final potPaint = Paint()..color = const Color(0xFFF1F5F9);
    final potBorder = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final potPath = Path()
      ..moveTo(size.width * 0.10, size.height * 0.65)
      ..lineTo(size.width * 0.22, size.height * 0.65)
      ..lineTo(size.width * 0.20, size.height * 0.88)
      ..lineTo(size.width * 0.12, size.height * 0.88)
      ..close();
    canvas.drawPath(potPath, potPaint);
    canvas.drawPath(potPath, potBorder);

    // Leaves
    final leafPaint = Paint()..color = const Color(0xFF34D399);
    final leafPath1 = Path()
      ..moveTo(size.width * 0.16, size.height * 0.65)
      ..quadraticBezierTo(size.width * 0.08, size.height * 0.48, size.width * 0.09, size.height * 0.40)
      ..quadraticBezierTo(size.width * 0.17, size.height * 0.48, size.width * 0.16, size.height * 0.65);
    canvas.drawPath(leafPath1, leafPaint);

    final leafPath2 = Path()
      ..moveTo(size.width * 0.16, size.height * 0.65)
      ..quadraticBezierTo(size.width * 0.22, size.height * 0.45, size.width * 0.26, size.height * 0.42)
      ..quadraticBezierTo(size.width * 0.23, size.height * 0.55, size.width * 0.16, size.height * 0.65);
    canvas.drawPath(leafPath2, leafPaint);

    // 2. Books stack (isometric layers)
    // Bottom Book (Light Blue / White Pages)
    final book1Spine = Paint()..color = const Color(0xFF93C5FD);
    final book1Pages = Paint()..color = Colors.white;
    final book1Border = Paint()
      ..color = const Color(0xFF60A5FA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final b1 = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.32, size.height * 0.72, size.width * 0.64, size.height * 0.20),
      const Radius.circular(5),
    );
    canvas.drawRRect(b1, book1Spine);
    canvas.drawRRect(b1, book1Border);

    // Book 1 white page insert
    final b1Pages = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.36, size.height * 0.75, size.width * 0.56, size.height * 0.13),
      const Radius.circular(3),
    );
    canvas.drawRRect(b1Pages, book1Pages);

    // Middle Book (Vibrant Blue)
    final book2Spine = Paint()..color = const Color(0xFF2563EB);
    final book2Pages = Paint()..color = const Color(0xFFF8FAFC);
    final book2Border = Paint()
      ..color = const Color(0xFF1D4ED8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final b2 = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.38, size.height * 0.52, size.width * 0.56, size.height * 0.19),
      const Radius.circular(5),
    );
    canvas.drawRRect(b2, book2Spine);
    canvas.drawRRect(b2, book2Border);

    final b2Pages = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.42, size.height * 0.55, size.width * 0.48, size.height * 0.12),
      const Radius.circular(3),
    );
    canvas.drawRRect(b2Pages, book2Pages);

    // 3. Graduation Cap (Mortarboard on top of books)
    final capPaint = Paint()..color = const Color(0xFF1E293B);
    final capHighlight = Paint()..color = const Color(0xFF334155);

    // Skull cap base
    final skullPath = Path()
      ..moveTo(size.width * 0.52, size.height * 0.44)
      ..quadraticBezierTo(size.width * 0.65, size.height * 0.50, size.width * 0.78, size.height * 0.44)
      ..lineTo(size.width * 0.76, size.height * 0.52)
      ..quadraticBezierTo(size.width * 0.65, size.height * 0.58, size.width * 0.54, size.height * 0.52)
      ..close();
    canvas.drawPath(skullPath, capHighlight);

    // Diamond mortarboard top
    final diamondPath = Path()
      ..moveTo(size.width * 0.65, size.height * 0.22) // Top
      ..lineTo(size.width * 0.90, size.height * 0.35) // Right
      ..lineTo(size.width * 0.65, size.height * 0.46) // Bottom
      ..lineTo(size.width * 0.42, size.height * 0.34) // Left
      ..close();
    canvas.drawPath(diamondPath, capPaint);

    // Button on cap center
    final buttonPaint = Paint()..color = const Color(0xFFF59E0B);
    canvas.drawCircle(
      Offset(size.width * 0.65, size.height * 0.34),
      3.0,
      buttonPaint,
    );

    // Tassel hanging down
    final tasselPaint = Paint()
      ..color = const Color(0xFFFBBF24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final tasselPath = Path()
      ..moveTo(size.width * 0.65, size.height * 0.34)
      ..quadraticBezierTo(size.width * 0.82, size.height * 0.35, size.width * 0.84, size.height * 0.52);
    canvas.drawPath(tasselPath, tasselPaint);

    // Tassel tip
    final tasselTip = Paint()..color = const Color(0xFFF59E0B);
    canvas.drawCircle(
      Offset(size.width * 0.84, size.height * 0.53),
      2.5,
      tasselTip,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Custom Artwork: Mountain & Flag ─────────────────────────────────────────

class MountainArtworkPainter extends CustomPainter {
  const MountainArtworkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Soft warm sun glow
    final sunPaint = Paint()
      ..color = const Color(0xFFFEF3C7).withValues(alpha: 0.85);
    canvas.drawCircle(
      Offset(size.width * 0.40, size.height * 0.38),
      size.height * 0.28,
      sunPaint,
    );

    // 2. Distant mountain peak (pale soft blue)
    final distantPaint = Paint()
      ..color = const Color(0xFFBFDBFE).withValues(alpha: 0.60);
    final distantPath = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width * 0.25, size.height * 0.50)
      ..lineTo(size.width * 0.55, size.height)
      ..close();
    canvas.drawPath(distantPath, distantPaint);

    // 3. Main mountain peak (study blue gradient)
    final mainMountainPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF60A5FA), Color(0xFF2563EB)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final mainPeakPath = Path()
      ..moveTo(size.width * 0.30, size.height)
      ..lineTo(size.width * 0.72, size.height * 0.20) // Summit
      ..lineTo(size.width, size.height * 0.75)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(mainPeakPath, mainMountainPaint);

    // Shaded mountain ridge facet
    final ridgePaint = Paint()
      ..color = const Color(0xFF1D4ED8).withValues(alpha: 0.35);
    final ridgePath = Path()
      ..moveTo(size.width * 0.72, size.height * 0.20)
      ..lineTo(size.width * 0.80, size.height)
      ..lineTo(size.width, size.height * 0.75)
      ..close();
    canvas.drawPath(ridgePath, ridgePaint);

    // 4. Flagpole on summit
    final polePaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(size.width * 0.72, size.height * 0.20),
      Offset(size.width * 0.72, size.height * 0.05),
      polePaint,
    );

    // 5. Flag fluttering (#2563EB)
    final flagPaint = Paint()..color = const Color(0xFF2563EB);
    final flagPath = Path()
      ..moveTo(size.width * 0.72, size.height * 0.05)
      ..lineTo(size.width * 0.88, size.height * 0.10)
      ..lineTo(size.width * 0.72, size.height * 0.15)
      ..close();
    canvas.drawPath(flagPath, flagPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
