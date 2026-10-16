import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Notes screen design tokens (matching reference image) ────────────────────
const _kNBg       = Color(0xFFF7F8FD); // light lavender-white background
const _kNCard     = Color(0xFFFFFFFF); // pure white card
const _kNPrimary  = Color(0xFF4854F5); // blue-violet accent
const _kNPriDark  = Color(0xFF3B46EC); // gradient stop
const _kNHead     = Color(0xFF1B1E36); // dark navy heading text
const _kNSubHead  = Color(0xFF8A92A6); // subtitle / search hint text
const _kNBody     = Color(0xFF71798E); // muted body preview text
const _kNSep      = Color(0xFFEFF1F7); // hairline separator / card border
const _kNSubject  = Color(0xFF4F5EF7); // vibrant blue subject text

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

  late TextEditingController _searchController;
  late FocusNode _searchFocusNode;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    if (!_hasLoadedFromStorage) {
      _loadNotesFromStorage();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
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
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header (Title + Count & Circular Search Icon) ─────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'My Notes',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: _kNHead,
                          letterSpacing: -0.6,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_cachedNotes.length} note${_cachedNotes.length == 1 ? '' : 's'} saved',
                        style: const TextStyle(
                          fontSize: 14,
                          color: _kNSubHead,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  // Circular search icon at top right
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _kNCard,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                      border: Border.all(color: _kNSep, width: 1),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.search_rounded,
                          size: 20, color: Color(0xFF6B7280)),
                      onPressed: () {
                        _searchFocusNode.requestFocus();
                      },
                      splashRadius: 22,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ── Wide, rounded Search Bar ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: _kNCard,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(color: _kNSep, width: 1),
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(
                    fontSize: 14,
                    color: _kNHead,
                    fontWeight: FontWeight.w400,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search notes...',
                    hintStyle: const TextStyle(
                      color: _kNSubHead,
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: _kNSubHead, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded,
                                size: 18, color: _kNSubHead),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            // ── Notes List (Vertical Stack) ──────────────────────────────────
            Expanded(
              child: notes.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      physics: const BouncingScrollPhysics(),
                      itemCount: notes.length,
                      itemBuilder: (context, index) {
                        final note = notes[index];
                        final globalIndex = _cachedNotes.indexOf(note);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _NoteCard(
                            note: note,
                            onTap: () => _openNoteEditor(note: note),
                            onDelete: () => _deleteNote(globalIndex),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),

      // ── "+ New Note" Prominent Button ────────────────────────────────────
      floatingActionButton: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _kNPrimary,
              gradient: const LinearGradient(
                colors: [Color(0xFF4B5BFA), Color(0xFF404DF2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _kNPrimary.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton(
              key: const Key('create_note_button'),
              onPressed: _showCreateNoteDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Opacity(
                    opacity: 0,
                    child: Text('Create Note', style: TextStyle(fontSize: 1)),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.add_rounded, size: 22, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        'New Note',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ],
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

// ─── Physics Motion Trail CustomPainter ───────────────────────────────────────
class _PhysicsMotionPainter extends CustomPainter {
  final Color color;
  _PhysicsMotionPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final circlePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Main particle circle at top-right
    final circleCenter = Offset(size.width * 0.72, size.height * 0.38);
    final circleRadius = size.width * 0.22;
    canvas.drawCircle(circleCenter, circleRadius, circlePaint);

    // 3 trailing speed lines to the bottom-left
    canvas.drawLine(
      Offset(size.width * 0.44, size.height * 0.58),
      Offset(size.width * 0.18, size.height * 0.78),
      strokePaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.38, size.height * 0.40),
      Offset(size.width * 0.12, size.height * 0.60),
      strokePaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.60, size.height * 0.72),
      Offset(size.width * 0.36, size.height * 0.90),
      strokePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── _NoteCard ────────────────────────────────────────────────────────────────

class _FallbackIcon {
  final Color bgColor;
  final IconData icon;
  final Color iconColor;

  const _FallbackIcon(this.bgColor, this.icon, this.iconColor);
}

class _NoteCard extends StatelessWidget {
  final NoteItem note;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _NoteCard({
    required this.note,
    required this.onTap,
    this.onDelete,
  });

  Widget _buildCircleIcon(String title, String subject) {
    final text = '${title.toLowerCase()} ${subject.toLowerCase()}';

    // Mathematics
    if (text.contains('math') ||
        text.contains('calculus') ||
        text.contains('algebra') ||
        text.contains('derivative') ||
        text.contains('integral') ||
        text.contains('geometry') ||
        text.contains('trig') ||
        text.contains('matrix') ||
        text.contains('matrices') ||
        text.contains('vector') ||
        text.contains('eigen') ||
        text.contains('statistic') ||
        text.contains('probability') ||
        text.contains('arithmetic') ||
        text.contains('equation')) {
      return Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: Color(0xFFEDE9FE), // pastel purple
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Text(
          '∫',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Color(0xFF4F46E5),
            height: 1.0,
          ),
        ),
      );
    }

    // Physics
    if (text.contains('physic') ||
        text.contains('mechanic') ||
        text.contains('motion') ||
        text.contains('newton') ||
        text.contains('gravity') ||
        text.contains('force') ||
        text.contains('velocity') ||
        text.contains('speed') ||
        text.contains('energy') ||
        text.contains('kinetic') ||
        text.contains('quantum') ||
        text.contains('optics') ||
        text.contains('thermodynamic') ||
        text.contains('astronomy') ||
        text.contains('relativity') ||
        text.contains('wave') ||
        text.contains('electric') ||
        text.contains('magnetic') ||
        text.contains('circuit')) {
      return Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: Color(0xFFE2F0FD), // pastel light blue
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: SizedBox(
          width: 22,
          height: 22,
          child: CustomPaint(
            painter: _PhysicsMotionPainter(const Color(0xFF3B82F6)),
          ),
        ),
      );
    }

    // Chemistry
    if (text.contains('chem') ||
        text.contains('organic') ||
        text.contains('inorganic') ||
        text.contains('reaction') ||
        text.contains('molecule') ||
        text.contains('atom') ||
        text.contains('acid') ||
        text.contains('base') ||
        text.contains('compound') ||
        text.contains('polymer') ||
        text.contains('titration') ||
        text.contains('periodic') ||
        text.contains('element')) {
      return Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: Color(0xFFE3F5EC), // pastel mint green
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.science_rounded,
          color: Color(0xFF229A71),
          size: 22,
        ),
      );
    }

    // Biology
    if (text.contains('bio') ||
        text.contains('cell') ||
        text.contains('genetic') ||
        text.contains('dna') ||
        text.contains('rna') ||
        text.contains('plant') ||
        text.contains('animal') ||
        text.contains('organism') ||
        text.contains('anatomy') ||
        text.contains('medicine') ||
        text.contains('ecology') ||
        text.contains('eco')) {
      return Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: Color(0xFFE8F6ED), // pastel sage
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.eco_rounded,
          color: Color(0xFF10B981),
          size: 22,
        ),
      );
    }

    // Computer Science / Coding
    if (text.contains('code') ||
        text.contains('coding') ||
        text.contains('program') ||
        text.contains('computer') ||
        text.contains('software') ||
        text.contains('developer') ||
        text.contains('java') ||
        text.contains('python') ||
        text.contains('flutter') ||
        text.contains('dart') ||
        text.contains('html') ||
        text.contains('css') ||
        text.contains('javascript') ||
        text.contains('algorithm') ||
        text.contains('data structure') ||
        text.contains('database') ||
        text.contains('sql') ||
        text.contains('ai') ||
        text.contains('machine learning')) {
      return Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: Color(0xFFE6EFFD), // pastel soft blue
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.terminal_rounded,
          color: Color(0xFF2563EB),
          size: 22,
        ),
      );
    }

    // History & Civics
    if (text.contains('hist') ||
        text.contains('history') ||
        text.contains('war') ||
        text.contains('revolution') ||
        text.contains('empire') ||
        text.contains('politic') ||
        text.contains('civic') ||
        text.contains('government') ||
        text.contains('constitution')) {
      return Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: Color(0xFFFEF2E8), // pastel peach
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.account_balance_rounded,
          color: Color(0xFFD97706),
          size: 22,
        ),
      );
    }

    // English & Literature
    if (text.contains('eng') ||
        text.contains('english') ||
        text.contains('lit') ||
        text.contains('literature') ||
        text.contains('essay') ||
        text.contains('poetry') ||
        text.contains('poem') ||
        text.contains('grammar') ||
        text.contains('novel') ||
        text.contains('book') ||
        text.contains('author') ||
        text.contains('language')) {
      return Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: Color(0xFFFFF0F5), // pastel blush
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.menu_book_rounded,
          color: Color(0xFFE11D48),
          size: 22,
        ),
      );
    }

    // Economics & Business
    if (text.contains('econ') ||
        text.contains('business') ||
        text.contains('finance') ||
        text.contains('money') ||
        text.contains('market') ||
        text.contains('trade') ||
        text.contains('accounting') ||
        text.contains('commerce')) {
      return Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: Color(0xFFE2F6F5), // pastel teal
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.trending_up_rounded,
          color: Color(0xFF0D9488),
          size: 22,
        ),
      );
    }

    // Geography & Earth
    if (text.contains('geog') ||
        text.contains('earth') ||
        text.contains('map') ||
        text.contains('climate') ||
        text.contains('geology') ||
        text.contains('ocean')) {
      return Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: Color(0xFFE0F2FE), // pastel sky
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.public_rounded,
          color: Color(0xFF0284C7),
          size: 22,
        ),
      );
    }

    // Art, Music & Design
    if (text.contains('art') ||
        text.contains('music') ||
        text.contains('design') ||
        text.contains('draw') ||
        text.contains('paint') ||
        text.contains('sketch') ||
        text.contains('song')) {
      return Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: Color(0xFFFCE7F3), // pastel rose
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.palette_rounded,
          color: Color(0xFFDB2777),
          size: 22,
        ),
      );
    }

    // Psychology & Philosophy
    if (text.contains('psych') ||
        text.contains('mind') ||
        text.contains('brain') ||
        text.contains('philosophy') ||
        text.contains('ethics')) {
      return Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: Color(0xFFF3E8FF), // pastel purple
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.psychology_rounded,
          color: Color(0xFF7C3AED),
          size: 22,
        ),
      );
    }

    // Dynamic pastel fallback based on hash so any custom note gets a unique, beautiful icon
    final hash = (title + subject).hashCode.abs();
    final fallbacks = [
      const _FallbackIcon(Color(0xFFEEF0FF), Icons.lightbulb_outline_rounded, Color(0xFF5B6CF9)),
      const _FallbackIcon(Color(0xFFE0F7FA), Icons.edit_note_rounded, Color(0xFF00ACC1)),
      const _FallbackIcon(Color(0xFFFEF9C3), Icons.bookmark_outline_rounded, Color(0xFFCA8A04)),
      const _FallbackIcon(Color(0xFFDCFCE7), Icons.checklist_rounded, Color(0xFF16A34A)),
      const _FallbackIcon(Color(0xFFF3E8FF), Icons.description_rounded, Color(0xFF9333EA)),
    ];
    final chosen = fallbacks[hash % fallbacks.length];

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: chosen.bgColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(
        chosen.icon,
        color: chosen.iconColor,
        size: 22,
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Delete Note'),
        content: Text('Are you sure you want to delete "${note.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete?.call();
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Delete',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rawContent = (note.content as dynamic)?.toString() ?? '';
    final cleanContent = rawContent.replaceAll('\n', ' ').trim();
    final snippet = cleanContent.isNotEmpty
        ? cleanContent
        : 'No content yet — tap to start writing.';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: _kNCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _kNSep,
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
            child: Row(
              children: [
                // Subject/Title Icon inside soft pastel circle
                _buildCircleIcon(note.title, note.subject),
                const SizedBox(width: 14),

                // Note Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title
                      Text(
                        (note.title as dynamic)?.toString().trim().isNotEmpty ==
                                true
                            ? note.title
                            : 'Untitled Note',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _kNHead,
                          letterSpacing: -0.2,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 3),

                      // Subject name in blue
                      Text(
                        (note.subject as dynamic)
                                    ?.toString()
                                    .trim()
                                    .isNotEmpty ==
                                true
                            ? note.subject
                            : 'General',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _kNSubject,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 5),

                      // Content preview limited to two lines
                      Text(
                        snippet,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: _kNBody,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 6),

                // Delete Button
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFF9CA3AF),
                      size: 20,
                    ),
                    splashRadius: 20,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    tooltip: 'Delete Note',
                    onPressed: () => _showDeleteDialog(context),
                  ),

                const SizedBox(width: 2),

                // Right-facing chevron arrow
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF8E95A9),
                  size: 24,
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
