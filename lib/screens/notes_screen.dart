import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/colors.dart';

class NoteItem {
  final String id;
  final String title;
  final String subject;
  final String content;
  final String date;

  const NoteItem({
    required this.id,
    required this.title,
    required this.subject,
    required this.content,
    required this.date,
  });

  NoteItem copyWith({
    String? id,
    String? title,
    String? subject,
    String? content,
    String? date,
  }) {
    return NoteItem(
      id: id ?? this.id,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      content: content ?? this.content,
      date: date ?? this.date,
    );
  }

  Map<String, String> toMap() => {
    'id': id,
    'title': title,
    'subject': subject,
    'content': content,
    'date': date,
  };

  factory NoteItem.fromMap(Map<String, dynamic> map) => NoteItem(
    id: map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
    title: map['title'] ?? 'Untitled Note',
    subject: map['subject'] ?? 'General',
    content: map['content'] ?? '',
    date: map['date'] ?? 'Today',
  );
}

String _formatCurrentDate() {
  final now = DateTime.now();
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return '${months[now.month - 1]} ${now.day}, ${now.year}';
}

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  // Static cache preserves note content across screen navigations in memory
  static List<NoteItem> _cachedNotes = [
    const NoteItem(
      id: '1',
      title: 'Calculus Derivatives & Integrals',
      subject: 'Mathematics',
      content:
          'Key formulas:\n• d/dx [x^n] = n*x^(n-1)\n• d/dx [sin(x)] = cos(x)\n• d/dx [cos(x)] = -sin(x)\n• d/dx [e^x] = e^x\n\nIntegration by parts:\n∫ u dv = uv - ∫ v du\n\nPractice exercises on page 142 before Thursday tutorial.',
      date: 'Oct 10, 2026',
    ),
    const NoteItem(
      id: '2',
      title: "Newton's Laws of Motion Summary",
      subject: 'Physics',
      content:
          'Core principles of classical mechanics:\n1. First Law (Inertia): An object remains at rest or in uniform motion unless acted upon by a net external force.\n2. Second Law (F = ma): Force equals mass times acceleration.\n3. Third Law (Action & Reaction): Every action has an equal and opposite reaction.\n\nKey equations: F = m*a, p = m*v, W = F*d.',
      date: 'Oct 9, 2026',
    ),
    const NoteItem(
      id: '3',
      title: 'Organic Chemistry Reactions',
      subject: 'Chemistry',
      content:
          'Mechanisms overview:\n• SN1: Two-step, carbocation intermediate, racemization.\n• SN2: One-step backside displacement with inversion of configuration.\n• E1 & E2 elimination competition factors.\n• Markovnikov vs Anti-Markovnikov addition.\n\nReview synthesis questions for exam revision.',
      date: 'Oct 7, 2026',
    ),
  ];

  static bool _hasLoadedFromStorage = false;

  @override
  void initState() {
    super.initState();
    if (!_hasLoadedFromStorage) {
      _loadNotesFromStorage();
    }
  }

  Future<void> _loadNotesFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedData = prefs.getStringList('studymate_saved_notes');
      if (savedData != null && savedData.isNotEmpty) {
        final loaded = savedData
            .map((item) => NoteItem.fromMap(jsonDecode(item) as Map<String, dynamic>))
            .toList();
        if (mounted) {
          setState(() {
            _cachedNotes = loaded;
            _hasLoadedFromStorage = true;
          });
        } else {
          _cachedNotes = loaded;
          _hasLoadedFromStorage = true;
        }
      } else {
        _hasLoadedFromStorage = true;
      }
    } catch (_) {
      _hasLoadedFromStorage = true;
    }
  }

  Future<void> _persistNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList =
          _cachedNotes.map((note) => jsonEncode(note.toMap())).toList();
      await prefs.setStringList('studymate_saved_notes', jsonList);
    } catch (_) {}
  }

  Future<void> _showCreateNoteDialog() async {
    final titleController = TextEditingController();
    final subjectController = TextEditingController();

    final created = await showDialog<NoteItem>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: AppColors.surface,
          elevation: 8,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(22.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.note_add_rounded,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Create Note',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.08),
                      ),
                    ),
                    child: TextField(
                      key: const Key('create_note_title_field'),
                      controller: titleController,
                      autofocus: true,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Title',
                        hintStyle: TextStyle(
                          color: AppColors.textLight,
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.08),
                      ),
                    ),
                    child: TextField(
                      key: const Key('create_note_subject_field'),
                      controller: subjectController,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(
                          Icons.label_outline_rounded,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        prefixIconConstraints: BoxConstraints(
                          minWidth: 26,
                          minHeight: 26,
                        ),
                        hintText: 'Subject',
                        hintStyle: TextStyle(
                          color: AppColors.textLight,
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        key: const Key('cancel_create_note_button'),
                        onPressed: () => Navigator.pop(dialogContext),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textLight,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        key: const Key('dialog_create_note_button'),
                        onPressed: () {
                          final rawTitle = titleController.text.trim();
                          final rawSubject = subjectController.text.trim();
                          final title =
                              rawTitle.isEmpty ? 'Untitled Note' : rawTitle;
                          final subject =
                              rawSubject.isEmpty ? 'General' : rawSubject;

                          final note = NoteItem(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            title: title,
                            subject: subject,
                            content: '',
                            date: _formatCurrentDate(),
                          );
                          Navigator.pop(dialogContext, note);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                        ),
                        child: const Text(
                          'Create',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (created != null) {
      setState(() {
        _cachedNotes.insert(0, created);
      });
      await _persistNotes();
    }
  }

  Future<void> _openNoteEditor({NoteItem? note}) async {
    final result = await Navigator.push<NoteItem>(
      context,
      MaterialPageRoute(
        builder: (context) => NoteEditorScreen(note: note),
      ),
    );

    if (result != null) {
      setState(() {
        final existingIndex =
            _cachedNotes.indexWhere((n) => n.id == result.id);
        if (existingIndex >= 0) {
          _cachedNotes[existingIndex] = result;
        } else {
          _cachedNotes.insert(0, result);
        }
      });
      await _persistNotes();
    }
  }

  void _deleteNote(int index) {
    setState(() {
      _cachedNotes.removeAt(index);
    });
    _persistNotes();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Note deleted'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Notes'),
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () => _showCreateNoteDialog(),
            icon: const Icon(Icons.add, color: Colors.white, size: 18),
            label: const Text(
              'Add Note',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: _cachedNotes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.note_alt_outlined,
                    size: 64,
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No notes yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tap "Create Note" to add your first study note!',
                    style: TextStyle(
                      color: AppColors.textLight,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _cachedNotes.length,
              itemBuilder: (context, index) {
                final note = _cachedNotes[index];
                final snippet = note.content.trim().isNotEmpty
                    ? note.content.replaceAll('\n', ' ')
                    : 'No additional details';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.05),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _openNoteEditor(note: note),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.description_rounded,
                                color: AppColors.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    note.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.08),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          note.subject,
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        note.date,
                                        style: const TextStyle(
                                          color: AppColors.textLight,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    snippet,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.textLight,
                                      fontSize: 13,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.redAccent,
                                size: 20,
                              ),
                              onPressed: () => _deleteNote(index),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => _showCreateNoteDialog(),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Create Note',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class NoteEditorScreen extends StatefulWidget {
  final NoteItem? note;

  const NoteEditorScreen({super.key, this.note});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _subjectController;
  late TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _subjectController =
        TextEditingController(text: widget.note?.subject ?? '');
    _contentController =
        TextEditingController(text: widget.note?.content ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  String _formatDate() => _formatCurrentDate();

  void _saveNote() {
    final rawTitle = _titleController.text.trim();
    final rawSubject = _subjectController.text.trim();
    final content = _contentController.text;

    final title = rawTitle.isEmpty ? 'Untitled Note' : rawTitle;
    final subject = rawSubject.isEmpty ? 'General' : rawSubject;

    final updated = NoteItem(
      id: widget.note?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      subject: subject,
      content: content,
      date: _formatDate(),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Note saved successfully!'),
        duration: Duration(seconds: 2),
      ),
    );

    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.note == null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isNew ? 'New Note' : 'Edit Note'),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Center(
              child: ElevatedButton.icon(
                key: const Key('save_note_button'),
                onPressed: _saveNote,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                ),
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: const Text(
                  'Save',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title Field Container
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                child: TextField(
                  key: const Key('note_title_field'),
                  controller: _titleController,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Note Title (e.g. Chapter 4 Key Concepts)',
                    hintStyle: TextStyle(
                      color: AppColors.textLight,
                      fontSize: 15,
                      fontWeight: FontWeight.normal,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Subject Field Container
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                child: TextField(
                  key: const Key('note_subject_field'),
                  controller: _subjectController,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(
                      Icons.label_outline_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    prefixIconConstraints: BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    hintText: 'Subject (e.g. Mathematics, Physics)',
                    hintStyle: TextStyle(
                      color: AppColors.textLight,
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Detailed Notes Content Area
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.05),
                    ),
                  ),
                  child: TextField(
                    key: const Key('note_content_field'),
                    controller: _contentController,
                    maxLines: null,
                    expands: true,
                    keyboardType: TextInputType.multiline,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: AppColors.textDark,
                    ),
                    decoration: const InputDecoration(
                      hintText:
                          'Write your detailed notes, lecture summaries, key equations, or revision points here...',
                      hintStyle: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
