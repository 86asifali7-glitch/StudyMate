import 'package:flutter/material.dart';
import '../core/colors.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final List<Map<String, dynamic>> _tasks = [
    {
      'title': 'Complete Calculus Problem Set 3',
      'isCompleted': false,
      'due': 'Due Tomorrow',
    },
    {
      'title': 'Read Physics Chapter 5 Summary',
      'isCompleted': true,
      'due': 'Completed',
    },
    {
      'title': 'Submit Chemistry Lab Report',
      'isCompleted': false,
      'due': 'Due Friday',
    },
    {
      'title': 'Prepare Flashcards for History',
      'isCompleted': false,
      'due': 'Due Sunday',
    },
  ];

  void _showAddTaskDialog() {
    final taskController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Add New Task'),
          content: TextField(
            controller: taskController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'e.g., Read biology pages 40-55',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (taskController.text.trim().isNotEmpty) {
                  setState(() {
                    _tasks.add({
                      'title': taskController.text.trim(),
                      'isCompleted': false,
                      'due': 'Pending',
                    });
                  });
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Add Task'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Study Tasks'),
        elevation: 0,
      ),
      body: _tasks.isEmpty
          ? const Center(
              child: Text(
                'No tasks yet. Tap + to add a study task!',
                style: TextStyle(color: AppColors.textLight, fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                final task = _tasks[index];
                final isDone = task['isCompleted'] as bool;

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: Colors.black.withValues(alpha: 0.05),
                    ),
                  ),
                  color: AppColors.surface,
                  child: CheckboxListTile(
                    value: isDone,
                    activeColor: AppColors.primary,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    title: Text(
                      task['title'] as String,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        color: isDone ? AppColors.textLight : AppColors.textDark,
                      ),
                    ),
                    subtitle: Text(
                      task['due'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDone ? AppColors.textLight : AppColors.primary,
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {
                        task['isCompleted'] = val ?? false;
                      });
                    },
                    secondary: IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _tasks.removeAt(index);
                        });
                      },
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: _showAddTaskDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
      ),
    );
  }
}

