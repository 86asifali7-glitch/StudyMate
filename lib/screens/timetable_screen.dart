import 'package:flutter/material.dart';
import '../core/colors.dart';

class TimetableScreen extends StatelessWidget {
  const TimetableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Map<String, List<Map<String, String>>> weeklySchedule = {
      'Monday': [
        {
          'subject': 'Calculus II',
          'time': '09:00 AM - 10:30 AM',
          'room': 'Hall A • Prof. Miller',
        },
        {
          'subject': 'Physics Mechanics',
          'time': '11:00 AM - 12:30 PM',
          'room': 'Lab 3 • Dr. Robert',
        },
        {
          'subject': 'Computer Architecture',
          'time': '02:00 PM - 03:30 PM',
          'room': 'Room 102 • Prof. Lee',
        },
      ],
      'Tuesday': [
        {
          'subject': 'Data Structures',
          'time': '10:00 AM - 11:30 AM',
          'room': 'Lab 1 • Dr. Harris',
        },
        {
          'subject': 'Technical Writing',
          'time': '01:00 PM - 02:30 PM',
          'room': 'Room 304 • Prof. Clark',
        },
      ],
      'Wednesday': [
        {
          'subject': 'Calculus II',
          'time': '09:00 AM - 10:30 AM',
          'room': 'Hall A • Prof. Miller',
        },
        {
          'subject': 'Physics Lab',
          'time': '01:00 PM - 03:00 PM',
          'room': 'Physics Lab 2',
        },
      ],
      'Thursday': [
        {
          'subject': 'Data Structures Lab',
          'time': '10:00 AM - 12:00 PM',
          'room': 'CS Lab 4 • Dr. Harris',
        },
        {
          'subject': 'Linear Algebra',
          'time': '02:00 PM - 03:30 PM',
          'room': 'Room 205 • Prof. Adams',
        },
      ],
      'Friday': [
        {
          'subject': 'Computer Architecture',
          'time': '09:30 AM - 11:00 AM',
          'room': 'Room 102 • Prof. Lee',
        },
        {
          'subject': 'Group Study & Review',
          'time': '02:00 PM - 04:00 PM',
          'room': 'Library Discussion Room B',
        },
      ],
    };

    final days = weeklySchedule.keys.toList();

    return DefaultTabController(
      length: days.length,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Weekly Timetable'),
          elevation: 0,
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: days.map((day) => Tab(text: day)).toList(),
          ),
        ),
        body: TabBarView(
          children: days.map((day) {
            final classes = weeklySchedule[day]!;
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: classes.length,
              itemBuilder: (context, index) {
                final classInfo = classes[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: Colors.black.withValues(alpha: 0.05),
                    ),
                  ),
                  color: AppColors.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.access_time_rounded,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                classInfo['subject']!,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                classInfo['time']!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                classInfo['room']!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}

