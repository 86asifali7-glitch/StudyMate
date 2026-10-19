import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';

// ─── Design Tokens matching reference image ─────────────────────────────────
const _kBgColor      = Color(0xFFF8F9FE); // clean light background
const _kCardBg       = Color(0xFFFFFFFF); // white card surface
const _kPrimaryBlue  = Color(0xFF4765FF); // vibrant blue accent
const _kDueColor     = Color(0xFF4B69FD); // due date blue
const _kTextHead     = Color(0xFF191D31); // dark navy heading
const _kTextMuted    = Color(0xFF8C93A8); // muted subtitle text
const _kTextDone     = Color(0xFF636A80); // completed task text
const _kDeleteBg     = Color(0xFFFFF0F1); // soft reddish/coral container
const _kDeleteIcon   = Color(0xFFE56969); // coral trash icon
const _kTabBg        = Color(0xFFEFF1F9); // tab selector track
const _kTabActiveBg  = Color(0xFFE8EEFF); // active tab pill tint
const _kCardBorder   = Color(0xFFF1F3F9); // subtle card border
const _kCheckBorder  = Color(0xFFBCC2D4); // unselected checkbox border

class TaskItem {
  final String id;
  String title;
  bool isCompleted;
  String due;
  String originalDue;
  DateTime? dueDateTime;
  DateTime? reminderDateTime;

