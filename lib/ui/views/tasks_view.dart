import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../controllers/tasks_controller.dart';
import '../../models/chore.dart';

/// Screen 3: Solo Student Tasks & Academic Deadlines View
class TasksView extends StatelessWidget {
  const TasksView({super.key});

  @override
  Widget build(BuildContext context) {
    return const TasksDeadlines();
  }
}

class TasksDeadlines extends StatefulWidget {
  const TasksDeadlines({super.key});

  @override
  State<TasksDeadlines> createState() => _TasksDeadlinesState();
}

class _TasksDeadlinesState extends State<TasksDeadlines> {
  DateTime? _tryParseDueDate(String text) {
    try {
      return DateFormat('MMM d, yyyy')
          .parse(text.replaceFirst('Due: ', '').trim());
    } catch (_) {
      return null;
    }
  }

  Future<DateTime?> _pickDueDate(
      BuildContext context, DateTime? initial) async {
    final now = DateTime.now();
    return await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF155E4A), // Emerald accent
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
            dialogBackgroundColor: AppColors.surface,
          ),
          child: child!,
        );
      },
    );
  }

  Future<bool> _confirmDeleteTask(
      BuildContext context, String taskTitle) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text(
              'Delete Task',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
            content: Text(
              'Are you sure you want to delete "$taskTitle"?',
              style:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Delete',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showAddTaskModal(BuildContext context, TasksController controller) {
    final titleCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    String dueDateDisplay = DateFormat('MMM d, yyyy').format(selectedDate);
    String selectedCategory = 'Academic';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setModalState) => ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(ctx2).size.height * 0.85),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx2).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0x33FFFFFF),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Add Academic / Personal Task',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Category Selection
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['Academic', 'Personal'].map((cat) {
                      final sel = selectedCategory == cat;
                      return GestureDetector(
                        onTap: () =>
                            setModalState(() => selectedCategory = cat),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel
                                ? AppColors.accent
                                : AppColors.surfaceSecondary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              color: sel
                                  ? AppColors.background
                                  : AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: titleCtrl,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Task Title (e.g. Study Math, CS301 Project)',
                      hintStyle: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                      filled: true,
                      fillColor: AppColors.surfaceSecondary,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Due Date',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () async {
                      final picked = await _pickDueDate(context, selectedDate);
                      if (picked != null) {
                        setModalState(() {
                          selectedDate = picked;
                          dueDateDisplay =
                              DateFormat('MMM d, yyyy').format(picked);
                        });
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined,
                              color: AppColors.accent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              dueDateDisplay,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.edit_calendar_outlined,
                              color: AppColors.accent, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        if (titleCtrl.text.trim().isNotEmpty) {
                          controller.addTask(
                            title: titleCtrl.text.trim(),
                            category: selectedCategory,
                            dueDate: dueDateDisplay,
                          );
                          Navigator.pop(ctx2);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.background,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Add Task',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showEditTaskModal(
      BuildContext context, TasksController controller, ChoreItem task) {
    final titleCtrl = TextEditingController(text: task.title);
    DateTime selectedDate = _tryParseDueDate(task.dueDate) ?? DateTime.now();
    String dueDateDisplay = task.dueDate;
    String selectedCategory =
        task.category.toLowerCase().contains('acad') ? 'Academic' : 'Personal';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setModalState) => ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(ctx2).size.height * 0.85),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx2).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0x33FFFFFF),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Edit Task',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['Academic', 'Personal'].map((cat) {
                      final sel = selectedCategory == cat;
                      return GestureDetector(
                        onTap: () =>
                            setModalState(() => selectedCategory = cat),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel
                                ? AppColors.accent
                                : AppColors.surfaceSecondary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              color: sel
                                  ? AppColors.background
                                  : AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: titleCtrl,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Task Title (e.g. Study Math, CS301 Project)',
                      hintStyle: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                      filled: true,
                      fillColor: AppColors.surfaceSecondary,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Due Date',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () async {
                      final picked = await _pickDueDate(context, selectedDate);
                      if (picked != null) {
                        setModalState(() {
                          selectedDate = picked;
                          dueDateDisplay =
                              DateFormat('MMM d, yyyy').format(picked);
                        });
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined,
                              color: AppColors.accent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              dueDateDisplay,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.edit_calendar_outlined,
                              color: AppColors.accent, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        if (titleCtrl.text.trim().isNotEmpty) {
                          controller.updateTask(
                            id: task.id,
                            title: titleCtrl.text.trim(),
                            category: selectedCategory,
                            dueDate: dueDateDisplay,
                          );
                          Navigator.pop(ctx2);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.background,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Save Changes',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    TasksController? controller;
    try {
      controller = context.watch<TasksController>();
    } catch (_) {}

    final tasks = controller?.filteredTasks ?? [];
    final currentFilter = controller?.filter ?? TaskCategoryFilter.all;
    final allCount = controller?.allCount ?? 0;
    final academicCount = controller?.academicCount ?? 0;
    final personalCount = controller?.personalCount ?? 0;
    final completionPct = controller?.completionPercentage ?? 0;
    final isEmpty = controller?.isEmpty ?? tasks.isEmpty;

    final prioritizedTasks = List<ChoreItem>.from(tasks)
      ..sort((a, b) {
        if (a.isCompleted == b.isCompleted) return 0;
        return a.isCompleted ? 1 : -1;
      });

    return Scaffold(
      backgroundColor: AppColors.deepPine,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── 1. Deep Pine Header (#1E3A2E) ──────────────────────
            Container(
              color: AppColors.deepPine,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Title & Add Task Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tasks & Deadlines',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.surfaceWhite,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Academic & Personal Study Schedule',
                              style: TextStyle(
                                color: AppColors.softSage,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (!isEmpty) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: () {
                                if (controller != null)
                                  _showAddTaskModal(context, controller);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.vibrantGreen,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add,
                                        color: AppColors.darkForest, size: 14),
                                    SizedBox(width: 3),
                                    Text(
                                      'Add Task',
                                      style: TextStyle(
                                        color: AppColors.darkForest,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Header Completion Stats Capsule with RouletteNumberText
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF264A3B),
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: AppColors.midMoss.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.vibrantGreen.withOpacity(0.20),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(Icons.check_circle_outline,
                                color: AppColors.vibrantGreen, size: 20),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Flexible(
                                    child: Text(
                                      'SCHEDULE COMPLETION',
                                      style: TextStyle(
                                        color: AppColors.softSage,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.8,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        '$completionPct% Complete',
                                        style: const TextStyle(
                                          color: AppColors.vibrantGreen,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  height: 6,
                                  color: Colors.white.withOpacity(0.15),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor:
                                        (completionPct / 100).clamp(0.0, 1.0),
                                    child: Container(
                                        color: AppColors.vibrantGreen),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── 2. Curved Body Sheet (#F9FAF7, 38px radius) ────────
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(38),
                    topRight: Radius.circular(38),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(38),
                    topRight: Radius.circular(38),
                  ),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Filter Segmented Tabs Bar
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLow,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.sandCream.withOpacity(0.5)),
                          ),
                          child: Row(
                            children: [
                              _filterTabItem(
                                'All',
                                allCount,
                                currentFilter == TaskCategoryFilter.all,
                                () => controller
                                    ?.setFilter(TaskCategoryFilter.all),
                              ),
                              _filterTabItem(
                                'Academic',
                                academicCount,
                                currentFilter == TaskCategoryFilter.academic,
                                () => controller
                                    ?.setFilter(TaskCategoryFilter.academic),
                              ),
                              _filterTabItem(
                                'Personal/Chore',
                                personalCount,
                                currentFilter == TaskCategoryFilter.personal,
                                () => controller
                                    ?.setFilter(TaskCategoryFilter.personal),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Tasks Content (List or Empty State)
                        if (isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 36),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: AppColors.sandCream.withOpacity(0.4)),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.sandCream.withOpacity(0.35),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.task_alt,
                                      color: AppColors.deepPine, size: 26),
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  'No tasks or deadlines logged. Tap \'Add Task\' to organize your study schedule.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.darkForest,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    if (controller != null)
                                      _showAddTaskModal(context, controller);
                                  },
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Add Task',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.vibrantGreen,
                                    foregroundColor: AppColors.darkForest,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: prioritizedTasks.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final task = prioritizedTasks[index];
                              return _buildTaskCard(context, controller, task);
                            },
                          ),
                      ],
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

  Widget _filterTabItem(
      String title, int count, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.vibrantGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    color:
                        isSelected ? AppColors.darkForest : AppColors.darkOlive,
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color:
                      isSelected ? AppColors.darkForest : AppColors.surfaceLow,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.vibrantGreen
                          : AppColors.darkOlive,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
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

  Widget _buildTaskCard(
      BuildContext context, TasksController? controller, ChoreItem task) {
    final isAcademic = task.category.toLowerCase().contains('acad');

    return Dismissible(
      key: Key('task-${task.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) => _confirmDeleteTask(context, task.title),
      onDismissed: (_) {
        controller?.deleteTask(task.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted "${task.title}"'),
            backgroundColor: AppColors.surfaceSecondary,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0x33D32F2F),
          borderRadius: BorderRadius.circular(16),
        ),
        child:
            const Icon(Icons.delete_outline, color: AppColors.error, size: 24),
      ),
      child: GestureDetector(
        onTap: () {
          if (controller != null) _showEditTaskModal(context, controller, task);
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: task.isCompleted
                  ? AppColors.border
                  : AppColors.borderHighlight,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Checkbox Toggle
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      controller?.toggleTask(task.id);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 22,
                      height: 22,
                      margin: const EdgeInsets.only(top: 2),
                      decoration: BoxDecoration(
                        color: task.isCompleted
                            ? AppColors.accent
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: task.isCompleted
                              ? AppColors.accent
                              : AppColors.textSecondary,
                          width: 1.5,
                        ),
                      ),
                      child: task.isCompleted
                          ? const Icon(Icons.check,
                              size: 16, color: AppColors.background)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Title & Category Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: TextStyle(
                            color: task.isCompleted
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            decoration: task.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          children: [
                            Text(
                              task.dueDate,
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 11),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isAcademic
                                    ? const Color(0x1F7EB4FF)
                                    : AppColors.accentSubtle,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                task.category,
                                style: TextStyle(
                                  color: isAcademic
                                      ? AppColors.academic
                                      : AppColors.personal,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Action row: Edit, Delete, and Mark done buttons wrapped in Wrap
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (controller != null)
                          _showEditTaskModal(context, controller, task);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSecondary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit_outlined,
                                  color: AppColors.textSecondary, size: 14),
                              SizedBox(width: 4),
                              Text('Edit',
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        final confirmed =
                            await _confirmDeleteTask(context, task.title);
                        if (confirmed) {
                          controller?.deleteTask(task.id);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSecondary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.delete_outline,
                                  color: AppColors.textSecondary, size: 14),
                              SizedBox(width: 4),
                              Text('Delete',
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => controller?.toggleTask(task.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: task.isCompleted
                              ? AppColors.surfaceSecondary
                              : AppColors.accent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          task.isCompleted ? 'Mark Pending' : 'Mark Done',
                          style: TextStyle(
                            color: task.isCompleted
                                ? AppColors.textSecondary
                                : AppColors.background,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
