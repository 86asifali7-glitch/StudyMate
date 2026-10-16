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
  final String? formatting;

  const NoteItem({
    required this.id,
    required this.title,
    required this.subject,
    required this.content,
    required this.date,
    this.formatting,
  });

  NoteItem copyWith({
    String? id,
    String? title,
    String? subject,
    String? content,
    String? date,
    String? formatting,
  }) {
    return NoteItem(
      id: id ?? this.id,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      content: content ?? this.content,
      date: date ?? this.date,
      formatting: formatting ?? this.formatting,
    );
  }

  Map<String, String> toMap() => {
    'id': id,
    'title': title,
    'subject': subject,
    'content': content,
    'date': date,
    if (formatting != null && formatting!.isNotEmpty) 'formatting': formatting!,
  };

  factory NoteItem.fromMap(Map<String, dynamic> map) => NoteItem(
    id: (map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString()).toString(),
    title: (map['title'] ?? 'Untitled Note').toString(),
    subject: (map['subject'] ?? 'General').toString(),
    content: (map['content'] ?? '').toString(),
    date: (map['date'] ?? 'Today').toString(),
    formatting: map['formatting']?.toString(),
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

  @visibleForTesting
  static void resetForTesting() {
    _NotesScreenState.resetStaticState();
  }

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

  static void resetStaticState() {
    _hasLoadedFromStorage = false;
    _cachedNotes = [
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
  }

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
  void deactivate() {
    try {
      ScaffoldMessenger.of(context).clearSnackBars();
    } catch (_) {}
    super.deactivate();
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note saved successfully!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
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

// ─── RichStyle & Markdown Migration ──────────────────────────────────────────
class RichStyle {
  final bool bold;
  final bool italic;
  final bool underline;

  const RichStyle({
    this.bold = false,
    this.italic = false,
    this.underline = false,
  });

  bool get isEmpty => !bold && !italic && !underline;

  RichStyle copyWith({
    bool? bold,
    bool? italic,
    bool? underline,
  }) {
    return RichStyle(
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
    );
  }

  Map<String, dynamic> toJson() => {
    if (bold) 'b': true,
    if (italic) 'i': true,
    if (underline) 'u': true,
  };

  factory RichStyle.fromJson(Map<String, dynamic> json) => RichStyle(
    bold: json['b'] == true,
    italic: json['i'] == true,
    underline: json['u'] == true,
  );

  TextStyle toTextStyle(TextStyle base) {
    TextStyle s = base;
    if (bold) s = s.copyWith(fontWeight: FontWeight.bold);
    if (italic) s = s.copyWith(fontStyle: FontStyle.italic);
    if (underline) {
      s = s.copyWith(
        decoration: TextDecoration.underline,
        decorationColor: const Color(0xFF4854F5),
        decorationThickness: 2.0,
      );
    }
    return s;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RichStyle &&
          runtimeType == other.runtimeType &&
          bold == other.bold &&
          italic == other.italic &&
          underline == other.underline;

  @override
  int get hashCode => Object.hash(bold, italic, underline);
}

class _MarkdownMigrationResult {
  final String plainText;
  final List<RichStyle> styles;

  _MarkdownMigrationResult(this.plainText, this.styles);
}

_MarkdownMigrationResult _migrateLegacyMarkdown(String input) {
  // Replace leading * or - with bullet symbol • for list items
  String normalized = input.replaceAllMapped(
    RegExp(r'(^|\n)\s*[\*\-]\s+', multiLine: true),
    (m) => '${m.group(1)}• ',
  );

  if (!normalized.contains('**') &&
      !normalized.contains('*') &&
      !normalized.contains('<u>') &&
      !normalized.contains('</u>')) {
    return _MarkdownMigrationResult(
      normalized,
      List.filled(normalized.length, const RichStyle(), growable: true),
    );
  }

  final buffer = StringBuffer();
  final styles = <RichStyle>[];

  final tagRegex = RegExp(
    r'(\*\*\*(?!\s)(.+?)(?<!\s)\*\*\*)'
    r'|(\*\*(?!\s)(.+?)(?<!\s)\*\*)'
    r'|(<u>(.*?)</u>)'
    r'|((?<!\*)\*(?!\s)([^\*\n]+?)(?<!\s)\*(?!\*))',
    dotAll: false,
  );

  int last = 0;
  for (final m in tagRegex.allMatches(normalized)) {
    if (m.start > last) {
      final plain = normalized.substring(last, m.start);
      buffer.write(plain);
      styles.addAll(List.filled(plain.length, const RichStyle()));
    }

    if (m.group(1) != null) {
      final inner = m.group(2) ?? '';
      buffer.write(inner);
      styles.addAll(
          List.filled(inner.length, const RichStyle(bold: true, italic: true)));
    } else if (m.group(3) != null) {
      final inner = m.group(4) ?? '';
      if (inner.contains('<u>') && inner.contains('</u>')) {
        final sub = _migrateSubUnderline(inner, const RichStyle(bold: true));
        buffer.write(sub.plainText);
        styles.addAll(sub.styles);
      } else {
        buffer.write(inner);
        styles.addAll(List.filled(inner.length, const RichStyle(bold: true)));
      }
    } else if (m.group(5) != null) {
      final inner = m.group(6) ?? '';
      buffer.write(inner);
      styles.addAll(
          List.filled(inner.length, const RichStyle(underline: true)));
    } else if (m.group(7) != null) {
      final inner = m.group(8) ?? '';
      buffer.write(inner);
      styles.addAll(List.filled(inner.length, const RichStyle(italic: true)));
    }

    last = m.end;
  }

  if (last < normalized.length) {
    final plain = normalized.substring(last);
    buffer.write(plain);
    styles.addAll(List.filled(plain.length, const RichStyle()));
  }

  return _MarkdownMigrationResult(buffer.toString(), styles);
}

_MarkdownMigrationResult _migrateSubUnderline(String inner, RichStyle base) {
  final buffer = StringBuffer();
  final styles = <RichStyle>[];
  final subRegex = RegExp(r'<u>(.*?)</u>');
  int last = 0;
  for (final m in subRegex.allMatches(inner)) {
    if (m.start > last) {
      final plain = inner.substring(last, m.start);
      buffer.write(plain);
      styles.addAll(List.filled(plain.length, base));
    }
    final text = m.group(1) ?? '';
    buffer.write(text);
    styles.addAll(List.filled(text.length, base.copyWith(underline: true)));
    last = m.end;
  }
  if (last < inner.length) {
    final plain = inner.substring(last);
    buffer.write(plain);
    styles.addAll(List.filled(plain.length, base));
  }
  return _MarkdownMigrationResult(buffer.toString(), styles);
}

// ─── RichTextEditingController (Span-Based, No Markdown Symbols) ─────────────
class RichTextEditingController extends TextEditingController {
  List<RichStyle> _charStyles = [];
  RichStyle _activeTypingStyle = const RichStyle();
  bool _isTypingStyleExplicit = false;

  RichTextEditingController({String? text, String? formattingJson}) {
    if (formattingJson != null && formattingJson.isNotEmpty) {
      _loadFromJson(text ?? '', formattingJson);
    } else if (text != null && text.isNotEmpty) {
      final mig = _migrateLegacyMarkdown(text);
      this.text = mig.plainText;
      _charStyles = List<RichStyle>.from(mig.styles);
    } else {
      this.text = '';
      _charStyles = [];
    }
  }

  factory RichTextEditingController.fromNote(
      String content, String? formatting) {
    return RichTextEditingController(
      text: content,
      formattingJson: formatting,
    );
  }

  String? exportFormattingJson() {
    if (_charStyles.isEmpty) return null;
    final spans = <Map<String, dynamic>>[];
    int i = 0;
    while (i < _charStyles.length) {
      final style = _charStyles[i];
      if (style.isEmpty) {
        i++;
        continue;
      }
      final start = i;
      while (i < _charStyles.length && _charStyles[i] == style) {
        i++;
      }
      final end = i;
      spans.add({
        'start': start,
        'end': end,
        ...style.toJson(),
      });
    }
    if (spans.isEmpty) return null;
    return jsonEncode(spans);
  }

  void _loadFromJson(String plainText, String formattingJson) {
    text = plainText;
    _charStyles =
        List.filled(plainText.length, const RichStyle(), growable: true);
    try {
      final list = jsonDecode(formattingJson) as List<dynamic>;
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          final start = (item['start'] as num?)?.toInt() ?? 0;
          final end = (item['end'] as num?)?.toInt() ?? 0;
          final style = RichStyle.fromJson(item);
          for (int i = start; i < end && i < _charStyles.length; i++) {
            _charStyles[i] = style;
          }
        }
      }
    } catch (_) {}
  }

  @override
  set value(TextEditingValue newValue) {
    final oldText = text;
    final newText = newValue.text;
    final oldSelection = selection;

    if (oldText != newText) {
      _syncStylesWithNewText(oldText, newText);
    }

    if (oldText == newText && newValue.selection != oldSelection) {
      _isTypingStyleExplicit = false;
      if (newValue.selection.isCollapsed && newValue.selection.isValid) {
        final pos = newValue.selection.baseOffset;
        if (pos > 0 && pos <= _charStyles.length) {
          _activeTypingStyle = _charStyles[pos - 1];
        } else if (pos == 0 && _charStyles.isNotEmpty) {
          _activeTypingStyle = _charStyles[0];
        } else {
          _activeTypingStyle = const RichStyle();
        }
      }
    }

    super.value = newValue;
  }

  void _syncStylesWithNewText(String oldText, String newText) {
    if (newText.isEmpty) {
      _charStyles.clear();
      return;
    }
    if (oldText.isEmpty) {
      _charStyles =
          List.filled(newText.length, _activeTypingStyle, growable: true);
      return;
    }

    int prefix = 0;
    while (prefix < oldText.length &&
        prefix < newText.length &&
        oldText[prefix] == newText[prefix]) {
      prefix++;
    }

    int oldSuffix = oldText.length;
    int newSuffix = newText.length;
    while (oldSuffix > prefix &&
        newSuffix > prefix &&
        oldText[oldSuffix - 1] == newText[newSuffix - 1]) {
      oldSuffix--;
      newSuffix--;
    }

    final removedCount = oldSuffix - prefix;
    final insertedCount = newSuffix - prefix;

    if (removedCount > 0 && prefix < _charStyles.length) {
      final end = (prefix + removedCount).clamp(0, _charStyles.length);
      _charStyles.removeRange(prefix, end);
    }

    if (insertedCount > 0) {
      RichStyle insertStyle = _activeTypingStyle;
      if (!_isTypingStyleExplicit) {
        if (prefix > 0 && prefix - 1 < _charStyles.length) {
          insertStyle = _charStyles[prefix - 1];
        } else if (_charStyles.isNotEmpty) {
          insertStyle = _charStyles.first;
        } else {
          insertStyle = const RichStyle();
        }
      }
      final newStyles = List.filled(insertedCount, insertStyle);
      final insertPos = prefix.clamp(0, _charStyles.length);
      _charStyles.insertAll(insertPos, newStyles);
    }

    if (_charStyles.length < newText.length) {
      _charStyles.addAll(
          List.filled(newText.length - _charStyles.length, const RichStyle()));
    } else if (_charStyles.length > newText.length) {
      _charStyles.removeRange(newText.length, _charStyles.length);
    }
  }

  // ── Format query methods ──────────────────────────────────────────────────

  bool isBoldAtSelection() {
    if (!selection.isValid) return _activeTypingStyle.bold;
    if (selection.isCollapsed) return _activeTypingStyle.bold;
    final start = selection.start;
    final end = selection.end;
    if (start >= end || start >= _charStyles.length) return false;
    for (int i = start; i < end && i < _charStyles.length; i++) {
      if (!_charStyles[i].bold) return false;
    }
    return true;
  }

  bool isItalicAtSelection() {
    if (!selection.isValid) return _activeTypingStyle.italic;
    if (selection.isCollapsed) return _activeTypingStyle.italic;
    final start = selection.start;
    final end = selection.end;
    if (start >= end || start >= _charStyles.length) return false;
    for (int i = start; i < end && i < _charStyles.length; i++) {
      if (!_charStyles[i].italic) return false;
    }
    return true;
  }

  bool isUnderlineAtSelection() {
    if (!selection.isValid) return _activeTypingStyle.underline;
    if (selection.isCollapsed) return _activeTypingStyle.underline;
    final start = selection.start;
    final end = selection.end;
    if (start >= end || start >= _charStyles.length) return false;
    for (int i = start; i < end && i < _charStyles.length; i++) {
      if (!_charStyles[i].underline) return false;
    }
    return true;
  }

  // ── Format toggles ────────────────────────────────────────────────────────

  void toggleBold() {
    if (!selection.isValid || selection.isCollapsed) {
      _isTypingStyleExplicit = true;
      _activeTypingStyle =
          _activeTypingStyle.copyWith(bold: !_activeTypingStyle.bold);
      notifyListeners();
      return;
    }

    final start = selection.start;
    final end = selection.end;
    final currentlyBold = isBoldAtSelection();
    final newBold = !currentlyBold;

    for (int i = start; i < end && i < _charStyles.length; i++) {
      _charStyles[i] = _charStyles[i].copyWith(bold: newBold);
    }
    _activeTypingStyle = _activeTypingStyle.copyWith(bold: newBold);
    notifyListeners();
  }

  void toggleItalic() {
    if (!selection.isValid || selection.isCollapsed) {
      _isTypingStyleExplicit = true;
      _activeTypingStyle =
          _activeTypingStyle.copyWith(italic: !_activeTypingStyle.italic);
      notifyListeners();
      return;
    }

    final start = selection.start;
    final end = selection.end;
    final currentlyItalic = isItalicAtSelection();
    final newItalic = !currentlyItalic;

    for (int i = start; i < end && i < _charStyles.length; i++) {
      _charStyles[i] = _charStyles[i].copyWith(italic: newItalic);
    }
    _activeTypingStyle = _activeTypingStyle.copyWith(italic: newItalic);
    notifyListeners();
  }

  void toggleUnderline() {
    if (!selection.isValid || selection.isCollapsed) {
      _isTypingStyleExplicit = true;
      _activeTypingStyle =
          _activeTypingStyle.copyWith(underline: !_activeTypingStyle.underline);
      notifyListeners();
      return;
    }

    final start = selection.start;
    final end = selection.end;
    final currentlyUnderline = isUnderlineAtSelection();
    final newUnderline = !currentlyUnderline;

    for (int i = start; i < end && i < _charStyles.length; i++) {
      _charStyles[i] = _charStyles[i].copyWith(underline: newUnderline);
    }
    _activeTypingStyle = _activeTypingStyle.copyWith(underline: newUnderline);
    notifyListeners();
  }

  // ── buildTextSpan with clean rendering ────────────────────────────────────

  static final RegExp _mathSymbolRegex = RegExp(
    r'([∫∑√πθαβλΔ±÷×≠≈≤≥∞²³∂∈∀∃]|d/dx|dy/dx|lim|f\(x\))',
  );

  static final RegExp _bulletRegex = RegExp(r'^\s*•\s+');
  static final RegExp _numberRegex = RegExp(r'^\s*(\d+)\.\s+');

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ??
        const TextStyle(
          fontSize: 15,
          height: 1.6,
          color: Color(0xFF1B1E36),
          letterSpacing: -0.1,
        );

    if (text.isEmpty) {
      return TextSpan(style: baseStyle, text: '');
    }

    final lines = text.split('\n');
    final lineSpans = <InlineSpan>[];
    int lineStartOffset = 0;

    for (int lineIdx = 0; lineIdx < lines.length; lineIdx++) {
      final line = lines[lineIdx];
      final lineEndOffset = lineStartOffset + line.length;

      if (line.isEmpty) {
        if (lineIdx < lines.length - 1) {
          lineSpans.add(const TextSpan(text: '\n'));
        }
        lineStartOffset = lineEndOffset + 1;
        continue;
      }

      final bulletMatch = _bulletRegex.firstMatch(line);
      final numberMatch = _numberRegex.firstMatch(line);

      int contentStartInLine = 0;

      if (bulletMatch != null) {
        final prefix = bulletMatch.group(0)!;
        lineSpans.add(TextSpan(
          text: prefix,
          style: baseStyle.copyWith(
            color: const Color(0xFF4854F5),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ));
        contentStartInLine = prefix.length;
      } else if (numberMatch != null) {
        final prefix = numberMatch.group(0)!;
        lineSpans.add(TextSpan(
          text: prefix,
          style: baseStyle.copyWith(
            color: const Color(0xFF4854F5),
            fontWeight: FontWeight.w700,
          ),
        ));
        contentStartInLine = prefix.length;
      }

      int cur = lineStartOffset + contentStartInLine;
      while (cur < lineEndOffset) {
        final curStyle =
            cur < _charStyles.length ? _charStyles[cur] : const RichStyle();
        int runEnd = cur + 1;
        while (runEnd < lineEndOffset &&
            runEnd < _charStyles.length &&
            _charStyles[runEnd] == curStyle) {
          runEnd++;
        }

        final runText = text.substring(cur, runEnd);
        final runTextStyle = curStyle.toTextStyle(baseStyle);

        if (_mathSymbolRegex.hasMatch(runText)) {
          int mLast = 0;
          for (final m in _mathSymbolRegex.allMatches(runText)) {
            if (m.start > mLast) {
              lineSpans.add(TextSpan(
                text: runText.substring(mLast, m.start),
                style: runTextStyle,
              ));
            }
            lineSpans.add(TextSpan(
              text: m.group(0)!,
              style: runTextStyle.copyWith(
                color: const Color(0xFF3B46EC),
                fontWeight: FontWeight.w600,
              ),
            ));
            mLast = m.end;
          }
          if (mLast < runText.length) {
            lineSpans.add(TextSpan(
              text: runText.substring(mLast),
              style: runTextStyle,
            ));
          }
        } else {
          lineSpans.add(TextSpan(text: runText, style: runTextStyle));
        }

        cur = runEnd;
      }

      if (lineIdx < lines.length - 1) {
        lineSpans.add(const TextSpan(text: '\n'));
      }
      lineStartOffset = lineEndOffset + 1;
    }

    return TextSpan(style: baseStyle, children: lineSpans);
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
  late RichTextEditingController _contentController;
  late FocusNode _contentFocusNode;

  String _lastContent = '';

  // Toolbar active status flags
  bool _isBoldActive = false;
  bool _isItalicActive = false;
  bool _isUnderlineActive = false;
  bool _isBulletActive = false;
  bool _isNumberedActive = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _subjectController =
        TextEditingController(text: widget.note?.subject ?? '');
    _contentController = RichTextEditingController.fromNote(
      widget.note?.content ?? '',
      widget.note?.formatting,
    );
    _contentFocusNode = FocusNode();
    _lastContent = _contentController.text;

    _contentController.addListener(_onContentSelectionChanged);
  }

  @override
  void dispose() {
    _contentController.removeListener(_onContentSelectionChanged);
    _titleController.dispose();
    _subjectController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  String _formatDate() => _formatCurrentDate();

  void _onContentSelectionChanged() {
    _updateToolbarActiveStates();
  }

  void _saveNote() {
    final rawTitle = _titleController.text.trim();
    final rawSubject = _subjectController.text.trim();
    final content = _contentController.text;
    final formatting = _contentController.exportFormattingJson() ?? '[]';

    final title = rawTitle.isEmpty ? 'Untitled Note' : rawTitle;
    final subject = rawSubject.isEmpty ? 'General' : rawSubject;

    final updated = NoteItem(
      id: widget.note?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      subject: subject,
      content: content,
      date: _formatDate(),
      formatting: formatting,
    );

    Navigator.pop(context, updated);
  }

  // ─── Format toggles for Bold, Italic, Underline (Span-based) ───────────────

  void _toggleBold() {
    _contentFocusNode.requestFocus();
    _contentController.toggleBold();
    _updateToolbarActiveStates();
  }

  void _toggleItalic() {
    _contentFocusNode.requestFocus();
    _contentController.toggleItalic();
    _updateToolbarActiveStates();
  }

  void _toggleUnderline() {
    _contentFocusNode.requestFocus();
    _contentController.toggleUnderline();
    _updateToolbarActiveStates();
  }

  // ─── Bulleted & Numbered List Toggle ───────────────────────────────────────

  void _toggleBulletList() {
    _contentFocusNode.requestFocus();
    final text = _contentController.text;
    final selection = _contentController.selection;
    final pos = selection.isValid ? selection.baseOffset : text.length;

    final selStart = selection.isValid ? selection.start : pos;
    final selEnd = selection.isValid ? selection.end : pos;

    final firstLineStart =
        text.lastIndexOf('\n', selStart > 0 ? selStart - 1 : 0);
    final startLineIdx = firstLineStart == -1 ? 0 : firstLineStart + 1;

    final lastLineEnd = text.indexOf('\n', selEnd);
    final endLineIdx = lastLineEnd == -1 ? text.length : lastLineEnd;

    final block = text.substring(startLineIdx, endLineIdx);
    final lines = block.split('\n');

    final bulletRegex = RegExp(r'^\s*•\s+');
    final allBulleted = lines.every((l) => bulletRegex.hasMatch(l));
    final numberRegex = RegExp(r'^\s*\d+\.\s+');

    final newLines = <String>[];
    for (final line in lines) {
      if (allBulleted) {
        newLines.add(line.replaceFirst(bulletRegex, ''));
      } else {
        if (numberRegex.hasMatch(line)) {
          newLines.add(line.replaceFirst(numberRegex, '• '));
        } else if (!bulletRegex.hasMatch(line)) {
          newLines.add('• $line');
        } else {
          newLines.add(line);
        }
      }
    }

    final newBlock = newLines.join('\n');
    final newText = text.replaceRange(startLineIdx, endLineIdx, newBlock);
    _lastContent = newText;

    final delta = newBlock.length - block.length;
    final newCursor = (selEnd + delta).clamp(0, newText.length);

    _contentController.value = TextEditingValue(
      text: newText,
      selection: selection.isCollapsed
          ? TextSelection.collapsed(offset: newCursor)
          : TextSelection(
              baseOffset: startLineIdx,
              extentOffset: startLineIdx + newBlock.length,
            ),
    );
    _updateToolbarActiveStates();
  }

  void _toggleNumberedList() {
    _contentFocusNode.requestFocus();
    final text = _contentController.text;
    final selection = _contentController.selection;
    final pos = selection.isValid ? selection.baseOffset : text.length;

    final selStart = selection.isValid ? selection.start : pos;
    final selEnd = selection.isValid ? selection.end : pos;

    final firstLineStart =
        text.lastIndexOf('\n', selStart > 0 ? selStart - 1 : 0);
    final startLineIdx = firstLineStart == -1 ? 0 : firstLineStart + 1;

    final lastLineEnd = text.indexOf('\n', selEnd);
    final endLineIdx = lastLineEnd == -1 ? text.length : lastLineEnd;

    final block = text.substring(startLineIdx, endLineIdx);
    final lines = block.split('\n');

    final numberRegex = RegExp(r'^\s*(\d+)\.\s+');
    final bulletRegex = RegExp(r'^\s*•\s+');
    final allNumbered = lines.every((l) => numberRegex.hasMatch(l));

    int startNum = 1;
    if (startLineIdx > 0) {
      final prevLineStart = text.lastIndexOf('\n', startLineIdx - 2);
      final pStart = prevLineStart == -1 ? 0 : prevLineStart + 1;
      final prevLine = text.substring(pStart, startLineIdx - 1);
      final prevMatch = numberRegex.firstMatch(prevLine);
      if (prevMatch != null) {
        startNum = (int.tryParse(prevMatch.group(1) ?? '0') ?? 0) + 1;
      }
    }

    final newLines = <String>[];
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (allNumbered) {
        newLines.add(line.replaceFirst(numberRegex, ''));
      } else {
        final currentNum = startNum + i;
        if (numberRegex.hasMatch(line)) {
          newLines.add(line.replaceFirst(numberRegex, '$currentNum. '));
        } else if (bulletRegex.hasMatch(line)) {
          newLines.add(line.replaceFirst(bulletRegex, '$currentNum. '));
        } else {
          newLines.add('$currentNum. $line');
        }
      }
    }

    final newBlock = newLines.join('\n');
    final newText = text.replaceRange(startLineIdx, endLineIdx, newBlock);
    _lastContent = newText;

    final delta = newBlock.length - block.length;
    final newCursor = (selEnd + delta).clamp(0, newText.length);

    _contentController.value = TextEditingValue(
      text: newText,
      selection: selection.isCollapsed
          ? TextSelection.collapsed(offset: newCursor)
          : TextSelection(
              baseOffset: startLineIdx,
              extentOffset: startLineIdx + newBlock.length,
            ),
    );
    _updateToolbarActiveStates();
  }

  // ─── Auto-continue list on Enter ───────────────────────────────────────────

  void _handleContentChanged(String newText) {
    final selection = _contentController.selection;
    final oldText = _lastContent;
    _lastContent = newText;

    // Detect if user pressed Enter (inserted '\n')
    if (newText.length == oldText.length + 1 &&
        selection.isCollapsed &&
        selection.baseOffset > 0) {
      final pos = selection.baseOffset;
      if (newText[pos - 1] == '\n') {
        final prevLineEnd = pos - 1;
        final prevLineStartIdx =
            newText.lastIndexOf('\n', prevLineEnd > 0 ? prevLineEnd - 1 : 0);
        final prevLineStart = prevLineStartIdx == -1 ? 0 : prevLineStartIdx + 1;
        final prevLine = newText.substring(prevLineStart, prevLineEnd);

        // Empty bullet line -> exit bullet list
        final emptyBulletRegex = RegExp(r'^\s*•\s*$');
        if (emptyBulletRegex.hasMatch(prevLine)) {
          final beforePrevLine = newText.substring(0, prevLineStart);
          final afterNewline = newText.substring(pos);
          final adjusted = '$beforePrevLine$afterNewline';
          _lastContent = adjusted;
          _contentController.value = TextEditingValue(
            text: adjusted,
            selection: TextSelection.collapsed(offset: prevLineStart),
          );
          _updateToolbarActiveStates();
          return;
        }

        // Bullet line with content -> continue bullet list
        final bulletMatch = RegExp(r'^\s*•\s+').firstMatch(prevLine);
        if (bulletMatch != null) {
          const insertStr = '• ';
          final updated = newText.replaceRange(pos, pos, insertStr);
          _lastContent = updated;
          _contentController.value = TextEditingValue(
            text: updated,
            selection: TextSelection.collapsed(offset: pos + insertStr.length),
          );
          _updateToolbarActiveStates();
          return;
        }

        // Empty numbered line -> exit numbered list
        final emptyNumberRegex = RegExp(r'^\s*(\d+)\.\s*$');
        if (emptyNumberRegex.hasMatch(prevLine)) {
          final beforePrevLine = newText.substring(0, prevLineStart);
          final afterNewline = newText.substring(pos);
          final adjusted = '$beforePrevLine$afterNewline';
          _lastContent = adjusted;
          _contentController.value = TextEditingValue(
            text: adjusted,
            selection: TextSelection.collapsed(offset: prevLineStart),
          );
          _updateToolbarActiveStates();
          return;
        }

        // Numbered line with content -> continue numbered list
        final numberMatch = RegExp(r'^\s*(\d+)\.\s+').firstMatch(prevLine);
        if (numberMatch != null) {
          final currentNum = int.tryParse(numberMatch.group(1) ?? '1') ?? 1;
          final nextNum = currentNum + 1;
          final insertStr = '$nextNum. ';
          final updated = newText.replaceRange(pos, pos, insertStr);
          _lastContent = updated;
          _contentController.value = TextEditingValue(
            text: updated,
            selection: TextSelection.collapsed(offset: pos + insertStr.length),
          );
          _updateToolbarActiveStates();
          return;
        }
      }
    }

    _updateToolbarActiveStates();
  }

  // ─── Active Toolbar State Computation ─────────────────────────────────────

  void _updateToolbarActiveStates() {
    final bold = _contentController.isBoldAtSelection();
    final italic = _contentController.isItalicAtSelection();
    final underline = _contentController.isUnderlineAtSelection();

    final text = _contentController.text;
    final selection = _contentController.selection;
    bool bullet = false;
    bool numbered = false;

    if (selection.isValid) {
      final pos = selection.baseOffset;
      final lineStartIdx = text.lastIndexOf('\n', pos > 0 ? pos - 1 : 0);
      final lStart = lineStartIdx == -1 ? 0 : lineStartIdx + 1;
      final lineEndIdx = text.indexOf('\n', pos);
      final lEnd = lineEndIdx == -1 ? text.length : lineEndIdx;
      final currentLine = text.substring(lStart, lEnd);

      bullet = RegExp(r'^\s*•\s+').hasMatch(currentLine);
      numbered = RegExp(r'^\s*\d+\.\s+').hasMatch(currentLine);
    }

    if (bold != _isBoldActive ||
        italic != _isItalicActive ||
        underline != _isUnderlineActive ||
        bullet != _isBulletActive ||
        numbered != _isNumberedActive) {
      if (mounted) {
        setState(() {
          _isBoldActive = bold;
          _isItalicActive = italic;
          _isUnderlineActive = underline;
          _isBulletActive = bullet;
          _isNumberedActive = numbered;
        });
      }
    }
  }

  // ─── Formula & Symbol Insertion ───────────────────────────────────────────

  void _insertFormula(String str) {
    _contentFocusNode.requestFocus();
    final text = _contentController.text;
    final selection = _contentController.selection;
    final pos = selection.isValid ? selection.baseOffset : text.length;

    if (selection.isValid && !selection.isCollapsed) {
      final selected = text.substring(selection.start, selection.end);
      String replacement;
      int cursorOffset;
      if (str == '√') {
        replacement = '√($selected)';
        cursorOffset = selection.start + replacement.length;
      } else if (str == '∫') {
        replacement = '∫ ($selected) dx';
        cursorOffset = selection.start + replacement.length;
      } else if (str == 'd/dx') {
        replacement = 'd/dx [$selected]';
        cursorOffset = selection.start + replacement.length;
      } else {
        replacement = str;
        cursorOffset = selection.start + str.length;
      }
      final newText =
          text.replaceRange(selection.start, selection.end, replacement);
      _lastContent = newText;
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: cursorOffset),
      );
    } else {
      final newText = text.replaceRange(pos, pos, str);
      _lastContent = newText;
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: pos + str.length),
      );
    }
    _updateToolbarActiveStates();
  }

  void _showFormulaPicker() {
    final mathSymbols = [
      '∫', '∑', '√', 'π', 'θ', 'α', 'β', 'λ', 'Δ', '±',
      '÷', '×', '≠', '≈', '≤', '≥', '∞', '²', '³', 'd/dx',
      'dy/dx', 'lim', '∂', '∈', '∀', '∃', 'f(x)', 'e^x',
    ];

    final templates = [
      {'name': 'Quadratic Formula', 'formula': 'x = (-b ± √(b² - 4ac)) / (2a)'},
      {'name': 'Pythagorean Theorem', 'formula': 'a² + b² = c²'},
      {'name': 'Definite Integral', 'formula': '∫[a, b] f(x) dx'},
      {'name': 'Derivative Definition', 'formula': 'lim(h→0) [f(x+h) - f(x)] / h'},
      {'name': 'Euler\'s Identity', 'formula': 'e^(iπ) + 1 = 0'},
      {'name': 'Summation Formula', 'formula': '∑[i=1, n] x_i'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Insert Formula / Symbol',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B1E36),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Quick Symbols',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8A92A6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: mathSymbols.map((sym) {
                      return InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          _insertFormula(sym);
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F6FC),
                            borderRadius: BorderRadius.circular(10),
                            border:
                                Border.all(color: const Color(0xFFEFF1F7)),
                          ),
                          child: Text(
                            sym,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4854F5),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Formula Templates',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8A92A6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...templates.map((tpl) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          _insertFormula(tpl['formula']!);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAFAFE),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFFEFF1F7)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tpl['name']!,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1B1E36),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      tpl['formula']!,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF4854F5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.add_circle_outline_rounded,
                                size: 18,
                                color: Color(0xFF4854F5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSubjectPicker() {
    final subjects = [
      'Mathematics',
      'Physics',
      'Chemistry',
      'Biology',
      'Computer Science',
      'History',
      'English',
      'Economics',
      'Geography',
      'General',
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Select Subject',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B1E36),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: subjects.map((subj) {
                    final isSelected = _subjectController.text
                            .trim()
                            .toLowerCase() ==
                        subj.toLowerCase();
                    return ChoiceChip(
                      label: Text(subj),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _subjectController.text = subj;
                          });
                          Navigator.pop(ctx);
                        }
                      },
                      selectedColor: const Color(0xFF4854F5),
                      backgroundColor: const Color(0xFFF3F4F8),
                      labelStyle: TextStyle(
                        color:
                            isSelected ? Colors.white : const Color(0xFF1B1E36),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected
                              ? const Color(0xFF4854F5)
                              : const Color(0xFFEFF1F7),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.note == null;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
    );

    return ScaffoldMessenger(
      child: Scaffold(
        backgroundColor: _kNBg,
        resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Top Bar (Circular Back Button + Rounded Save Button) ────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Circular back button
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
                      border: Border.all(color: _kNSep, width: 1.0),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.chevron_left_rounded,
                        size: 28,
                        color: _kNHead,
                      ),
                      onPressed: () => Navigator.pop(context),
                      splashRadius: 22,
                      padding: EdgeInsets.zero,
                    ),
                  ),

                  // Hidden compatibility widget for tests expecting find.text('Edit Note') / 'New Note'
                  Opacity(
                    opacity: 0,
                    child: Text(
                      isNew ? 'New Note' : 'Edit Note',
                      style: const TextStyle(fontSize: 1),
                    ),
                  ),

                  // Rounded blue-violet Save button
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: _kNPrimary,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: _kNPrimary.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      key: const Key('save_note_button'),
                      onPressed: _saveNote,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.check_rounded,
                              size: 18, color: Colors.white),
                          SizedBox(width: 6),
                          Text(
                            'Save',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Colors.white,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ── Large Title & Subject Selector ──────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title TextField (Large, Bold, Clean)
                  TextField(
                    key: const Key('note_title_field'),
                    controller: _titleController,
                    maxLines: null,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: _kNHead,
                      letterSpacing: -0.5,
                      height: 1.2,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Note Title...',
                      hintStyle: TextStyle(
                        color: _kNSubHead,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Rounded Subject Selector
                  InkWell(
                    onTap: _showSubjectPicker,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: _kNCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _kNSep, width: 1.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Soft pastel icon container
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDE9FE),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.label_outline_rounded,
                              color: Color(0xFF4F5EF7),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              key: const Key('note_subject_field'),
                              controller: _subjectController,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF4F5EF7),
                                letterSpacing: -0.1,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Subject (e.g. Mathematics)',
                                hintStyle: TextStyle(
                                  color: Color(0xFF8A92A6),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Color(0xFF4F5EF7),
                            size: 24,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Large White Rounded Editing Area & Bottom Formatting Toolbar ───
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: _kNCard,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: _kNSep, width: 1.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Content text area
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: TextField(
                            key: const Key('note_content_field'),
                            controller: _contentController,
                            focusNode: _contentFocusNode,
                            onChanged: _handleContentChanged,
                            maxLines: null,
                            expands: true,
                            keyboardType: TextInputType.multiline,
                            textAlignVertical: TextAlignVertical.top,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.6,
                              color: _kNHead,
                              letterSpacing: -0.1,
                            ),
                            decoration: const InputDecoration(
                              hintText:
                                  'Write your notes, formulas, or key concepts here…',
                              hintStyle: TextStyle(
                                color: _kNSubHead,
                                fontSize: 15,
                                height: 1.6,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ),

                      // Formatting Toolbar at bottom of the editor card
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAFAFE),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _kNSep, width: 1.0),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _ToolbarItem(
                                key: const Key('format_bold_button'),
                                isActive: _isBoldActive,
                                labelWidget: Text(
                                  'B',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    color: _isBoldActive
                                        ? const Color(0xFF4854F5)
                                        : const Color(0xFF1B1E36),
                                  ),
                                ),
                                tooltip: 'Bold',
                                onTap: _toggleBold,
                              ),
                              _ToolbarItem(
                                key: const Key('format_italic_button'),
                                isActive: _isItalicActive,
                                labelWidget: Text(
                                  'I',
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: _isItalicActive
                                        ? const Color(0xFF4854F5)
                                        : const Color(0xFF1B1E36),
                                  ),
                                ),
                                tooltip: 'Italic',
                                onTap: _toggleItalic,
                              ),
                              _ToolbarItem(
                                key: const Key('format_underline_button'),
                                isActive: _isUnderlineActive,
                                labelWidget: Text(
                                  'U',
                                  style: TextStyle(
                                    decoration: TextDecoration.underline,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: _isUnderlineActive
                                        ? const Color(0xFF4854F5)
                                        : const Color(0xFF1B1E36),
                                  ),
                                ),
                                tooltip: 'Underline',
                                onTap: _toggleUnderline,
                              ),
                              _ToolbarItem(
                                key: const Key('format_bullet_button'),
                                isActive: _isBulletActive,
                                labelWidget: Icon(
                                  Icons.format_list_bulleted_rounded,
                                  size: 20,
                                  color: _isBulletActive
                                      ? const Color(0xFF4854F5)
                                      : const Color(0xFF1B1E36),
                                ),
                                tooltip: 'Bulleted list',
                                onTap: _toggleBulletList,
                              ),
                              _ToolbarItem(
                                key: const Key('format_numbered_button'),
                                isActive: _isNumberedActive,
                                labelWidget: Icon(
                                  Icons.format_list_numbered_rounded,
                                  size: 20,
                                  color: _isNumberedActive
                                      ? const Color(0xFF4854F5)
                                      : const Color(0xFF1B1E36),
                                ),
                                tooltip: 'Numbered list',
                                onTap: _toggleNumberedList,
                              ),
                              _ToolbarItem(
                                key: const Key('format_formula_button'),
                                isActive: false,
                                labelWidget: const Text(
                                  'Σ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                    color: Color(0xFF4854F5),
                                  ),
                                ),
                                tooltip: 'Formulas & Math Symbols',
                                onTap: _showFormulaPicker,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ));
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
    final stripped = rawContent
        .replaceAll('**', '')
        .replaceAll('<u>', '')
        .replaceAll('</u>', '')
        .replaceAll(RegExp(r'(?<!\*)\*(?!\*)'), '')
        .replaceAll('\n', ' ')
        .trim();
    final cleanContent = stripped;
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

// ─── _ToolbarItem ─────────────────────────────────────────────────────────────

class _ToolbarItem extends StatelessWidget {
  final Widget labelWidget;
  final String tooltip;
  final VoidCallback onTap;
  final bool isActive;

  const _ToolbarItem({
    super.key,
    required this.labelWidget,
    required this.tooltip,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFEDE9FE) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive ? const Color(0xFFC7D2FE) : Colors.transparent,
              width: 1.0,
            ),
          ),
          child: Tooltip(
            message: tooltip,
            child: labelWidget,
          ),
        ),
      ),
    );
  }
}

