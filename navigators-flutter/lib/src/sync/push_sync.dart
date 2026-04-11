import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import 'pull_sync.dart';

/// Maximum number of operations to push in a single batch.
const int _maxBatchSize = 50;

/// Maximum number of retry attempts before an operation becomes dead-letter.
const int maxRetryCount = 5;

/// PushSync reads the sync_operations outbox and pushes batched operations
/// to the server via the PushSyncBatch RPC.
class PushSync {
  final NavigatorsDatabase _db;
  final SyncClient _client;

  PushSync(this._db, this._client);

  /// Push pending operations from the outbox to the server.
  ///
  /// Returns the count of successfully pushed operations.
  /// Operations are processed in creation order (FIFO), batched up to 50.
  ///
  /// Flow:
  /// 1. SELECT pending ops (limit 50, ordered by createdAt ASC)
  /// 2. Mark as in_progress (prevents double-sends)
  /// 3. Send PushSyncBatchRequest
  /// 4. Delete processed ops, handle failures
  Future<int> pushPendingOperations() async {
    final syncDao = _db.syncDao;

    // 1. Get pending operations
    final pending = await syncDao.getPendingOperations(_maxBatchSize);
    if (pending.isEmpty) return 0;

    // 2. Mark as in_progress before sending
    final ids = pending.map((op) => op.id).toList();
    await syncDao.markInProgress(ids);

    try {
      // 3. Build and send PushSyncBatch request
      final operations = pending.map((op) {
        return {
          'clientOperationId': '${op.id}',
          'entityType': op.entityType,
          'entityId': op.entityId,
          'operationType': op.operationType,
          'payload': base64Encode(op.payload),
          'clientTimestamp': op.createdAt.toIso8601String(),
        };
      }).toList();

      final response = await _client.pushSyncBatch(operations);

      // 4. Process response
      final processedIds = (response['processedOperationIds'] as List<dynamic>?)
              ?.cast<String>() ??
          [];
      final errors = (response['errors'] as List<dynamic>?) ?? [];

      // Map processed string IDs back to integer IDs
      final processedIntIds = <int>[];
      final failedIntIds = <int>[];

      // Build a map from string ID to int ID
      final idMap = <String, int>{};
      for (final op in pending) {
        idMap['${op.id}'] = op.id;
      }

      for (final pid in processedIds) {
        final intId = idMap[pid];
        if (intId != null) processedIntIds.add(intId);
      }

      // Collect IDs that had errors
      final errorOpIds = <String>{};
      for (final err in errors) {
        final errMap = err as Map<String, dynamic>;
        final opId = errMap['operationId'] as String? ?? '';
        errorOpIds.add(opId);
      }

      for (final errId in errorOpIds) {
        final intId = idMap[errId];
        if (intId != null) failedIntIds.add(intId);
      }

      // Delete successfully processed operations
      if (processedIntIds.isNotEmpty) {
        await syncDao.markSynced(processedIntIds);
      }

      // Mark failed operations with incremented retry count
      if (failedIntIds.isNotEmpty) {
        await syncDao.markFailedWithRetry(failedIntIds);
      }

      // Any remaining in-progress ops that were neither processed nor errored:
      // reset to pending (partial success case)
      final handledIds = {...processedIntIds, ...failedIntIds};
      final unhandledIds =
          ids.where((id) => !handledIds.contains(id)).toList();
      if (unhandledIds.isNotEmpty) {
        await syncDao.markFailed(unhandledIds);
      }

      return processedIntIds.length;
    } catch (e) {
      // Network failure: reset ALL to pending for retry
      await syncDao.resetInProgressToPending();
      rethrow;
    }
  }

  /// Reset failed operations (under retry limit) back to pending for retry.
  Future<int> retryFailedOperations() async {
    final syncDao = _db.syncDao;
    final retriable =
        await syncDao.getRetriableFailedOperations(maxRetryCount);
    if (retriable.isEmpty) return 0;

    final ids = retriable.map((op) => op.id).toList();
    await syncDao.resetToPending(ids);
    return ids.length;
  }

  /// Get dead-letter operations (exceeded retry limit) for UI display.
  Future<List<SyncOperation>> getDeadLetterOperations() {
    return _db.syncDao.getDeadLetterOperations(maxRetryCount);
  }

  /// Push pending operations for a specific turf (used before turf reassignment cleanup).
  ///
  /// Filters the outbox for operations whose entityId matches voters in the given turf,
  /// or whose payload contains the turfId. This ensures no field work is lost before
  /// deleting local data for a removed turf.
  Future<int> pushOperationsForTurf(String turfId) async {
    final syncDao = _db.syncDao;
    final pending = await syncDao.getPendingOperations(1000);
    if (pending.isEmpty) return 0;

    // Filter operations related to this turf by checking payload for turfId
    final turfOps = pending.where((op) {
      try {
        final payloadStr = utf8.decode(op.payload);
        return payloadStr.contains(turfId);
      } catch (_) {
        return false;
      }
    }).toList();

    if (turfOps.isEmpty) return 0;

    // Mark as in_progress before sending
    final ids = turfOps.map((op) => op.id).toList();
    await syncDao.markInProgress(ids);

    try {
      final operations = turfOps.map((op) {
        return {
          'clientOperationId': '${op.id}',
          'entityType': op.entityType,
          'entityId': op.entityId,
          'operationType': op.operationType,
          'payload': base64Encode(op.payload),
          'clientTimestamp': op.createdAt.toIso8601String(),
        };
      }).toList();

      final response = await _client.pushSyncBatch(operations);

      final processedIds = (response['processedOperationIds'] as List<dynamic>?)
              ?.cast<String>() ??
          [];

      final idMap = <String, int>{};
      for (final op in turfOps) {
        idMap['${op.id}'] = op.id;
      }

      final processedIntIds = <int>[];
      for (final pid in processedIds) {
        final intId = idMap[pid];
        if (intId != null) processedIntIds.add(intId);
      }

      if (processedIntIds.isNotEmpty) {
        await syncDao.markSynced(processedIntIds);
      }

      // Reset any not-processed back to pending
      final unprocessedIds =
          ids.where((id) => !processedIntIds.contains(id)).toList();
      if (unprocessedIds.isNotEmpty) {
        await syncDao.resetToPending(unprocessedIds);
      }

      return processedIntIds.length;
    } catch (_) {
      // Network failure: reset to pending for retry
      await syncDao.resetInProgressToPending();
      return 0;
    }
  }
}

/// Riverpod provider for PushSync.
final pushSyncProvider = Provider<PushSync>((ref) {
  final db = ref.watch(databaseProvider);
  final syncClient = ref.watch(syncClientProvider);
  return PushSync(db, syncClient);
});
