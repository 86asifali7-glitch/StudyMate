import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Notes screen design tokens (mirrors Home screen palette) ─────────────────
const _kNBg       = Color(0xFFEEF0FF); // lavender page background
const _kNCard     = Color(0xFFFFFFFF); // white card
const _kNPrimary  = Color(0xFF5B6CF9); // indigo accent
const _kNPriDark  = Color(0xFF4152E8); // gradient stop
const _kNHead     = Color(0xFF1A1A2E); // heading text
const _kNBody     = Color(0xFF6B7280); // body / muted text
const _kNSep      = Color(0xFFE5E5EA); // hairline separator

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
    id: (map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString()).toString(),
    title: (map['title'] ?? 'Untitled Note').toString(),
    subject: (map['subject'] ?? 'General').toString(),
    content: (map['content'] ?? '').toString(),
    date: (map['date'] ?? 'Today').toString(),
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

  // ── search query ─────────────────────────────────────────────────────────
  String _searchQuery = '';

  List<NoteItem> get _filteredNotes {
    final query = (_searchQuery as dynamic)?.toString().trim() ?? '';
    if (query.isEmpty) return _cachedNotes;
    final q = query.toLowerCase();
    return _cachedNotes
        .where((n) =>
            (n.title as dynamic)?.toString().toLowerCase().contains(q) == true ||
            (n.subject as dynamic)?.toString().toLowerCase().contains(q) == true ||
            (n.content as dynamic)?.toString().toLowerCase().contains(q) == true)
        .toList();
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
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: _kNCard,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_kNPrimary, _kNPriDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.note_add_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'New Note',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _kNHead,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Title field
                _DialogField(
                  controller: titleController,
                  hintText: 'Title',
                  autofocus: true,
                  testKey: const Key('create_note_title_field'),
                  fontWeight: FontWeight.w600,
                ),
                const SizedBox(height: 10),
                // Subject field
                _DialogField(
                  controller: subjectController,
                  hintText: 'Subject (e.g. Mathematics)',
                  prefixIcon: Icons.label_outline_rounded,
                  testKey: const Key('create_note_subject_field'),
                ),
                const SizedBox(height: 22),
                // Actions
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        key: const Key('cancel_create_note_button'),
                        onPressed: () => Navigator.pop(dialogContext),
                        style: TextButton.styleFrom(
                          foregroundColor: _kNBody,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: _kNSep),
                          ),
                        ),
                        child: const Text('Cancel',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_kNPrimary, _kNPriDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ElevatedButton(
                          key: const Key('dialog_create_note_button'),
                          onPressed: () {
                            final rawTitle = titleController.text.trim();
                            final rawSubject = subjectController.text.trim();
                            final title =
                                rawTitle.isEmpty ? 'Untitled Note' : rawTitle;
                            final subject =
                                rawSubject.isEmpty ? 'General' : rawSubject;
                            final note = NoteItem(
                              id: DateTime.now()
                                  .millisecondsSinceEpoch
                                  .toString(),
                              title: title,
                              subject: subject,
                              content: '',
                              date: _formatCurrentDate(),
                            );
                            Navigator.pop(dialogContext, note);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Create',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14)),
                        ),
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
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
    );

    final notes = _filteredNotes;

    return Scaffold(
      backgroundColor: _kNBg,
      // ── No AppBar — custom header in body ──
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'My Notes',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: _kNHead,
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_cachedNotes.length} note${_cachedNotes.length == 1 ? '' : 's'} saved',
                    style: const TextStyle(
                      fontSize: 14,
                      color: _kNBody,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Search bar ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: _kNCard,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(
                    fontSize: 14,
                    color: _kNHead,
                    fontWeight: FontWeight.w400,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search notes…',
                    hintStyle: const TextStyle(
                      color: _kNBody,
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: _kNBody, size: 20),
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Notes list ──────────────────────────────────────────────────
            Expanded(
              child: notes.isEmpty
                  ? _buildEmptyState()
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final int crossAxisCount;
                        if (width < 340) {
                          crossAxisCount = 1;
                        } else if (width >= 960) {
                          crossAxisCount = 4;
                        } else if (width >= 640) {
                          crossAxisCount = 3;
                        } else {
                          crossAxisCount = 2; // Two columns on mobile
                        }

                        return GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                          physics: const BouncingScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            mainAxisExtent: 176,
                          ),
                          itemCount: notes.length,
                          itemBuilder: (context, index) {
                            final note = notes[index];
                            final globalIndex = _cachedNotes.indexOf(note);
                            return _NoteCard(
                              note: note,
                              onTap: () => _openNoteEditor(note: note),
                              onDelete: () => _deleteNote(globalIndex),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),

      // ── New Note button (above nav bar) ─────────────────────────────────
      floatingActionButton: Padding(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 8),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_kNPrimary, _kNPriDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _kNPrimary.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: _showCreateNoteDialog,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text(
                'New Note',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _kNPrimary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.note_alt_outlined,
                size: 38, color: _kNPrimary.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 16),
          const Text(
            'No notes yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _kNHead,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap "New Note" to capture your first idea.',
            style: TextStyle(color: _kNBody, fontSize: 14),
          ),
        ],
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

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
    );

    return Scaffold(
      backgroundColor: _kNBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Editor top bar ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _kNCard,
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.07),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 16, color: _kNHead),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isNew ? 'New Note' : 'Edit Note',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _kNHead,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  // Save button
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_kNPrimary, _kNPriDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: _kNPrimary.withValues(alpha: 0.30),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      key: const Key('save_note_button'),
                      onPressed: _saveNote,
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text(
                        'Save',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Fields ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Title
                  _EditorField(
                    controller: _titleController,
                    testKey: const Key('note_title_field'),
                    hintText: 'Note title…',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _kNHead,
                  ),
                  const SizedBox(height: 10),
                  // Subject
                  _EditorField(
                    controller: _subjectController,
                    testKey: const Key('note_subject_field'),
                    hintText: 'Subject (e.g. Mathematics)',
                    prefixIcon: Icons.label_outline_rounded,
                    color: _kNPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── Content area ──────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: _kNCard,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
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
                      height: 1.6,
                      color: _kNHead,
                    ),
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.all(16),
                      hintText:
                          'Write your notes, key equations, or revision points here…',
                      hintStyle: TextStyle(color: _kNBody, fontSize: 14),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── _NoteCard ────────────────────────────────────────────────────────────────

class _NoteCard extends StatelessWidget {
  final NoteItem note;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NoteCard({
    required this.note,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final rawContent = (note.content as dynamic)?.toString() ?? '';
    final cleanContent = rawContent.replaceAll('\n', ' ').trim();
    final snippet = cleanContent.isNotEmpty
        ? cleanContent
        : 'No additional text';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: _kNCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE5E7EB),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Note Title
                Text(
                  note.title.isNotEmpty ? note.title : 'Untitled Note',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _kNHead,
                    letterSpacing: -0.25,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 5),

                // Subject below title
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _kNPrimary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          note.subject.isNotEmpty ? note.subject : 'General',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _kNPrimary,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Note content preview
                Expanded(
                  child: Text(
                    snippet,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _kNBody.withValues(alpha: 0.9),
                      fontSize: 12.5,
                      height: 1.35,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                // Subtle date & minimal delete action
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        note.date.isNotEmpty ? note.date : 'Today',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF9CA3AF),
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 16,
                        color: Color(0xFF9CA3AF),
                      ),
                      onPressed: onDelete,
                      splashRadius: 16,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      tooltip: 'Delete note',
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

// ─── _DialogField ─────────────────────────────────────────────────────────────
// Reusable field used inside the "New Note" dialog.

class _DialogField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final Key? testKey;
  final IconData? prefixIcon;
  final bool autofocus;
  final FontWeight fontWeight;

  const _DialogField({
    required this.controller,
    required this.hintText,
    this.testKey,
    this.prefixIcon,
    this.autofocus = false,
    this.fontWeight = FontWeight.w400,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kNSep),
      ),
      child: TextField(
        key: testKey,
        controller: controller,
        autofocus: autofocus,
        style: TextStyle(
          fontSize: 14,
          fontWeight: fontWeight,
          color: _kNHead,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: _kNBody, fontSize: 14),
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, color: _kNPrimary, size: 18)
              : null,
          prefixIconConstraints:
              const BoxConstraints(minWidth: 36, minHeight: 36),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}

// ─── _EditorField ─────────────────────────────────────────────────────────────
// Reusable field used in the note editor (title / subject rows).

class _EditorField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final Key? testKey;
  final IconData? prefixIcon;
  final double fontSize;
  final FontWeight fontWeight;
  final Color color;

  const _EditorField({
    required this.controller,
    required this.hintText,
    this.testKey,
    this.prefixIcon,
    this.fontSize = 15,
    this.fontWeight = FontWeight.w400,
    this.color = _kNHead,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kNCard,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        key: testKey,
        controller: controller,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: _kNBody, fontSize: 14),
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, color: _kNPrimary, size: 18)
              : null,
          prefixIconConstraints:
              const BoxConstraints(minWidth: 44, minHeight: 44),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        ),
      ),
    );
  }
}
