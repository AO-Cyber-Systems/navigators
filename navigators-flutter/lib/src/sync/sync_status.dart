import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import '../database/daos/sync_dao.dart';

/// Aggregate sync status for the UI layer.
class SyncStatus {
  final int pendingOperations;
  final DateTime? lastSyncAt;
  final bool isSyncing;
  final String? lastError;
  final bool isOnline;

  const SyncStatus({
    this.pendingOperations = 0,
    this.lastSyncAt,
    this.isSyncing = false,
    this.lastError,
    this.isOnline = false,
  });

  bool get hasPending => pendingOperations > 0;
  bool get isFullySynced => pendingOperations == 0 && lastError == null;
}

/// Watches connectivity state via connectivity_plus.
/// Returns true when any connection type other than none is available.
final connectivityProvider = StreamProvider<bool>((ref) {
  return Connectivity().onConnectivityChanged.map((results) {
    return results.any((r) => r != ConnectivityResult.none);
  });
});

/// Whether a sync cycle is currently running.
/// Set by the sync engine during runSyncCycle.
final isSyncingProvider = StateProvider<bool>((ref) => false);

/// Last error from the most recent sync attempt.
final lastSyncErrorProvider = StateProvider<String?>((ref) => null);

/// Reads the most recent lastSyncAt from the sync_cursors table.
final lastSyncTimeProvider = FutureProvider<DateTime?>((ref) async {
  try {
    final db = ref.watch(databaseProvider);
    final syncDao = SyncDao(db);
    // Check voters cursor as the representative sync time
    final cursor = await syncDao.getCursor('voters');
    return cursor?.lastSyncAt;
  } catch (_) {
    return null;
  }
});

/// Aggregate sync status provider.
/// Combines pending count (reactive Drift stream), connectivity, syncing state,
/// and last sync time into a single SyncStatus object.
final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final isOnlineAsync = ref.watch(connectivityProvider);
  final isSyncing = ref.watch(isSyncingProvider);
  final lastError = ref.watch(lastSyncErrorProvider);
  final lastSyncTimeAsync = ref.watch(lastSyncTimeProvider);

  final isOnline = isOnlineAsync.valueOrNull ?? false;
  final lastSyncAt = lastSyncTimeAsync.valueOrNull;

  try {
    final db = ref.watch(databaseProvider);
    final syncDao = SyncDao(db);

    // Use Drift's reactive .watch() for zero-polling pending count
    return syncDao.countPending().map((count) {
      return SyncStatus(
        pendingOperations: count,
        lastSyncAt: lastSyncAt,
        isSyncing: isSyncing,
        lastError: lastError,
        isOnline: isOnline,
      );
    });
  } catch (_) {
    // Database not yet initialized -- return a default status stream
    return Stream.value(SyncStatus(
      isOnline: isOnline,
      isSyncing: isSyncing,
      lastError: lastError,
      lastSyncAt: lastSyncAt,
    ));
  }
});
