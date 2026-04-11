import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/tasks.dart';
import '../tables/task_assignments.dart';
import '../tables/task_notes.dart';
import 'sync_dao.dart';

part 'task_dao.g.dart';

@DriftAccessor(tables: [Tasks, TaskAssignments, TaskNotes])
class TaskDao extends DatabaseAccessor<NavigatorsDatabase>
    with _$TaskDaoMixin {
  TaskDao(super.db);

  /// Get a single task by ID.
  Future<Task?> getTask(String id) {
    return (select(tasks)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Watch tasks assigned to a specific user (via JOIN on task_assignments).
  Stream<List<Task>> watchMyTasks(String userId) {
    final query = select(tasks).join([
      innerJoin(
        taskAssignments,
        taskAssignments.taskId.equalsExp(tasks.id),
      ),
    ])
      ..where(taskAssignments.userId.equals(userId))
      ..orderBy([OrderingTerm.desc(tasks.createdAt)]);

    return query.watch().map(
          (rows) => rows.map((row) => row.readTable(tasks)).toList(),
        );
  }

  /// Watch task notes for a task, ordered by createdAt DESC.
  Stream<List<TaskNote>> watchTaskNotes(String taskId) {
    return (select(taskNotes)
          ..where((t) => t.taskId.equals(taskId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// Watch tasks filtered by status.
  Stream<List<Task>> watchTasksByStatus(String status) {
    return (select(tasks)
          ..where((t) => t.status.equals(status))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// Bulk upsert tasks from server pull sync.
  Future<void> upsertTasks(List<TasksCompanion> items) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(tasks, items);
    });
  }

  /// Bulk upsert task assignments from server pull sync.
  Future<void> upsertTaskAssignments(
      List<TaskAssignmentsCompanion> items) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(taskAssignments, items);
    });
  }

  /// Bulk upsert task notes from server pull sync.
  Future<void> upsertTaskNotes(List<TaskNotesCompanion> items) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(taskNotes, items);
    });
  }

  /// Insert a task note and enqueue a sync operation in a single transaction.
  Future<void> insertTaskNoteWithOutbox(
    TaskNotesCompanion note,
    SyncDao syncDao,
  ) async {
    await syncDao.writeWithOutbox(
      attachedDatabase,
      dataWrite: () async {
        await into(taskNotes).insert(note);
      },
      entityType: 'task_note',
      entityId: note.id.value,
      operationType: 'create',
      payload: {
        'id': note.id.value,
        'task_id': note.taskId.value,
        'content': note.content.value,
        'visibility': note.visibility.value,
        'created_at': note.createdAt.value.toIso8601String(),
      },
    );
  }
}
