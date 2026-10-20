import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/notes_screen.dart';
import '../screens/tasks_screen.dart';
import '../screens/timetable_screen.dart';

/// Centralized data persistence service for StudyMate.
/// Manages loading, saving, initialization, and default sample data seeding.
/// Guarantees that empty lists are preserved across app restarts and that
/// default sample data is seeded ONLY on genuinely fresh installations.
class AppDataService extends ChangeNotifier {
  AppDataService._internal();
  static final AppDataService instance = AppDataService._internal();

  // Storage keys matching existing schema to preserve all user data
  static const String kDataInitializedKey = 'studymate_has_initialized_data';
  static const String kNotesJsonKey       = 'studymate_notes_json';
  static const String kNotesListKey       = 'studymate_saved_notes';
  static const String kNotesSavedKey      = 'studymate_notes_saved';
  static const String kTasksJsonKey       = 'studymate_tasks_json';
  static const String kTasksListKey       = 'studymate_saved_tasks';
  static const String kTasksSavedKey      = 'studymate_tasks_saved';
  static const String kTimetableKey       = 'timetable_entries_v2';
  static const String kTimetableSavedKey  = 'studymate_timetable_saved';

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  List<NoteItem> _notes = [];
  List<TaskItem> _tasks = [];
  List<TimetableEntry> _timetableEntries = [];

  List<NoteItem> get notes => List.unmodifiable(_notes);
  List<TaskItem> get tasks => List.unmodifiable(_tasks);
  List<TimetableEntry> get timetableEntries => List.unmodifiable(_timetableEntries);