  TaskItem({
    required this.id,
    required this.title,
    required this.isCompleted,
    required this.due,
    String? originalDue,
    this.dueDateTime,
    this.reminderDateTime,
  }) : originalDue = originalDue ?? due;

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'isCompleted': isCompleted,
        'due': due,
        'originalDue': originalDue,
        if (dueDateTime != null) 'dueDateTime': dueDateTime!.toIso8601String(),
        if (reminderDateTime != null)
          'reminderDateTime': reminderDateTime!.toIso8601String(),
      };

  factory TaskItem.fromMap(Map<String, dynamic> map) => TaskItem(
        id: (map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString()).toString(),
        title: (map['title'] ?? '').toString(),
        isCompleted: map['isCompleted'] == true,
        due: (map['due'] ?? 'Pending').toString(),
        originalDue: (map['originalDue'] ?? map['due'] ?? 'Pending').toString(),
        dueDateTime: map['dueDateTime'] != null
            ? DateTime.tryParse(map['dueDateTime'].toString())
            : null,
        reminderDateTime: map['reminderDateTime'] != null
            ? DateTime.tryParse(map['reminderDateTime'].toString())
            : null,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @visibleForTesting
  static void resetForTesting() {
    _TasksScreenState.resetStaticState();
  }

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  static const String _kPrefsKey = 'studymate_saved_tasks';

  static final List<TaskItem> _defaultTasks = [
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

  static List<TaskItem> _cachedTasks = List.from(_defaultTasks);
  static bool _hasLoadedFromStorage = false;

  static void resetStaticState() {
    _hasLoadedFromStorage = false;
    _cachedTasks = [
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
  }

  // 0: All Tasks, 1: Completed
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    if (!_hasLoadedFromStorage) {
      _loadTasksFromStorage();
    }
  }

  Future<void> _loadTasksFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasSaved = (prefs.getBool('studymate_tasks_saved') ?? false) ||
          prefs.containsKey(_kPrefsKey) ||
          prefs.containsKey('studymate_tasks_json');
      if (hasSaved) {
        final rawJson = prefs.getString('studymate_tasks_json');
        List<TaskItem> loaded = [];
        if (rawJson != null) {
          try {
            final List decoded = jsonDecode(rawJson) as List;
            loaded = decoded
                .map((item) => TaskItem.fromMap(item as Map<String, dynamic>))
                .toList();
          } catch (_) {}
        } else {
          final legacyData = prefs.getStringList(_kPrefsKey);
          if (legacyData != null) {
            loaded = legacyData
                .map((item) =>
                    TaskItem.fromMap(jsonDecode(item) as Map<String, dynamic>))
                .toList();
          }
        }
        if (mounted) {
          setState(() {
            _cachedTasks = loaded;
            _hasLoadedFromStorage = true;
          });
        } else {
          _cachedTasks = loaded;
          _hasLoadedFromStorage = true;
        }
      } else {
        _hasLoadedFromStorage = true;
      }
    } catch (_) {
      _hasLoadedFromStorage = true;
    }
  }

  Future<void> _persistTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _cachedTasks.map((t) => jsonEncode(t.toMap())).toList();
      await prefs.setStringList(_kPrefsKey, jsonList);
      await prefs.setString(
        'studymate_tasks_json',
        jsonEncode(_cachedTasks.map((t) => t.toMap()).toList()),
      );
      await prefs.setBool('studymate_tasks_saved', true);
    } catch (_) {}
  }

  List<TaskItem> get _displayedTasks {
    if (_selectedTab == 1) {
      return _cachedTasks.where((task) => task.isCompleted).toList();
    }
    return _cachedTasks;
  }

  void _toggleTaskCompletion(TaskItem task) {
    setState(() {
      task.isCompleted = !task.isCompleted;
      if (task.isCompleted) {
        task.due = 'Completed';
      } else {
        task.due = task.originalDue.isNotEmpty ? task.originalDue : 'Pending';
      }
    });
    _persistTasks();
    if (task.isCompleted) {
      NotificationService.instance.cancelTaskReminder(task.id);
    } else {
      NotificationService.instance.scheduleTaskReminder(task);
    }
  }

  void _deleteTask(TaskItem task) {
    final deletedIndex = _cachedTasks.indexWhere((t) => t.id == task.id);
    if (deletedIndex == -1) return;

    setState(() {
      _cachedTasks.removeAt(deletedIndex);
    });
    _persistTasks();
    NotificationService.instance.cancelTaskReminder(task.id);

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted "${task.title}"'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'Undo',
          textColor: const Color(0xFF8298FF),
          onPressed: () {
            setState(() {
              _cachedTasks.insert(deletedIndex, task);
            });
            _persistTasks();
            if (!task.isCompleted) {
              NotificationService.instance.scheduleTaskReminder(task);
            }
          },
        ),
      ),
    );
  }

  void _showAddTaskDialog() {
    final titleController = TextEditingController();
    String selectedDue = 'Due Tomorrow';
    DateTime? selectedDateTime;
    final duePresets = ['Due Tomorrow', 'Due Friday', 'Due Sunday', 'Next Week', 'Due Today'];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: _kPrimaryBlue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.add_task_rounded,
                                color: _kPrimaryBlue, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Add New Task',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: _kTextHead,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        key: const Key('add_task_title_field'),
                        controller: titleController,
                        autofocus: true,
                        style: const TextStyle(fontSize: 14, color: _kTextHead),
                        decoration: InputDecoration(
                          hintText: 'e.g. Complete Calculus Problem Set 3',
                          hintStyle: const TextStyle(fontSize: 13, color: _kTextMuted),
                          filled: true,
                          fillColor: const Color(0xFFF8F9FE),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E6F2)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E6F2)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _kPrimaryBlue, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Due date / time',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _kTextMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ...duePresets.map((preset) {
                            final isSelected = selectedDue == preset && selectedDateTime == null;
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  setDialogState(() {
                                    selectedDue = preset;
                                    selectedDateTime = null;
                                  });
                                },
                                mouseCursor: SystemMouseCursors.click,
                                borderRadius: BorderRadius.circular(20),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isSelected ? _kPrimaryBlue : const Color(0xFFF1F3F9),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    preset,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: isSelected ? Colors.white : const Color(0xFF4B5565),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () async {
                                final now = DateTime.now();
                                final pickedDate = await showDatePicker(
                                  context: dialogCtx,
                                  initialDate: selectedDateTime ?? now,
                                  firstDate: now,
                                  lastDate: now.add(const Duration(days: 365)),
                                );
                                if (pickedDate != null && dialogCtx.mounted) {
                                  final pickedTime = await showTimePicker(
                                    context: dialogCtx,
                                    initialTime: selectedDateTime != null
                                        ? TimeOfDay(
                                            hour: selectedDateTime!.hour,
                                            minute: selectedDateTime!.minute)
                                        : TimeOfDay.now(),
                                  );
                                  if (pickedTime != null) {
                                    final dt = DateTime(
                                      pickedDate.year,
                                      pickedDate.month,
                                      pickedDate.day,
                                      pickedTime.hour,
                                      pickedTime.minute,
                                    );
                                    final period =
                                        pickedTime.period == DayPeriod.am ? 'AM' : 'PM';
                                    final h = pickedTime.hourOfPeriod == 0
                                        ? 12
                                        : pickedTime.hourOfPeriod;
                                    final m = pickedTime.minute.toString().padLeft(2, '0');
                                    final formatted =
                                        'Due ${pickedDate.month}/${pickedDate.day} at $h:$m $period';
                                    setDialogState(() {
                                      selectedDateTime = dt;
                                      selectedDue = formatted;
                                    });
                                  }
                                }
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: selectedDateTime != null
                                      ? _kPrimaryBlue
                                      : const Color(0xFFE8EEFF),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: selectedDateTime != null
                                        ? _kPrimaryBlue
                                        : const Color(0xFFB4C6FF),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.alarm_rounded,
                                      size: 14,
                                      color: selectedDateTime != null
                                          ? Colors.white
                                          : _kPrimaryBlue,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      selectedDateTime != null
                                          ? selectedDue
                                          : 'Pick Exact Time (Reminder)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: selectedDateTime != null
                                            ? Colors.white
                                            : _kPrimaryBlue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            key: const Key('dialog_create_task_button'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _kPrimaryBlue,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              final rawTitle = titleController.text.trim();
                              if (rawTitle.isNotEmpty) {
                                final newTask = TaskItem(
                                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                                  title: rawTitle,
                                  isCompleted: false,
                                  due: selectedDue,
                                  originalDue: selectedDue,
                                  dueDateTime: selectedDateTime,
                                  reminderDateTime: selectedDateTime,
                                );
                                setState(() {
                                  _cachedTasks.insert(0, newTask);
                                });
                                _persistTasks();
                                NotificationService.instance.scheduleTaskReminder(newTask);
                                Navigator.pop(ctx);
                              }
                            },
                            child: const Text(
                              'Add Task',
                              style: TextStyle(fontWeight: FontWeight.w600),
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
      },
    );
  }

  void _showOverflowMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD6DBE7),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.done_all_rounded, color: _kPrimaryBlue),
                  title: const Text('Mark all as completed'),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      for (final t in _cachedTasks) {
                        t.isCompleted = true;
                        t.due = 'Completed';
                        NotificationService.instance.cancelTaskReminder(t.id);
                      }
                    });
                    _persistTasks();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.cleaning_services_rounded, color: Color(0xFFE56969)),
                  title: const Text('Clear completed tasks'),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _cachedTasks.removeWhere((t) => t.isCompleted);
                    });
                    _persistTasks();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.restore_rounded, color: Color(0xFF4B5565)),
                  title: const Text('Reset to sample tasks'),
                  onTap: () {
                    Navigator.pop(ctx);
                    NotificationService.instance.cancelAllTaskReminders();
                    setState(() {
                      resetStaticState();
                    });
                    _persistTasks();
                  },
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
    final displayedTasks = _displayedTasks;

    return Scaffold(
      backgroundColor: _kBgColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Header ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Tasks',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: _kTextHead,
                          letterSpacing: -0.6,
                          height: 1.1,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Stay organized. Get things done.',
                        style: TextStyle(
                          fontSize: 14,
                          color: _kTextMuted,
                          fontWeight: FontWeight.w400,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
                  // Subtle circular action button with three horizontal dots
                  Tooltip(
                    message: 'More options',
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _kCardBg,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                        border: Border.all(
                          color: const Color(0xFFF0F1F6),
                          width: 1.2,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          mouseCursor: SystemMouseCursors.click,
                          onTap: _showOverflowMenu,
                          hoverColor: Colors.black.withValues(alpha: 0.05),
                          child: const Center(
                            child: Icon(
                              Icons.more_horiz_rounded,
                              color: Color(0xFF2D3142),
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // ── Tab Selector / Filter Bar ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: _kTabBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    // Tab 1: All Tasks
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: _selectedTab == 0 ? _kTabActiveBg : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            mouseCursor: SystemMouseCursors.click,
                            highlightColor: Colors.transparent,
                            splashFactory: NoSplash.splashFactory,
                            hoverColor: _selectedTab == 0
                                ? Colors.transparent
                                : Colors.black.withValues(alpha: 0.03),
                            onTap: () {
                              if (_selectedTab != 0) {
                                setState(() => _selectedTab = 0);
                              }
                            },
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.format_list_bulleted_rounded,
                                    size: 18,
                                    color: _selectedTab == 0 ? _kDueColor : const Color(0xFF6B7280),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'All Tasks',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: _selectedTab == 0 ? FontWeight.w700 : FontWeight.w500,
                                      color: _selectedTab == 0 ? _kDueColor : const Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Tab 2: Completed
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: _selectedTab == 1 ? _kTabActiveBg : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            mouseCursor: SystemMouseCursors.click,
                            highlightColor: Colors.transparent,
                            splashFactory: NoSplash.splashFactory,
                            hoverColor: _selectedTab == 1
                                ? Colors.transparent
                                : Colors.black.withValues(alpha: 0.03),
                            onTap: () {
                              if (_selectedTab != 1) {
                                setState(() => _selectedTab = 1);
                              }
                            },
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 18,
                                    color: _selectedTab == 1 ? _kDueColor : const Color(0xFF6B7280),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Completed',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: _selectedTab == 1 ? FontWeight.w700 : FontWeight.w500,
                                      color: _selectedTab == 1 ? _kDueColor : const Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            // ── Tasks List ───────────────────────────────────────────────────
            Expanded(
              child: displayedTasks.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                      physics: const BouncingScrollPhysics(),
                      itemCount: displayedTasks.length,
                      itemBuilder: (context, index) {
                        final task = displayedTasks[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _TaskCard(
                            key: ValueKey(task.id),
                            task: task,
                            onToggle: () => _toggleTaskCompletion(task),
                            onDelete: () => _deleteTask(task),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),

      // ── Floating Action Button (+) ─────────────────────────────────────────
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(right: 6, bottom: 8),
        child: Tooltip(
          message: 'Add Task',
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kPrimaryBlue,
              boxShadow: [
                BoxShadow(
                  color: _kPrimaryBlue.withValues(alpha: 0.38),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                customBorder: const CircleBorder(),
                mouseCursor: SystemMouseCursors.click,
                onTap: _showAddTaskDialog,
                hoverColor: Colors.white.withValues(alpha: 0.15),
                child: const Center(
                  child: Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isCompletedTab = _selectedTab == 1;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: _kTabBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCompletedTab ? Icons.check_circle_outline_rounded : Icons.task_alt_rounded,
                color: _kTextMuted,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isCompletedTab ? 'No completed tasks yet' : 'No tasks to do',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _kTextHead,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isCompletedTab
                  ? 'Complete your active tasks to see them here!'
                  : 'Tap the + button to add your first study task!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: _kTextMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Task Card matching the screenshot with clean, isolated hover & click ───
class _TaskCard extends StatelessWidget {
  final TaskItem task;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _TaskCard({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kCardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          mouseCursor: SystemMouseCursors.click,
          highlightColor: Colors.transparent,
          hoverColor: const Color(0xFFF6F8FF),
          splashColor: const Color(0xFFEBF0FF),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                // Left: Soft reddish/coral container with trash icon
                Tooltip(
                  message: 'Delete task',
                  child: Material(
                    color: _kDeleteBg,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      mouseCursor: SystemMouseCursors.click,
                      highlightColor: Colors.transparent,
                      hoverColor: const Color(0xFFFFD9DC),
                      splashColor: const Color(0xFFFFCCD0),
                      onTap: onDelete,
                      child: const SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: Icon(
                            Icons.delete_outline_rounded,
                            color: _kDeleteIcon,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 14),

                // Middle: Title and Due subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: task.isCompleted ? _kTextDone : _kTextHead,
                          letterSpacing: -0.2,
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: const Color(0xFF8A92A6),
                          decorationThickness: 1.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        task.isCompleted ? 'Completed' : task.due,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: task.isCompleted ? _kTextMuted : _kDueColor,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Right: Custom rounded checkbox
                Tooltip(
                  message: task.isCompleted ? 'Mark incomplete' : 'Mark complete',
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: task.isCompleted
                          ? const Color(0xFF4361EE)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: task.isCompleted
                            ? const Color(0xFF4361EE)
                            : _kCheckBorder,
                        width: 1.8,
                      ),
                    ),
                    child: task.isCompleted
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 17,
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
