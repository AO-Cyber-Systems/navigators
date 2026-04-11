import 'dart:convert';

import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/sync_operations.dart';
import '../tables/sync_cursors.dart';

part 'sync_dao.g.dart';

@DriftAccessor(tables: [SyncOperations, SyncCursors])
class SyncDao extends DatabaseAccessor<NavigatorsDatabase>
    with _$SyncDaoMixin {
  SyncDao(super.db);

  /// Enqueue a new sync operation in the outbox.
  Future<int> enqueueSyncOperation({
    required String entityType,
    required String entityId,
    required String operationType,
    required Uint8List payload,
  }) {
    return into(syncOperations).insert(
      SyncOperationsCompanion.insert(
        entityType: entityType,
        entityId: entityId,
        operationType: operationType,
        payload: payload,
      ),
    );
  }

  /// Get pending operations up to [limit], ordered by creation time.
  Future<List<SyncOperation>> getPendingOperations(int limit) {
    return (select(syncOperations)
          ..where((t) => t.status.equals('pending'))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
          ..limit(limit))
        .get();
  }

  /// Mark operations as in_progress before sending.
  Future<void> markInProgress(List<int> ids) {
    return (update(syncOperations)..where((t) => t.id.isIn(ids)))
        .write(const SyncOperationsCompanion(status: Value('in_progress')));
  }

  /// Delete successfully synced operations.
  Future<void> markSynced(List<int> ids) {
    return (delete(syncOperations)..where((t) => t.id.isIn(ids))).go();
  }

  /// Reset failed operations to pending and increment retry count.
  Future<void> markFailed(List<int> ids) async {
    for (final id in ids) {
      await (update(syncOperations)..where((t) => t.id.equals(id))).write(
        SyncOperationsCompanion(
          status: const Value('pending'),
          retryCount: const Value.absent(), // Incremented below
        ),
      );
      await customUpdate(
        'UPDATE sync_operations SET retry_count = retry_count + 1 WHERE id = ?',
        variables: [Variable.withInt(id)],
        updates: {syncOperations},
      );
    }
  }

  /// Watch count of pending operations for reactive UI.
  Stream<int> countPending() {
    final count = syncOperations.id.count();
    final query = selectOnly(syncOperations)
      ..addColumns([count])
      ..where(syncOperations.status.isIn(['pending', 'in_progress']));
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  /// Get operations that have exceeded retry limit (dead letter).
  Future<List<SyncOperation>> getOperationsOverRetryLimit(int maxRetries) {
    return (select(syncOperations)
          ..where((t) =>
              t.retryCount.isBiggerOrEqualValue(maxRetries) &
              t.status.equals('failed')))
        .get();
  }

  /// Get or create a sync cursor for an entity type.
  Future<SyncCursor?> getCursor(String entityType) {
    return (select(syncCursors)
          ..where((t) => t.entityType.equals(entityType)))
        .getSingleOrNull();
  }

  /// Reset in-progress operations back to pending (for crash recovery).
  Future<void> resetInProgressToPending() {
    return (update(syncOperations)
          ..where((t) => t.status.equals('in_progress')))
        .write(const SyncOperationsCompanion(status: Value('pending')));
  }

  /// Reset specific operations to pending status (for retry).
  Future<void> resetToPending(List<int> ids) {
    return (update(syncOperations)..where((t) => t.id.isIn(ids)))
        .write(const SyncOperationsCompanion(status: Value('pending')));
  }

  /// Mark specific operations as failed with incremented retry count.
  Future<void> markFailedWithRetry(List<int> ids) async {
    for (final id in ids) {
      await customUpdate(
        'UPDATE sync_operations SET status = \'failed\', retry_count = retry_count + 1 WHERE id = ?',
        variables: [Variable.withInt(id)],
        updates: {syncOperations},
      );
    }
  }

  /// Get failed operations that can still be retried (retry_count < maxRetries).
  Future<List<SyncOperation>> getRetriableFailedOperations(int maxRetries) {
    return (select(syncOperations)
          ..where((t) =>
              t.status.equals('failed') &
              t.retryCount.isSmallerThanValue(maxRetries))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  /// Get dead-letter operations (retryCount >= maxRetries).
  Future<List<SyncOperation>> getDeadLetterOperations(int maxRetries) {
    return (select(syncOperations)
          ..where((t) =>
              t.retryCount.isBiggerOrEqualValue(maxRetries)))
        .get();
  }

  /// Write a data entity + sync outbox entry in a single transaction.
  /// Used by all field write operations to guarantee outbox consistency.
  Future<void> writeWithOutbox(
    NavigatorsDatabase database, {
    required Future<void> Function() dataWrite,
    required String entityType,
    required String entityId,
    required String operationType,
    required Map<String, dynamic> payload,
  }) async {
    await database.transaction(() async {
      await dataWrite();
      await into(syncOperations).insert(
        SyncOperationsCompanion.insert(
          entityType: entityType,
          entityId: entityId,
          operationType: operationType,
          payload:
              Uint8List.fromList(utf8.encode(jsonEncode(payload))),
        ),
      );
    });
  }

  /// Update (or insert) a sync cursor.
  Future<void> updateCursor(String entityType, String cursor) {
    return into(syncCursors).insertOnConflictUpdate(
      SyncCursorsCompanion.insert(
        entityType: entityType,
        cursor: cursor,
        lastSyncAt: DateTime.now(),
      ),
    );
  }
}
