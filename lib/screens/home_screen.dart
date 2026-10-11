import 'package:flutter/material.dart';
import '../app/routes.dart';
import '../core/colors.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final navItems = [
      {
        'title': 'Notes',
        'subtitle': 'Manage lecture & study notes',
        'icon': Icons.menu_book_rounded,
        'color': const Color(0xFF4F6FFF),
        'route': AppRoutes.notes,
      },
      {
        'title': 'Tasks',
        'subtitle': 'Track assignments & to-dos',
        'icon': Icons.check_circle_outline_rounded,
        'color': const Color(0xFF10B981),
        'route': AppRoutes.tasks,
      },
      {
        'title': 'Timetable',
        'subtitle': 'View weekly class schedule',
        'icon': Icons.calendar_today_rounded,
        'color': const Color(0xFFF59E0B),
        'route': AppRoutes.timetable,
      },
      {
        'title': 'Profile',
        'subtitle': 'Student details & settings',
        'icon': Icons.person_rounded,
        'color': const Color(0xFF8B5CF6),
        'route': AppRoutes.profile,
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'StudyMate',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.profile),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20.0),
          children: [
            // Welcome Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back! 👋',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Ready to organize your study day?',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Quick Access',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),
            // Navigation Items
            ...navItems.map((item) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                color: AppColors.surface,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (item['color'] as Color).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      item['icon'] as IconData,
                      color: item['color'] as Color,
                      size: 26,
                    ),
                  ),
                  title: Text(
                    item['title'] as String,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: AppColors.textDark,
                    ),
                  ),
                  subtitle: Text(
                    item['subtitle'] as String,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textLight,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: AppColors.textLight,
                  ),
                  onTap: () {
                    Navigator.pushNamed(context, item['route'] as String);
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

