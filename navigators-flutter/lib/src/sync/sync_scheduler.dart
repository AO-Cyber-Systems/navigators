import 'dart:async';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:workmanager/workmanager.dart';

import '../database/database.dart';
import '../services/notification_service.dart';
import 'pull_sync.dart';
import 'push_sync.dart';
import 'sync_engine.dart';

/// Unique task name for WorkManager periodic sync.
const String _periodicSyncTask = 'navigators.periodicSync';

/// Top-level callback dispatcher for WorkManager background execution.
///
/// MUST be a top-level function (not inside a class or closure).
/// WorkManager invokes this in a separate isolate for background sync.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName != _periodicSyncTask) return true;

    NavigatorsDatabase? db;
    try {
      // Retrieve encryption key from secure storage (works in background isolate)
      const storage = FlutterSecureStorage();
      final encryptionKey = await storage.read(key: 'db_encryption_key');
      if (encryptionKey == null || encryptionKey.isEmpty) {
        // Cannot open DB without key -- skip this cycle
        return true;
      }

      db = NavigatorsDatabase.create(encryptionKey);

      // Create a minimal SyncClient for the background isolate.
      // In background, we read the stored access token from secure storage.
      final accessToken = await storage.read(key: 'access_token');
      const envUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
      final baseUrl = envUrl.isNotEmpty ? envUrl : 'http://localhost:8080';

      final syncClient = SyncClient(
        baseUrl: baseUrl,
        getAccessToken: () => accessToken,
      );
      final pushSync = PushSync(db, syncClient);
      final engine = SyncEngine(db, pushSync, syncClient);

      await engine.runSyncCycle();
      return true;
    } catch (_) {
      // Swallow errors in background -- WorkManager will retry
      return false;
    } finally {
      await db?.close();
    }
  });
}

/// SyncScheduler manages background and foreground sync scheduling.
///
/// - WorkManager: periodic background sync every 15 min (Android reliable, iOS best-effort)
/// - connectivity_plus: immediate foreground sync on network reconnect with jitter
class SyncScheduler {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _wasDisconnected = false;
  final Random _random = Random();

  /// Optional NotificationService for PUSH-03 sync alerts.
  /// Set after initialization via [setNotificationService].
  NotificationService? _notificationService;

  /// Set the notification service for PUSH-03 local sync alerts.
  void setNotificationService(NotificationService service) {
    _notificationService = service;
  }

  /// Initialize WorkManager and register the periodic sync task.
  Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher);

    await Workmanager().registerPeriodicTask(
      _periodicSyncTask,
      _periodicSyncTask,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  /// Start listening for connectivity changes to trigger foreground sync.
  ///
  /// On reconnect (transition from disconnected to connected), applies a
  /// random 0-60 second jitter delay before triggering sync. This prevents
  /// "sync storms" when a cell tower comes back online and many devices
  /// reconnect simultaneously.
  void startConnectivityListener() {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) async {
      final isConnected =
          results.any((r) => r != ConnectivityResult.none);

      if (!isConnected) {
        _wasDisconnected = true;
        return;
      }

      // Only trigger sync on reconnect (was disconnected, now connected)
      if (_wasDisconnected && isConnected) {
        _wasDisconnected = false;

        // PUSH-03: Check pending outbox count and show local notification
        if (_notificationService != null) {
          try {
            final engine = SyncEngine.instance;
            if (engine != null) {
              final pendingCount =
                  await engine.db.syncDao.getPendingCount();
              if (pendingCount > 0) {
                await _notificationService!.showSyncAlert(pendingCount);
              }
            }
          } catch (_) {
            // Non-critical: sync alert failed, continue with sync
          }
        }

        // Apply jitter: random 0-60 second delay to prevent sync storms
        final jitterMs = _random.nextInt(60000);
        await Future<void>.delayed(Duration(milliseconds: jitterMs));

        // Trigger sync if engine is available
        await SyncEngine.instance?.runSyncCycle();
      }
    });
  }

  /// Cancel all scheduled tasks and listeners.
  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    await Workmanager().cancelByUniqueName(_periodicSyncTask);
  }
}

/// Riverpod provider for SyncScheduler.
final syncSchedulerProvider = Provider<SyncScheduler>((ref) {
  return SyncScheduler();
});
