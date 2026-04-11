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
