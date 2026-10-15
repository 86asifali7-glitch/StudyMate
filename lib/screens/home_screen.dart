import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/colors.dart';

// ─── Color palette extensions for the home screen ────────────────────────────
const _kBlue = Color(0xFF4F6FFF);
const _kPurple = Color(0xFF7C3AED);
const _kGreen = Color(0xFF10B981);
const _kAmber = Color(0xFFF59E0B);

// ─── Screen ──────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  /// Called when the user taps a quick-access card or stat card.
  /// [tabIndex] corresponds to the MainShell IndexedStack position:
  ///   1 = Notes, 2 = Tasks, 3 = Timetable.
  final void Function(int tabIndex)? onNavigate;

  const HomeScreen({super.key, this.onNavigate});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _bannerAnimCtrl;
  late Animation<double> _bannerFade;

  // Quick‑access section data (tabIndex matches MainShell's IndexedStack order)
  static const _quickItems = [
    _QuickItem(
      title: 'Notes',
      subtitle: 'Lecture & study notes',
      icon: Icons.menu_book_rounded,
      color: _kBlue,
      tabIndex: 1,
    ),
    _QuickItem(
      title: 'Tasks',
      subtitle: 'Assignments & to‑dos',
      icon: Icons.check_circle_outline_rounded,
      color: _kGreen,
      tabIndex: 2,
    ),
    _QuickItem(
      title: 'Timetable',
      subtitle: 'Weekly class schedule',
      icon: Icons.calendar_month_rounded,
      color: _kAmber,
      tabIndex: 3,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _bannerAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _bannerFade = CurvedAnimation(
      parent: _bannerAnimCtrl,
      curve: Curves.easeOut,
    );
    _bannerAnimCtrl.forward();
  }

  @override
  void dispose() {
    _bannerAnimCtrl.dispose();
    super.dispose();
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _navigateTo(int tabIndex) {
    widget.onNavigate?.call(tabIndex);
  }

  @override
  Widget build(BuildContext context) {
    // Make the status bar icons dark (suits the light header)
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: Colors.transparent,
    ));

    return Scaffold(
      backgroundColor: AppColors.background,
      // ── No AppBar — custom header inside body ──
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Top bar ──────────────────────────────────────────────────
            SliverToBoxAdapter(child: _buildTopBar()),

            // ── Greeting ─────────────────────────────────────────────────
            SliverToBoxAdapter(child: _buildGreeting()),

            // ── Banner ───────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: FadeTransition(
                  opacity: _bannerFade,
                  child: _buildBanner(),
                ),
              ),
            ),

            // ── Stat cards ───────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _buildStatRow(),
              ),
            ),

            // ── Daily Focus ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _buildDailyFocus(),
              ),
            ),

            // ── Quick Access header ───────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: _sectionHeader('Quick Access'),
              ),
            ),

            // ── Quick Access cards ────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _buildQuickCard(_quickItems[i]),
                  childCount: _quickItems.length,
                ),
              ),
            ),
          ],
        ),
      ),

    );
  }

  // ── Top Bar ──────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 6),
      child: Row(
        children: [
          // Logo
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _kBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.auto_stories_rounded,
              color: _kBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'StudyMate',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
              letterSpacing: 0.2,
            ),
          ),
          const Spacer(),
          // Notification bell
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  size: 20,
                  color: AppColors.textDark,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Greeting ─────────────────────────────────────────────────────────────

  Widget _buildGreeting() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$_greeting! 👋',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Let's make today productive.",
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textLight,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Banner ────────────────────────────────────────────────────────────────

  Widget _buildBanner() {
    return Container(
      height: 130,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kBlue, _kPurple],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _kBlue.withValues(alpha: 0.30),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Decorative circles
            Positioned(
              right: -16,
              top: -22,
              child: _circle(100, Colors.white.withValues(alpha: 0.08)),
            ),
            Positioned(
              right: 60,
              bottom: -28,
              child: _circle(80, Colors.white.withValues(alpha: 0.06)),
            ),
            Positioned(
              left: -20,
              bottom: -30,
              child: _circle(90, Colors.white.withValues(alpha: 0.05)),
            ),
            // Content
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(
                children: [
                  // Left text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Your Study Space',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Stay focused.\nProgress daily. 🎯',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white70,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Right icon badge
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      color: Colors.white,
                      size: 28,
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

  Widget _circle(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );

  // ── Stat Row ──────────────────────────────────────────────────────────────

  Widget _buildStatRow() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Notes',
            count: '12',
            icon: Icons.menu_book_rounded,
            color: _kBlue,
            onTap: () => _navigateTo(1),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Tasks',
            count: '4',
            icon: Icons.assignment_outlined,
            color: _kAmber,
            onTap: () => _navigateTo(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Classes',
            count: '3',
            icon: Icons.schedule_rounded,
            color: _kGreen,
            onTap: () => _navigateTo(3),
          ),
        ),
      ],
    );
  }

  // ── Daily Focus ───────────────────────────────────────────────────────────

  Widget _buildDailyFocus() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Daily Focus'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Tag chip
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _kBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Today\'s Focus',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _kBlue,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Focus label
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.bolt_rounded,
                      size: 16,
                      color: _kAmber,
                    ),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Text(
                        'Calculus II  •  09:00 AM',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Quick Access card ─────────────────────────────────────────────────────

  Widget _buildQuickCard(_QuickItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _navigateTo(item.tabIndex),
          child: Ink(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.black.withValues(alpha: 0.05),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Icon container
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(item.icon, color: item.color, size: 24),
                  ),
                  const SizedBox(width: 14),
                  // Labels
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Arrow badge
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 13,
                      color: item.color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Helper ────────────────────────────────────────────────────────────────

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: AppColors.textDark,
        letterSpacing: 0.1,
      ),
    );
  }
}

// ─── Small data classes / components ─────────────────────────────────────────

class _QuickItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final int tabIndex;

  const _QuickItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.tabIndex,
  });
}

// ─── Stat Card ───────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String count;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _StatCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                const SizedBox(height: 10),
                Text(
                  count,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

