import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Local-only notification service using flutter_local_notifications.
///
/// Remote push (Firebase Cloud Messaging) was descoped in objective 08-04.
/// PUSH-01/02/03 are reinterpreted as local-only notifications:
/// - PUSH-01 (task assignment): surfaced in-app via ListTasks / pull sync.
/// - PUSH-02 (task reminder): surfaced in-app on the Tasks tab.
/// - PUSH-03 (sync-ready local alert): via [showSyncAlert] below.
///
/// If real-time remote push is ever required, a dedicated objective
/// (e.g., 11-push-notifications) will re-introduce it cleanly.
class NotificationService {
  FlutterLocalNotificationsPlugin? _plugin;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  /// Initialize the local-notifications plugin and create Android channels.
  /// Degrades gracefully if initialization fails.
  Future<void> initialize() async {
    try {
      _plugin = FlutterLocalNotificationsPlugin();
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings();
      await _plugin!.initialize(
        const InitializationSettings(android: android, iOS: ios),
      );

      final androidPlugin = _plugin!
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'tasks',
            'Task Notifications',
            description:
                'Notifications for task assignments and reminders',
            importance: Importance.high,
          ),
        );
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'sync',
            'Sync Alerts',
            description: 'Notifications when data is ready to sync',
            importance: Importance.defaultImportance,
          ),
        );
      }
      _initialized = true;
    } catch (_) {
      // Degrade gracefully; app continues without notifications.
      _initialized = true;
    }
  }

  /// Show a local task notification (assignment, reminder, etc.).
  /// Callers supply a stable [id] so re-notifying replaces rather than stacks.
  Future<void> showTaskNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (_plugin == null) return;
    await _plugin!.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'tasks',
          'Task Notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// PUSH-03 (local-only): notify the user that the outbox has pending items.
  ///
  /// Called by SyncScheduler when the device reconnects and outbox is non-empty.
  Future<void> showSyncAlert(int pendingCount) async {
    if (_plugin == null || pendingCount == 0) return;

    await _plugin!.show(
      0, // Fixed ID -- replaces previous sync alert
      'Data Ready to Sync',
      '$pendingCount change${pendingCount == 1 ? '' : 's'} waiting to upload',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'sync',
          'Sync Alerts',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}

/// Riverpod provider for [NotificationService].
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
