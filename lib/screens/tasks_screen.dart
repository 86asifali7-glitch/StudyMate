import 'dart:async';
import 'package:flutter/material.dart';
import '../services/app_data_service.dart';
import '../services/notification_service.dart';
import '../services/sound_service.dart';

// ─── Design Tokens matching reference image ─────────────────────────────────
const _kBgColor       = Color(0xFFFFFFFF); // clean white background
const _kCardBg        = Color(0xFFFFFFFF); // white card surface
const _kPrimaryBlue   = Color(0xFF2563EB); // vibrant primary blue #2563EB
const _kPrimaryLight  = Color(0xFFEFF6FF); // light blue tint #EFF6FF
const _kTextHead      = Color(0xFF1E293B); // dark slate heading #1E293B
const _kTextMuted     = Color(0xFF64748B); // muted secondary text #64748B
const _kTextDone      = Color(0xFF94A3B8); // completed strike text #94A3B8
const _kCardBorder    = Color(0xFFE2E8F0); // subtle border #E2E8F0

/// Supported filter options matching the reference design
enum TaskFilter { all, today, upcoming, completed }

class TaskItem {
  final String id;
  String title;
  bool isCompleted;
  String due;
  String originalDue;
  DateTime? dueDateTime;
  DateTime? reminderDateTime;
  String? priority;

  TaskItem({
    required this.id,
    required this.title,
    required this.isCompleted,
    required this.due,
    String? originalDue,
    this.dueDateTime,
    this.reminderDateTime,
    String? priority,
  })  : originalDue = originalDue ?? due,
        priority = priority ?? (title == 'Complete Calculus Problem Set 3' ? 'High' : null);

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'isCompleted': isCompleted,
        'due': due,
        'originalDue': originalDue,
        if (dueDateTime != null) 'dueDateTime': dueDateTime!.toIso8601String(),
        if (reminderDateTime != null)
          'reminderDateTime': reminderDateTime!.toIso8601String(),
        if (priority != null && priority!.isNotEmpty) 'priority': priority,
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
        priority: map['priority']?.toString(),
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
  static List<TaskItem> _cachedTasks = List.from(AppDataService.instance.tasks);

  static void resetStaticState() {
    AppDataService.instance.resetForTesting();
    _cachedTasks = [];
  }

  TaskFilter _selectedFilter = TaskFilter.all;

  // Track task IDs that were recently toggled so they visibly check/uncheck in-place
  // before smoothly moving in the list order.
  final Set<String> _recentlyToggledTaskIds = {};
  Timer? _reorderTimer;

  @override
  void initState() {
    super.initState();
    AppDataService.instance.addListener(_onAppDataChanged);
    _cachedTasks = List.from(AppDataService.instance.tasks);
    if (!AppDataService.instance.isInitialized) {
      _loadTasksFromStorage();
    }
  }

  void _onAppDataChanged() {
    if (!mounted) return;
    setState(() {
      _cachedTasks = List.from(AppDataService.instance.tasks);
    });
  }

  @override
  void dispose() {
    _reorderTimer?.cancel();
    AppDataService.instance.removeListener(_onAppDataChanged);
    super.dispose();
  }

  Future<void> _loadTasksFromStorage() async {
    try {
      await AppDataService.instance.initialize();
      if (mounted) {
        setState(() {
          _cachedTasks = List<TaskItem>.from(AppDataService.instance.tasks);
        });
      } else {
        _cachedTasks = List<TaskItem>.from(AppDataService.instance.tasks);
      }
    } catch (_) {}
  }

  Future<void> _persistTasks() async {
    await AppDataService.instance.saveTasks(_cachedTasks);
  }

  // ─── Due Date & Filtering Helpers ──────────────────────────────────────────

