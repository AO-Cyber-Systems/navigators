import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:eden_platform_flutter/eden_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../database/database.dart';

/// Task detail screen showing full task information.
///
/// Sections:
/// 1. Header: title, status chip, priority badge, task type
/// 2. Progress: LinearProgressIndicator + count text
/// 3. Due date with overdue highlighting
/// 4. Linked item (turf/voter/list)
/// 5. Notes section with add-note input
class TaskDetailScreen extends ConsumerStatefulWidget {
  final String taskId;

  const TaskDetailScreen({super.key, required this.taskId});

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  final _noteController = TextEditingController();
  bool _isSendingNote = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    NavigatorsDatabase db;
    try {
      db = ref.read(databaseProvider);
    } catch (_) {
      return Scaffold(
        appBar: AppBar(title: const Text('Task')),
        body: const Center(child: Text('Database not initialized')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Details'),
      ),
      body: FutureBuilder<Task?>(
        future: db.taskDao.getTask(widget.taskId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final task = snapshot.data;
          if (task == null) {
            return const Center(child: Text('Task not found'));
          }

          return _buildTaskDetail(context, db, task);
        },
      ),
    );
  }

  Widget _buildTaskDetail(
      BuildContext context, NavigatorsDatabase db, Task task) {
    final theme = Theme.of(context);
    final isOverdue =
        task.dueDate != null && task.dueDate!.isBefore(DateTime.now());

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. Header
              Text(
                task.title,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _StatusChip(status: task.status),
                  const SizedBox(width: 8),
                  _PriorityBadge(priority: task.priority),
                  const SizedBox(width: 8),
                  Icon(
                    _taskTypeIcon(task.taskType),
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _taskTypeLabel(task.taskType),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              if (task.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(task.description, style: theme.textTheme.bodyMedium),
              ],

              // 2. Progress
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text('Progress', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: task.progressPct / 100,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${task.progressPct}% complete',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (task.totalCount > 0)
                    Text(
                      '${task.completedCount}/${task.totalCount} completed',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),

              // 3. Due date
              if (task.dueDate != null) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: isOverdue
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Due ${DateFormat.yMMMd().format(task.dueDate!)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isOverdue
                            ? theme.colorScheme.error
                            : null,
                        fontWeight:
                            isOverdue ? FontWeight.bold : null,
                      ),
                    ),
                    if (isOverdue) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Overdue',
                          style: TextStyle(
                            color: theme.colorScheme.error,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],

              // 4. Linked item
              if (task.linkedEntityType != null) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      _linkedEntityIcon(task.linkedEntityType!),
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Linked: ${_linkedEntityLabel(task.linkedEntityType!)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ],

              // 5. Assignments
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text('Assignments', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              StreamBuilder<List<TaskAssignment>>(
                stream: _watchAssignments(db),
                builder: (context, snapshot) {
                  final assignments = snapshot.data ?? [];
                  if (assignments.isEmpty) {
                    return Text(
                      'No assignments',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    );
                  }
                  return Column(
                    children: assignments.map((a) {
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          radius: 16,
                          child: Icon(Icons.person, size: 16),
                        ),
                        title: Text(a.userId,
                            style: theme.textTheme.bodyMedium),
                        subtitle: Text(
                          'Assigned ${DateFormat.MMMd().format(a.assignedAt)}',
                          style: theme.textTheme.bodySmall,
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

              // 6. Notes section
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text('Notes', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              StreamBuilder<List<TaskNote>>(
                stream: db.taskDao.watchTaskNotes(widget.taskId),
                builder: (context, snapshot) {
                  final notes = snapshot.data ?? [];
                  if (notes.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No notes yet',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: notes.map((note) => _NoteCard(note: note)).toList(),
                  );
                },
              ),
            ],
          ),
        ),

        // 7. Add note input at bottom
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              top: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _noteController,
                    decoration: const InputDecoration(
                      hintText: 'Add a note...',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _isSendingNote
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  onPressed: _isSendingNote ? null : () => _addNote(context),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Stream<List<TaskAssignment>> _watchAssignments(NavigatorsDatabase db) {
    return (db.select(db.taskAssignments)
          ..where((t) => t.taskId.equals(widget.taskId)))
        .watch();
  }

  Future<void> _addNote(BuildContext context) async {
    final content = _noteController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isSendingNote = true);

    try {
      final db = ref.read(databaseProvider);
      final auth = ref.read(authProvider);
      final userId = auth.userId ?? '';
      final now = DateTime.now();
      final noteId = _generateId();

      await db.taskDao.insertTaskNoteWithOutbox(
        TaskNotesCompanion(
          id: Value(noteId),
          companyId: const Value(''), // Filled by server
          taskId: Value(widget.taskId),
          userId: Value(userId),
          content: Value(content),
          visibility: const Value('team'),
          createdAt: Value(now),
        ),
        db.syncDao,
      );

      _noteController.clear();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add note: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingNote = false);
      }
    }
  }

  /// Generate a simple unique ID using timestamp + random.
  static String _generateId() {
    final rng = DateTime.now().microsecondsSinceEpoch;
    final random = Random.secure().nextInt(0xffff);
    return '${rng.toRadixString(16).padLeft(12, '0')}-'
        '${random.toRadixString(16).padLeft(4, '0')}-'
        '4${(rng % 0xfff).toRadixString(16).padLeft(3, '0')}-'
        '${(0x8000 | (rng & 0x3fff)).toRadixString(16)}-'
        '${DateTime.now().millisecondsSinceEpoch.toRadixString(16).padLeft(12, '0')}';
  }

  IconData _taskTypeIcon(String type) {
    return switch (type) {
      'contact_list' => Icons.list_alt,
      'event' => Icons.event,
      'data_entry' => Icons.edit_note,
      _ => Icons.task,
    };
  }

  String _taskTypeLabel(String type) {
    return switch (type) {
      'contact_list' => 'Contact List',
      'event' => 'Event',
      'data_entry' => 'Data Entry',
      'custom' => 'Custom',
      _ => type,
    };
  }

  IconData _linkedEntityIcon(String entityType) {
    return switch (entityType) {
      'turf' => Icons.map,
      'voter' => Icons.person,
      'voter_list' => Icons.list,
      _ => Icons.link,
    };
  }

  String _linkedEntityLabel(String entityType) {
    return switch (entityType) {
      'turf' => 'Turf',
      'voter' => 'Voter',
      'voter_list' => 'Voter List',
      _ => entityType,
    };
  }
}

/// Individual note card.
class _NoteCard extends StatelessWidget {
  final TaskNote note;

  const _NoteCard({required this.note});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  note.userId,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (note.visibility != 'team')
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      note.visibility,
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Text(
                  DateFormat.MMMd().add_jm().format(note.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(note.content, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

/// Color-coded priority badge (shared with task_list_screen).
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
