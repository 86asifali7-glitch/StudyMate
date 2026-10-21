import 'package:flutter/material.dart';
import '../core/colors.dart';
import 'home_screen.dart';
import 'notes_screen.dart';
import 'tasks_screen.dart';
import 'timetable_screen.dart';

// ─── Color constant matching the design system ────────────────────────────────
const _kBlue = AppColors.primary;

// ─── Nav destination descriptors ─────────────────────────────────────────────
class _NavDest {
  final String label;
  final IconData icon;
  const _NavDest({required this.label, required this.icon});
}

const _navDestinations = [
  _NavDest(label: 'Home', icon: Icons.home_rounded),
  _NavDest(label: 'Notes', icon: Icons.menu_book_rounded),
  _NavDest(label: 'Tasks', icon: Icons.check_circle_outline_rounded),
  _NavDest(label: 'Timetable', icon: Icons.calendar_month_rounded),
];

// ─── Shell ───────────────────────────────────────────────────────────────────

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(onNavigate: _onNavTap),
      const NotesScreen(),
      const TasksScreen(),
      const TimetableScreen(),
    ];
  }

  void _onNavTap(int index) {
    if (index != _selectedIndex) {
      setState(() => _selectedIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Each child screen has its own Scaffold with AppBar / body, so this
      // outer Scaffold only needs to provide the persistent bottom bar.
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              _navDestinations.length,
              (i) => _NavBarItem(
                dest: _navDestinations[i],
                isSelected: _selectedIndex == i,
                onTap: () => _onNavTap(i),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Bottom Nav Item (standardized blue & slate gray) ────────────────────────

class _NavBarItem extends StatelessWidget {
  final _NavDest dest;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.dest,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: isSelected
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryLight
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              dest.icon,
              size: 20,
              color: isSelected ? _kBlue : AppColors.textLight,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                dest.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _kBlue,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