  DateTime _getEffectiveDueDate(TaskItem task) {
    if (task.dueDateTime != null) {
      return task.dueDateTime!;
    }
    final dueLower = (task.originalDue.isNotEmpty ? task.originalDue : task.due).toLowerCase();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (dueLower.contains('today')) {
      return today.add(const Duration(hours: 23, minutes: 59));
    }
    if (dueLower.contains('tomorrow')) {
      return today.add(const Duration(days: 1, hours: 23, minutes: 59));
    }
    const days = {
      'monday': DateTime.monday,
      'tuesday': DateTime.tuesday,
      'wednesday': DateTime.wednesday,
      'thursday': DateTime.thursday,
      'friday': DateTime.friday,
      'saturday': DateTime.saturday,
      'sunday': DateTime.sunday,
    };
    for (final entry in days.entries) {
      if (dueLower.contains(entry.key)) {
        int daysUntil = (entry.value - now.weekday + 7) % 7;
        if (daysUntil == 0) daysUntil = 7;
        return today.add(Duration(days: daysUntil, hours: 23, minutes: 59));
      }
    }
    if (dueLower.contains('next week')) {
      return today.add(const Duration(days: 7, hours: 23, minutes: 59));
    }
    final match = RegExp(r'(\d{1,2})/(\d{1,2})').firstMatch(dueLower);
    if (match != null) {
      final m = int.tryParse(match.group(1)!);
      final d = int.tryParse(match.group(2)!);
      if (m != null && d != null) {
        return DateTime(now.year, m, d, 23, 59);
      }
    }
    // No due date or pending: place at bottom of chronological list
    return today.add(const Duration(days: 365));
  }

  bool _isDueToday(TaskItem task) {
    if (task.dueDateTime != null) {
      final now = DateTime.now();
      final dt = task.dueDateTime!;
      return dt.year == now.year && dt.month == now.month && dt.day == now.day;
    }
    final dueLower = (task.originalDue.isNotEmpty ? task.originalDue : task.due).toLowerCase();
    return dueLower.contains('today');
  }

  bool _isUpcoming(TaskItem task) {
    if (task.dueDateTime != null) {
      final now = DateTime.now();
      final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
      return task.dueDateTime!.isAfter(endOfToday);
    }
    final dueLower = (task.originalDue.isNotEmpty ? task.originalDue : task.due).toLowerCase();
    if (dueLower.contains('today') || dueLower.contains('completed')) {
      return false;
    }
    if (dueLower.contains('tomorrow') ||
        dueLower.contains('friday') ||
        dueLower.contains('sunday') ||
        dueLower.contains('monday') ||
        dueLower.contains('tuesday') ||
        dueLower.contains('wednesday') ||
        dueLower.contains('thursday') ||
        dueLower.contains('saturday') ||
        dueLower.contains('next week')) {
      return true;
    }
    final match = RegExp(r'(\d{1,2})/(\d{1,2})').firstMatch(dueLower);
    if (match != null) {
      final now = DateTime.now();
      final m = int.tryParse(match.group(1)!);
      final d = int.tryParse(match.group(2)!);
      if (m != null && d != null) {
        final taskDate = DateTime(now.year, m, d, 23, 59);
        return taskDate.isAfter(DateTime(now.year, now.month, now.day, 23, 59));
      }
    }
    return dueLower.contains('pending');
  }

  List<TaskItem> get _displayedTasks {
    List<TaskItem> list;
    switch (_selectedFilter) {
      case TaskFilter.today:
        list = _cachedTasks.where((t) {
          if (_recentlyToggledTaskIds.contains(t.id)) return true;
          return _isDueToday(t);
        }).toList();
        break;
      case TaskFilter.upcoming:
        list = _cachedTasks.where((t) {
          if (_recentlyToggledTaskIds.contains(t.id)) return true;
          return !t.isCompleted && _isUpcoming(t);
        }).toList();
        break;
      case TaskFilter.completed:
        list = _cachedTasks.where((t) {
          if (_recentlyToggledTaskIds.contains(t.id)) return true;
          return t.isCompleted;
        }).toList();
        break;
      case TaskFilter.all:
        list = List<TaskItem>.from(_cachedTasks);
        break;
    }

    // Sort: Incomplete tasks first ordered by nearest due date, followed by completed tasks.
    // For tasks in _recentlyToggledTaskIds, we preserve their previous sorting state
    // temporarily so the tick is clearly visible right under the user's touch.
    list.sort((a, b) {
      final aCompletedSort = _recentlyToggledTaskIds.contains(a.id) ? !a.isCompleted : a.isCompleted;
      final bCompletedSort = _recentlyToggledTaskIds.contains(b.id) ? !b.isCompleted : b.isCompleted;

      if (aCompletedSort != bCompletedSort) {
        return aCompletedSort ? 1 : -1;
      }
      return _getEffectiveDueDate(a).compareTo(_getEffectiveDueDate(b));
    });

    return list;
  }

