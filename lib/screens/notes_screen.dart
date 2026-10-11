import 'package:flutter/material.dart';
import '../core/colors.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final List<Map<String, String>> _notes = [
    {
      'title': 'Calculus Derivatives & Integrals',
      'subject': 'Mathematics',
      'date': 'Oct 10, 2026',
    },
    {
      'title': 'Newton\'s Laws of Motion Summary',
      'subject': 'Physics',
      'date': 'Oct 9, 2026',
    },
    {
      'title': 'Organic Chemistry Reactions',
      'subject': 'Chemistry',
      'date': 'Oct 7, 2026',
    },
  ];

  void _showAddNoteDialog() {
    final titleController = TextEditingController();
    final subjectController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Add New Note'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Note Title',
                  hintText: 'e.g., Chapter 4 Key Concepts',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: subjectController,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  hintText: 'e.g., Biology',
                ),
              ),
            ],
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
                if (titleController.text.trim().isNotEmpty) {
                  setState(() {
                    _notes.insert(0, {
                      'title': titleController.text.trim(),
                      'subject': subjectController.text.trim().isEmpty
                          ? 'General'
                          : subjectController.text.trim(),
                      'date': 'Today',
                    });
                  });
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Add Note'),
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
        title: const Text('My Notes'),
        elevation: 0,
      ),
      body: _notes.isEmpty
          ? const Center(
              child: Text(
                'No notes yet. Tap + to add one!',
                style: TextStyle(color: AppColors.textLight, fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _notes.length,
              itemBuilder: (context, index) {
                final note = _notes[index];
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
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.description_outlined,
                        color: AppColors.primary,
                      ),
                    ),
                    title: Text(
                      note['title']!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    subtitle: Text(
                      '${note['subject']} • ${note['date']}',
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontSize: 13,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _notes.removeAt(index);
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
        onPressed: _showAddNoteDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Note'),
      ),
    );
  }
}

