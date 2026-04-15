import 'package:eden_platform_flutter/eden_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../database/database.dart';
import 'task_create_screen.dart';
import 'task_detail_screen.dart';

/// Task inbox screen showing tasks assigned to the current user.
///
/// Features:
/// - Filter chips: All, Open, In Progress, Completed
/// - Task cards with title, type icon, priority badge, due date, progress bar
/// - FAB for task creation (visible for Manager/60+ roles: super_navigator, admin)
/// - Empty state message when no tasks assigned
/// - Offline-first: reads from local Drift database via TaskDao
class TaskListScreen extends ConsumerStatefulWidget {
  const TaskListScreen({super.key});

  @override
  ConsumerState<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends ConsumerState<TaskListScreen> {
  String _selectedFilter = 'all';

  static const _filters = ['all', 'open', 'in_progress', 'completed'];
  static const _filterLabels = {
    'all': 'All',
    'open': 'Open',
    'in_progress': 'In Progress',
    'completed': 'Completed',
  };

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final userId = auth.userId ?? '';
    final canCreate = _canCreateTasks(auth.role);

    return Semantics(
      identifier: 'task-list-screen',
      explicitChildNodes: true,
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
      ),
      body: Column(
        children: [
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: _filters.map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Semantics(
                    identifier: 'task-list-filter-$filter',
                    button: true,
                    selected: isSelected,
                    child: FilterChip(
                      label: Text(_filterLabels[filter]!),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _selectedFilter = filter),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          // Task list
          Expanded(
            child: _buildTaskList(userId),
          ),
        ],
      ),
      floatingActionButton: canCreate
          ? Semantics(
              identifier: 'task-list-fab',
              button: true,
              child: FloatingActionButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const TaskCreateScreen(),
                    ),
                  );
                },
                child: const Icon(Icons.add),
              ),
            )
          : null,
      ),
    );
  }

  Widget _buildTaskList(String userId) {
    if (userId.isEmpty) {
      return const Center(child: Text('Not authenticated'));
    }

    NavigatorsDatabase db;
    try {
      db = ref.read(databaseProvider);
    } catch (_) {
      return const Center(child: Text('Database not initialized'));
    }

    // Use watchMyTasks for 'all' filter, or watchTasksByStatus for specific filter
    final stream = _selectedFilter == 'all'
        ? db.taskDao.watchMyTasks(userId)
        : db.taskDao.watchTasksByStatus(_selectedFilter);

    return StreamBuilder<List<Task>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final tasks = snapshot.data ?? [];
        if (tasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.task_alt,
                  size: 64,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  'No tasks assigned',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: tasks.length,
          itemBuilder: (context, index) => Semantics(
            identifier: 'task-list-row-${tasks[index].id}',
            button: true,
            child: _TaskCard(
              task: tasks[index],
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TaskDetailScreen(taskId: tasks[index].id),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// Check if user can create tasks (Manager/60+ = super_navigator or admin).
  bool _canCreateTasks(String? role) {
    if (role == null) return false;
    final lower = role.toLowerCase();
    return lower == 'admin' || lower == 'manager' || lower == 'super_navigator';
  }
}

/// Individual task card widget.
class _TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onTap;

  const _TaskCard({required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOverdue = task.dueDate != null && task.dueDate!.isBefore(DateTime.now());

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row with type icon and priority badge
              Row(
                children: [
                  Icon(
                    _taskTypeIcon(task.taskType),
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      task.title,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _PriorityBadge(priority: task.priority),
                ],
              ),
              const SizedBox(height: 8),
              // Status chip and due date
              Row(
                children: [
                  _StatusChip(status: task.status),
                  const Spacer(),
                  if (task.dueDate != null)
                    Text(
                      DateFormat.MMMd().format(task.dueDate!),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isOverdue
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              // Progress bar
              if (task.progressPct > 0 || task.totalCount > 0) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: task.progressPct / 100,
                  backgroundColor:
                      theme.colorScheme.surfaceContainerHighest,
                ),
                const SizedBox(height: 4),
                Text(
                  '${task.progressPct}% complete',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _taskTypeIcon(String type) {
    switch (type) {
      case 'contact_list':
        return Icons.list_alt;
      case 'event':
        return Icons.event;
      case 'data_entry':
        return Icons.edit_note;
      default:
        return Icons.task;
    }
  }
}

/// Color-coded priority badge.
class _PriorityBadge extends StatelessWidget {
  final String priority;

  const _PriorityBadge({required this.priority});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (priority) {
      'urgent' => (Colors.red, 'Urgent'),
      'high' => (Colors.orange, 'High'),
      'medium' => (Colors.blue, 'Medium'),
      'low' => (Colors.grey, 'Low'),
      _ => (Colors.grey, priority),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Status chip widget.
class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      'open' => 'Open',
      'in_progress' => 'In Progress',
      'completed' => 'Completed',
      'cancelled' => 'Cancelled',
      _ => status,
    };

    return Chip(
      label: Text(label),
      labelStyle: const TextStyle(fontSize: 11),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