  String _formatDueSubtitle(TaskItem task) {
    if (task.isCompleted) {
      return 'Completed';
    }
    if (task.dueDateTime != null) {
      final dt = task.dueDateTime!;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final taskDay = DateTime(dt.year, dt.month, dt.day);

      final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      final timeStr = '$hour:$minute $period';

      if (taskDay == today) {
        return 'Due Today  •  $timeStr';
      } else if (taskDay == today.add(const Duration(days: 1))) {
        return 'Due Tomorrow  •  $timeStr';
      } else {
        const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
        final day = weekdays[dt.weekday - 1];
        return 'Due $day  •  $timeStr';
      }
    }
    return task.due.isNotEmpty ? task.due : (task.originalDue.isNotEmpty ? task.originalDue : 'Pending');
  }

  // ─── Actions ───────────────────────────────────────────────────────────────

  Future<void> _toggleTaskCompletion(TaskItem task) async {
    // Identify task by unique ID
    final targetIndex = _cachedTasks.indexWhere((t) => t.id == task.id);
    if (targetIndex == -1) return;
    final targetTask = _cachedTasks[targetIndex];

    // 1. Immediately toggle completion and update due status
    targetTask.isCompleted = !targetTask.isCompleted;
    if (targetTask.isCompleted) {
      targetTask.due = 'Completed';
    } else {
      targetTask.due = targetTask.originalDue.isNotEmpty ? targetTask.originalDue : 'Pending';
    }

    // 2. Mark this task ID as recently toggled so it retains its visual list position
    // temporarily, showing the checkmark on the exact task tapped before moving.
    _recentlyToggledTaskIds.add(targetTask.id);

    // Immediate visual update: checkbox ticks right at the tapped location
    setState(() {});

    // 3. Immediately persist updated data and handle sound/notifications
    await _persistTasks();
    if (targetTask.isCompleted) {
      NotificationService.instance.cancelTaskReminder(targetTask.id);
      SoundService.instance.playTaskDone();
    } else {
      NotificationService.instance.scheduleTaskReminder(targetTask);
    }

    // 4. After 400ms delay, smooth reordering moves completed tasks to bottom
    _reorderTimer?.cancel();
    _reorderTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          _recentlyToggledTaskIds.clear();
        });
      }
    });
  }

  Future<void> _deleteTask(TaskItem task) async {
    final deletedIndex = _cachedTasks.indexWhere((t) => t.id == task.id);
    if (deletedIndex == -1) return;

    setState(() {
      _cachedTasks.removeAt(deletedIndex);
      _recentlyToggledTaskIds.remove(task.id);
    });
    await _persistTasks();
    NotificationService.instance.cancelTaskReminder(task.id);

    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted "${task.title}"'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'Undo',
          textColor: const Color(0xFF8298FF),
          onPressed: () async {
            setState(() {
              _cachedTasks.insert(deletedIndex, task);
            });
            await _persistTasks();
            if (!task.isCompleted) {
              NotificationService.instance.scheduleTaskReminder(task);
            }
          },
        ),
      ),
    );
  }

  void _showTaskMenu(TaskItem task) {
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
                  leading: Icon(
                    task.isCompleted
                        ? Icons.radio_button_unchecked_rounded
                        : Icons.check_circle_outline_rounded,
                    color: _kPrimaryBlue,
                  ),
                  title: Text(task.isCompleted ? 'Mark as incomplete' : 'Mark as complete'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _toggleTaskCompletion(task);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.edit_outlined, color: _kTextHead),
                  title: const Text('Edit task'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showEditTaskDialog(task);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                  title: const Text('Delete task', style: TextStyle(color: Color(0xFFEF4444))),
                  onTap: () {
                    Navigator.pop(ctx);
                    _deleteTask(task);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditTaskDialog(TaskItem task) {
    final titleController = TextEditingController(text: task.title);
    String selectedDue = task.originalDue.isNotEmpty ? task.originalDue : task.due;
    DateTime? selectedDateTime = task.dueDateTime;
    String? selectedPriority = task.priority;
    final duePresets = ['Due Tomorrow', 'Due Friday', 'Due Sunday', 'Next Week', 'Due Today'];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                            child: const Icon(Icons.edit_note_rounded, color: _kPrimaryBlue, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Edit Task',
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
                        controller: titleController,
                        style: const TextStyle(fontSize: 14, color: _kTextHead),
                        decoration: InputDecoration(
                          hintText: 'Task Title',
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
                        'Priority',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kTextMuted),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: ['None', 'Low', 'Medium', 'High'].map((p) {
                          final isSel = (p == 'None' && selectedPriority == null) || (selectedPriority == p);
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                setDialogState(() {
                                  selectedPriority = p == 'None' ? null : p;
                                });
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSel ? _kPrimaryBlue : const Color(0xFFF1F3F9),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  p,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isSel ? Colors.white : const Color(0xFF4B5565),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Due date / time',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kTextMuted),
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
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
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
                        ],
                      ),
                      const SizedBox(height: 22),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _kPrimaryBlue,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () async {
                              final text = titleController.text.trim();
                              if (text.isNotEmpty) {
                                setState(() {
                                  task.title = text;
                                  task.due = selectedDue;
                                  task.originalDue = selectedDue;
                                  task.dueDateTime = selectedDateTime;
                                  task.priority = selectedPriority;
                                });
                                await _persistTasks();
                                if (ctx.mounted) Navigator.pop(ctx);
                              }
                            },
                            child: const Text('Save Changes'),
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

  void _showAddTaskDialog() {
    final titleController = TextEditingController();
    String selectedDue = 'Due Tomorrow';
    DateTime? selectedDateTime;
    String? selectedPriority;
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
                        'Priority (Optional)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _kTextMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: ['None', 'Low', 'Medium', 'High'].map((p) {
                          final isSel = (p == 'None' && selectedPriority == null) || (selectedPriority == p);
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                setDialogState(() {
                                  selectedPriority = p == 'None' ? null : p;
                                });
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSel ? _kPrimaryBlue : const Color(0xFFF1F3F9),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  p,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isSel ? Colors.white : const Color(0xFF4B5565),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
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
                            onPressed: () async {
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
                                  priority: selectedPriority,
                                );
                                setState(() {
                                  _cachedTasks.insert(0, newTask);
                                });
                                await _persistTasks();
                                NotificationService.instance.scheduleTaskReminder(newTask);
                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                }
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
                  onTap: () async {
                    Navigator.pop(ctx);
                    setState(() {
                      for (final t in _cachedTasks) {
                        t.isCompleted = true;
                        t.due = 'Completed';
                        NotificationService.instance.cancelTaskReminder(t.id);
                      }
                    });
                    await _persistTasks();
                    SoundService.instance.playTaskDone();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.cleaning_services_rounded, color: Color(0xFFE56969)),
                  title: const Text('Clear completed tasks'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    setState(() {
                      _cachedTasks.removeWhere((t) => t.isCompleted);
                    });
                    await _persistTasks();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.restore_rounded, color: Color(0xFF4B5565)),
                  title: const Text('Reset to sample tasks'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    NotificationService.instance.cancelAllTaskReminders();
                    setState(() {
                      _cachedTasks = AppDataService.defaultTasks();
                    });
                    await _persistTasks();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── UI Components ─────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'My Tasks',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: _kTextHead,
                    letterSpacing: -0.6,
                    height: 1.15,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Stay focused, one task at a time.',
                  style: TextStyle(
                    fontSize: 14,
                    color: _kTextMuted,
                    fontWeight: FontWeight.w400,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
          Tooltip(
            message: 'More options',
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _kCardBg,
                shape: BoxShape.circle,
                border: Border.all(
                  color: _kCardBorder,
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  mouseCursor: SystemMouseCursors.click,
                  onTap: _showOverflowMenu,
                  child: const Center(
                    child: Icon(
                      Icons.more_horiz_rounded,
                      color: Color(0xFF334155),
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    final total = _cachedTasks.length;
    final completed = _cachedTasks.where((t) => t.isCompleted).length;
    final percent = total > 0 ? ((completed / total) * 100).round() : 0;
    final progressFraction = total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kPrimaryLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFDBEAFE),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0xFFDBEAFE),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.check_circle_outline_rounded,
                    color: _kPrimaryBlue,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your progress',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _kTextMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$completed of $total completed',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _kTextHead,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '$percent%',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _kPrimaryBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 7,
              child: LinearProgressIndicator(
                value: progressFraction,
                backgroundColor: const Color(0xFFDBEAFE),
                valueColor: const AlwaysStoppedAnimation<Color>(_kPrimaryBlue),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kCardBorder, width: 1.2),
      ),
      padding: const EdgeInsets.all(5),
      child: Row(
        children: [
          Expanded(
            child: _buildFilterTab(
              filter: TaskFilter.all,
              label: 'All',
              icon: Icons.grid_view_rounded,
            ),
          ),
          _buildFilterDivider(TaskFilter.all, TaskFilter.today),
          Expanded(
            child: _buildFilterTab(
              filter: TaskFilter.today,
              label: 'Today',
              icon: Icons.calendar_today_outlined,
            ),
          ),
          _buildFilterDivider(TaskFilter.today, TaskFilter.upcoming),
          Expanded(
            child: _buildFilterTab(
              filter: TaskFilter.upcoming,
              label: 'Upcoming',
              icon: Icons.access_time_rounded,
            ),
          ),
          _buildFilterDivider(TaskFilter.upcoming, TaskFilter.completed),
          Expanded(
            child: _buildFilterTab(
              filter: TaskFilter.completed,
              label: 'Completed',
              icon: Icons.check_circle_outline_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDivider(TaskFilter left, TaskFilter right) {
    final hideDivider = _selectedFilter == left || _selectedFilter == right;
    return Container(
      width: 1,
      height: 22,
      color: hideDivider ? Colors.transparent : _kCardBorder,
    );
  }

  Widget _buildFilterTab({
    required TaskFilter filter,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedFilter == filter;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Material(
        key: ValueKey('filter_tab_${filter.name}'),
        color: isSelected ? _kPrimaryLight : Colors.transparent,
        child: InkWell(
          onTap: () {
            if (_selectedFilter != filter) {
              setState(() => _selectedFilter = filter);
            }
          },
          borderRadius: BorderRadius.circular(12),
          splashColor: _kPrimaryBlue.withValues(alpha: 0.10),
          highlightColor: Colors.transparent,
          hoverColor: isSelected ? Colors.transparent : Colors.black.withValues(alpha: 0.02),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 19,
                  color: isSelected ? _kPrimaryBlue : _kTextMuted,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? _kPrimaryBlue : _kTextMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader() {
    String sectionTitle;
    switch (_selectedFilter) {
      case TaskFilter.today:
        sectionTitle = 'Today';
        break;
      case TaskFilter.completed:
        sectionTitle = 'Completed';
        break;
      case TaskFilter.upcoming:
      case TaskFilter.all:
        sectionTitle = 'Due soon';
        break;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          sectionTitle,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _kTextHead,
            letterSpacing: -0.3,
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (_selectedFilter != TaskFilter.all) {
              setState(() => _selectedFilter = TaskFilter.all);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'View all',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _kPrimaryBlue,
                  ),
                ),
                SizedBox(width: 2),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: _kPrimaryBlue,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    IconData icon;
    String title;
    String subtitle;

    switch (_selectedFilter) {
      case TaskFilter.today:
        icon = Icons.calendar_today_rounded;
        title = 'No tasks due today';
        subtitle = "You're all caught up for today!";
        break;
      case TaskFilter.upcoming:
        icon = Icons.access_time_rounded;
        title = 'No upcoming tasks';
        subtitle = 'Plan ahead by scheduling tasks for the week.';
        break;
      case TaskFilter.completed:
        icon = Icons.check_circle_outline_rounded;
        title = 'No completed tasks yet';
        subtitle = 'Complete your active tasks to see them here!';
        break;
      case TaskFilter.all:
        icon = Icons.task_alt_rounded;
        title = 'No tasks to do';
        subtitle = 'Tap the + button to add your first study task!';
        break;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: _kTextMuted,
                size: 30,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _kTextHead,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
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
            _buildHeader(),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
                children: [
                  _buildProgressCard(),
                  const SizedBox(height: 16),
                  _buildFilterBar(),
                  const SizedBox(height: 22),
                  _buildSectionHeader(),
                  const SizedBox(height: 12),
                  if (displayedTasks.isEmpty)
                    _buildEmptyState()
                  else
                    ...displayedTasks.map((task) {
                      return Padding(
                        key: ValueKey('task_item_${task.id}'),
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _TaskCard(
                          key: ValueKey('task_card_${task.id}'),
                          task: task,
                          formattedDue: _formatDueSubtitle(task),
                          onToggle: () => _toggleTaskCompletion(task),
                          onMenuTap: () => _showTaskMenu(task),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),

      // ── Floating Action Button (+) matching reference ───────────────────────
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
}

// ─── Task Card matching the screenshot with clean, isolated hover & click ───
class _TaskCard extends StatelessWidget {
  final TaskItem task;
  final String formattedDue;
  final VoidCallback onToggle;
  final VoidCallback onMenuTap;

  const _TaskCard({
    super.key,
    required this.task,
    required this.formattedDue,
    required this.onToggle,
    required this.onMenuTap,
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
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
          hoverColor: const Color(0xFFF8FAFC),
          splashColor: const Color(0xFFEFF6FF),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Checkbox: rounded rectangle with blue border and immediate checkmark
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onToggle,
                  child: AnimatedContainer(
                    key: ValueKey('task_checkbox_${task.id}'),
                    duration: const Duration(milliseconds: 150),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: task.isCompleted ? _kPrimaryBlue : Colors.white,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: _kPrimaryBlue,
                        width: 1.8,
                      ),
                    ),
                    child: task.isCompleted
                        ? const Icon(
                            Icons.check_rounded,
                            key: ValueKey('icon_checked'),
                            color: Colors.white,
                            size: 16,
                          )
                        : null,
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: task.isCompleted ? _kTextDone : _kTextHead,
                          letterSpacing: -0.2,
                          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                          decorationColor: _kTextMuted,
                          decorationThickness: 1.8,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 13,
                            color: _kTextMuted,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              formattedDue,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: _kTextMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Priority Badge (e.g. "High" as seen in reference image)
                if (task.priority != null && task.priority!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: _kPrimaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      task.priority!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _kPrimaryBlue,
                      ),
                    ),
                  ),
                ],

                const SizedBox(width: 6),

                // Right: Three-dot overflow menu for actions (delete, toggle, edit)
                Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onMenuTap,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.more_vert,
                        color: _kTextMuted,
                        size: 20,
                      ),
                    ),
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