  /// Default starter notes for genuinely fresh installs
  static List<NoteItem> defaultNotes() => [
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

  /// Default starter tasks for genuinely fresh installs
  static List<TaskItem> defaultTasks() => [
    TaskItem(
      id: '1',
      title: 'Complete Calculus Problem Set 3',
      isCompleted: false,
      due: 'Due Tomorrow',
      originalDue: 'Due Tomorrow',
    ),
    TaskItem(
      id: '2',
      title: 'Read Physics Chapter 5 Summary',
      isCompleted: true,
      due: 'Completed',
      originalDue: 'Due Today',
    ),
    TaskItem(
      id: '3',
      title: 'Submit Chemistry Lab Report',
      isCompleted: false,
      due: 'Due Friday',
      originalDue: 'Due Friday',
    ),
    TaskItem(
      id: '4',
      title: 'Prepare Flashcards for History',
      isCompleted: false,
      due: 'Due Sunday',
      originalDue: 'Due Sunday',
    ),
  ];

  /// Default starter timetable classes for genuinely fresh installs
  static List<TimetableEntry> defaultTimetable() => [
    TimetableEntry(
      id: '1',
      subject: 'Calculus II',
      day: 'Mon',
      startTime: const TimeOfDay(hour: 9, minute: 0),
      endTime: const TimeOfDay(hour: 10, minute: 30),
    ),
    TimetableEntry(
      id: '2',
      subject: 'Physics Mechanics',
      day: 'Mon',
      startTime: const TimeOfDay(hour: 11, minute: 0),
      endTime: const TimeOfDay(hour: 12, minute: 30),
    ),
    TimetableEntry(
      id: '3',
      subject: 'Computer Architecture',
      day: 'Mon',
      startTime: const TimeOfDay(hour: 14, minute: 0),
      endTime: const TimeOfDay(hour: 15, minute: 30),
    ),
    TimetableEntry(
      id: '4',
      subject: 'Data Structures',
      day: 'Tue',
      startTime: const TimeOfDay(hour: 10, minute: 0),
      endTime: const TimeOfDay(hour: 11, minute: 30),
    ),
    TimetableEntry(
      id: '5',
      subject: 'Technical Writing',
      day: 'Tue',
      startTime: const TimeOfDay(hour: 13, minute: 0),
      endTime: const TimeOfDay(hour: 14, minute: 30),
    ),
    TimetableEntry(
      id: '6',
      subject: 'Calculus II',
      day: 'Wed',
      startTime: const TimeOfDay(hour: 9, minute: 0),
      endTime: const TimeOfDay(hour: 10, minute: 30),
    ),
    TimetableEntry(
      id: '7',
      subject: 'Physics Lab',
      day: 'Wed',
      startTime: const TimeOfDay(hour: 13, minute: 0),
      endTime: const TimeOfDay(hour: 15, minute: 0),
    ),
    TimetableEntry(
      id: '8',
      subject: 'Linear Algebra',
      day: 'Thu',
      startTime: const TimeOfDay(hour: 14, minute: 0),
      endTime: const TimeOfDay(hour: 15, minute: 30),
    ),
    TimetableEntry(
      id: '9',
      subject: 'Computer Architecture',
      day: 'Fri',
      startTime: const TimeOfDay(hour: 9, minute: 30),
      endTime: const TimeOfDay(hour: 11, minute: 0),
    ),
  ];

  Future<void>? _initializingFuture;
  SharedPreferences? _lastPrefs;

  /// Initialize application data before UI render.
  /// If saved data exists (even an empty list []), it is strictly honored.
  /// If it is a fresh install with no markers or keys, sample data is seeded and persisted.
  Future<void> initialize({SharedPreferences? customPrefs, bool forceReload = false}) async {
    final prefs = customPrefs ?? await SharedPreferences.getInstance();
    final bool prefsChanged = !identical(prefs, _lastPrefs);

    if (_isInitialized && !forceReload && !prefsChanged) return;
    if (_initializingFuture != null && !forceReload && !prefsChanged) {
      return _initializingFuture;
    }

    _lastPrefs = prefs;
    _initializingFuture = _doInitialize(prefs, forceReload: forceReload || prefsChanged);
    try {
      await _initializingFuture;
    } finally {
      _initializingFuture = null;
    }
  }

  Future<void> _doInitialize(SharedPreferences prefs, {bool forceReload = false}) async {
    try {
      if (forceReload) {
        try {
          await prefs.reload();
        } catch (_) {}
      }

      final bool hasInitializedMarker = prefs.getBool(kDataInitializedKey) ?? false;
      final bool hasNotesSaved = (prefs.getBool(kNotesSavedKey) ?? false) ||
          prefs.containsKey(kNotesJsonKey) ||
          prefs.containsKey(kNotesListKey);
      final bool hasTasksSaved = (prefs.getBool(kTasksSavedKey) ?? false) ||
          prefs.containsKey(kTasksJsonKey) ||
          prefs.containsKey(kTasksListKey);
      final bool hasTimetableSaved = (prefs.getBool(kTimetableSavedKey) ?? false) ||
          prefs.containsKey(kTimetableKey);

      final bool hasAnySavedData = hasInitializedMarker ||
          hasNotesSaved ||
          hasTasksSaved ||
          hasTimetableSaved;

      if (!hasAnySavedData) {
        // Genuinely fresh installation: seed default sample data
        _notes = defaultNotes();
        _tasks = defaultTasks();
        _timetableEntries = defaultTimetable();

        // Persist immediately so sample data is never re-seeded on subsequent launches
        await _persistAllInitialData(prefs);
      } else {
        // Existing installation or post-deletion: load saved data
        // Never restore default sample data if any saved data or initialized marker exists.

        // 1. Notes
        if (hasNotesSaved) {
          final rawJson = prefs.getString(kNotesJsonKey);
          if (rawJson != null) {
            try {
              final List decoded = jsonDecode(rawJson) as List;
              _notes = decoded
                  .map((item) => NoteItem.fromMap(item as Map<String, dynamic>))
                  .toList();
            } catch (_) {
              _notes = [];
            }
          } else {
            final legacyList = prefs.getStringList(kNotesListKey);
            if (legacyList != null) {
              _notes = legacyList
                  .map((item) =>
                      NoteItem.fromMap(jsonDecode(item) as Map<String, dynamic>))
                  .toList();
            } else {
              _notes = [];
            }
          }
        } else {
          _notes = [];
        }

        // 2. Tasks
        if (hasTasksSaved) {
          final rawJson = prefs.getString(kTasksJsonKey);
          if (rawJson != null) {
            try {
              final List decoded = jsonDecode(rawJson) as List;
              _tasks = decoded
                  .map((item) => TaskItem.fromMap(item as Map<String, dynamic>))
                  .toList();
            } catch (_) {
              _tasks = [];
            }
          } else {
            final legacyList = prefs.getStringList(kTasksListKey);
            if (legacyList != null) {
              _tasks = legacyList
                  .map((item) =>
                      TaskItem.fromMap(jsonDecode(item) as Map<String, dynamic>))
                  .toList();
            } else {
              _tasks = [];
            }
          }
        } else {
          _tasks = [];
        }

        // 3. Timetable
        if (hasTimetableSaved) {
          final rawJson = prefs.getString(kTimetableKey);
          if (rawJson != null) {
            try {
              final List decoded = jsonDecode(rawJson) as List;
              _timetableEntries = decoded
                  .map((e) => TimetableEntry.fromJson(e as Map<String, dynamic>))
                  .toList();
            } catch (_) {
              _timetableEntries = [];
            }
          } else {
            _timetableEntries = [];
          }
        } else {
          _timetableEntries = [];
        }

        // Establish the permanent marker and saved state flags
        await prefs.setBool(kDataInitializedKey, true);
        await prefs.setBool(kNotesSavedKey, true);
        await prefs.setBool(kTasksSavedKey, true);
        await prefs.setBool(kTimetableSavedKey, true);
      }

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('AppDataService initialize error: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> _persistAllInitialData(SharedPreferences prefs) async {
    try {
      final notesJsonList = _notes.map((n) => jsonEncode(n.toMap())).toList();
      await prefs.setStringList(kNotesListKey, notesJsonList);
      await prefs.setString(
        kNotesJsonKey,
        jsonEncode(_notes.map((n) => n.toMap()).toList()),
      );

      final tasksJsonList = _tasks.map((t) => jsonEncode(t.toMap())).toList();
      await prefs.setStringList(kTasksListKey, tasksJsonList);
      await prefs.setString(
        kTasksJsonKey,
        jsonEncode(_tasks.map((t) => t.toMap()).toList()),
      );

      await prefs.setString(
        kTimetableKey,
        jsonEncode(_timetableEntries.map((e) => e.toJson()).toList()),
      );

      await prefs.setBool(kDataInitializedKey, true);
      await prefs.setBool(kNotesSavedKey, true);
      await prefs.setBool(kTasksSavedKey, true);
      await prefs.setBool(kTimetableSavedKey, true);
    } catch (e) {
      debugPrint('Error persisting initial data: $e');
    }
  }

  /// Save notes list and persist to disk immediately.
  /// Guarantees that empty lists write explicit empty payloads and markers.
  Future<void> saveNotes(List<NoteItem> updatedNotes) async {
    _notes = List.from(updatedNotes);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kDataInitializedKey, true);
      await prefs.setBool(kNotesSavedKey, true);

      final jsonList = _notes.map((n) => jsonEncode(n.toMap())).toList();
      await prefs.setStringList(kNotesListKey, jsonList);
      await prefs.setString(
        kNotesJsonKey,
        jsonEncode(_notes.map((n) => n.toMap()).toList()),
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving notes: $e');
    }
  }

  /// Save tasks list and persist to disk immediately.
  /// Guarantees that empty lists write explicit empty payloads and markers.
  Future<void> saveTasks(List<TaskItem> updatedTasks) async {
    _tasks = List.from(updatedTasks);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kDataInitializedKey, true);
      await prefs.setBool(kTasksSavedKey, true);

      final jsonList = _tasks.map((t) => jsonEncode(t.toMap())).toList();
      await prefs.setStringList(kTasksListKey, jsonList);
      await prefs.setString(
        kTasksJsonKey,
        jsonEncode(_tasks.map((t) => t.toMap()).toList()),
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving tasks: $e');
    }
  }

  /// Save timetable entries and persist to disk immediately.
  /// Guarantees that empty lists write explicit empty payloads and markers.
  Future<void> saveTimetable(List<TimetableEntry> updatedEntries) async {
    _timetableEntries = List.from(updatedEntries);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kDataInitializedKey, true);
      await prefs.setBool(kTimetableSavedKey, true);

      await prefs.setString(
        kTimetableKey,
        jsonEncode(_timetableEntries.map((e) => e.toJson()).toList()),
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving timetable: $e');
    }
  }

  /// Helper for today's classes
  List<TimetableEntry> get todayClasses {
    final now = DateTime.now();
    final weekday = now.weekday; // 1=Mon, ..., 5=Fri
    if (weekday < 1 || weekday > 5) return [];
    final todayDay = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'][weekday - 1];
    final list = _timetableEntries
        .where((e) => e.day.toLowerCase() == todayDay.toLowerCase())
        .toList();
    list.sort((a, b) {
      final aMin = a.startTime.hour * 60 + a.startTime.minute;
      final bMin = b.startTime.hour * 60 + b.startTime.minute;
      return aMin.compareTo(bMin);
    });
    return list;
  }

  int get todayClassesCount => todayClasses.length;

  /// Reset in-memory state for testing
  void resetForTesting() {
    _isInitialized = false;
    _initializingFuture = null;
    _lastPrefs = null;
    _notes = [];
    _tasks = [];
    _timetableEntries = [];
    notifyListeners();
  }
}
