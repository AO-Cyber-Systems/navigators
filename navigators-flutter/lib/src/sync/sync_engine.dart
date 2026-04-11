import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

import '../database/database.dart';
import 'pull_sync.dart';
import 'push_sync.dart';

/// Result of a full sync cycle.
class SyncResult {
  final int pushedCount;
  final int pulledVoters;
  final int pulledContactLogs;
  final int retriedCount;
  final List<String> errors;

  const SyncResult({
    required this.pushedCount,
    required this.pulledVoters,
    required this.pulledContactLogs,
    required this.retriedCount,
    this.errors = const [],
  });

  bool get hasErrors => errors.isNotEmpty;

  @override
  String toString() =>
      'SyncResult(pushed: $pushedCount, pulledVoters: $pulledVoters, '
      'pulledContactLogs: $pulledContactLogs, retried: $retriedCount, '
      'errors: ${errors.length})';
}

/// SyncEngine orchestrates the full sync cycle: push pending, then pull updates.
///
/// Push-before-pull ordering ensures:
/// 1. Local changes reach the server first
/// 2. Pull then gets back the server-authoritative version
/// 3. No risk of overwriting server data with stale local data
class SyncEngine {
  final NavigatorsDatabase _db;
  final PushSync _pushSync;
  final SyncClient _pullClient;

  /// Static instance for access from connectivity listener and WorkManager.
  static SyncEngine? instance;

  bool _isSyncing = false;

  SyncEngine(this._db, this._pushSync, this._pullClient) {
    instance = this;
  }

  /// Whether a sync cycle is currently in progress.
  bool get isSyncing => _isSyncing;

  /// Run a full sync cycle: push all pending, retry failed, then pull updates.
  ///
  /// Safe to call from both main isolate and WorkManager background isolate.
  /// Uses a simple lock (_isSyncing) to prevent concurrent cycles.
  Future<SyncResult> runSyncCycle() async {
    if (_isSyncing) {
      return const SyncResult(
        pushedCount: 0,
        pulledVoters: 0,
        pulledContactLogs: 0,
        retriedCount: 0,
        errors: ['Sync already in progress'],
      );
    }

    _isSyncing = true;
    try {
      // Check actual internet connectivity (not just network interface)
      final hasInternet = await InternetConnection().hasInternetAccess;
      if (!hasInternet) {
        return const SyncResult(
          pushedCount: 0,
          pulledVoters: 0,
          pulledContactLogs: 0,
          retriedCount: 0,
          errors: ['No internet connection'],
        );
      }

      final errors = <String>[];
      var totalPushed = 0;
      var retriedCount = 0;

      // Phase 1: Push pending operations (loop until all pushed)
      try {
        while (true) {
          final pushed = await _pushSync.pushPendingOperations();
          if (pushed == 0) break;
          totalPushed += pushed;
        }
      } catch (e) {
        errors.add('Push failed: $e');
      }

      // Phase 2: Retry previously failed operations
      try {
        retriedCount = await _pushSync.retryFailedOperations();
      } catch (e) {
        errors.add('Retry failed: $e');
      }

      // Phase 3: Pull updates from server
      var pulledVoters = 0;
      var pulledContactLogs = 0;

      try {
        // Get turf IDs from local turf assignments
        final turfIds = await _getTurfIds();

        if (turfIds.isNotEmpty) {
          pulledVoters =
              await _pullClient.pullAllVoters(_db, turfIds);
          pulledContactLogs =
              await _pullClient.pullAllContactLogs(_db, turfIds);
        }
      } catch (e) {
        errors.add('Pull failed: $e');
      }

      return SyncResult(
        pushedCount: totalPushed,
        pulledVoters: pulledVoters,
        pulledContactLogs: pulledContactLogs,
        retriedCount: retriedCount,
        errors: errors,
      );
    } finally {
      _isSyncing = false;
    }
  }

  /// Push-only sync (for quick sync before navigating away).
  Future<int> pushOnly() async {
    if (_isSyncing) return 0;

    _isSyncing = true;
    try {
      final hasInternet = await InternetConnection().hasInternetAccess;
      if (!hasInternet) return 0;

      var totalPushed = 0;
      while (true) {
        final pushed = await _pushSync.pushPendingOperations();
        if (pushed == 0) break;
        totalPushed += pushed;
      }
      return totalPushed;
    } finally {
      _isSyncing = false;
    }
  }

  /// Get turf IDs from local turf_assignments table.
  Future<List<String>> _getTurfIds() async {
    final assignments = await _db.select(_db.turfAssignments).get();
    return assignments.map((a) => a.turfId).toList();
  }
}

/// Riverpod provider for SyncEngine.
final syncEngineProvider = Provider<SyncEngine>((ref) {
  final db = ref.watch(databaseProvider);
  final pushSync = ref.watch(pushSyncProvider);
  final pullClient = ref.watch(syncClientProvider);
  return SyncEngine(db, pushSync, pullClient);
});
