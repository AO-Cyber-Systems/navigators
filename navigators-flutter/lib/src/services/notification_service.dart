import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:eden_platform_flutter/eden_platform.dart';

/// NotificationService handles FCM initialization, token registration,
/// foreground/background message display, and PUSH-03 local sync alerts.
///
/// Firebase must be initialized before calling [initialize].
/// If Firebase is not configured (firebase_options.dart missing), the service
/// gracefully degrades -- push features are disabled but the app continues.
///
/// After running `flutterfire configure`, uncomment the Firebase.initializeApp
/// call in main.dart to enable push notifications.
class NotificationService {
  final String _baseUrl;
  final String? Function() _getAccessToken;
  FlutterLocalNotificationsPlugin? _localPlugin;
  bool _initialized = false;

  NotificationService({
    required String baseUrl,
    required String? Function() getAccessToken,
  })  : _baseUrl = baseUrl,
        _getAccessToken = getAccessToken;

  bool get isInitialized => _initialized;

  /// Initialize FCM and local notifications.
  ///
  /// Call after Firebase.initializeApp() has completed.
  /// Gracefully degrades if permissions denied or token unavailable.
  Future<void> initialize() async {
    try {
      // 1. Request notification permission (Android 13+ and iOS)
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        // User denied notification permission -- degrade gracefully
        await _initLocalNotifications();
        _initialized = true;
        return;
      }

      // 2. Get and register FCM token
      // Note: getToken() returns null on iOS simulator -- that's expected
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _registerToken(token);
      }

      // 3. Listen for token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen(_registerToken);

      // 4. Foreground message handling
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // 5. Notification tap handlers
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        _handleNotificationTap(initial);
      }
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // 6. Init local notifications for foreground display + PUSH-03
      await _initLocalNotifications();

      _initialized = true;
    } catch (e) {
      // Firebase not configured or other init error -- degrade gracefully.
      // The app continues without push notifications.
      // Still try to init local notifications for PUSH-03 sync alerts.
      try {
        await _initLocalNotifications();
      } catch (_) {
        // Local notifications also failed -- fully degraded mode
      }
      _initialized = true;
    }
  }

  /// Initialize flutter_local_notifications plugin.
  Future<void> _initLocalNotifications() async {
    _localPlugin = FlutterLocalNotificationsPlugin();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _localPlugin!.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    // Create notification channels for Android 8+ (Oreo)
    final androidPlugin = _localPlugin!
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'tasks',
          'Task Notifications',
          description: 'Notifications for task assignments and reminders',
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
  }

  /// Register FCM token with the server.
  /// POST to RegisterDeviceToken RPC with token + platform.
  Future<void> _registerToken(String token) async {
    try {
      final accessToken = _getAccessToken();
      if (accessToken == null) return;

      final platform = Platform.isIOS ? 'ios' : 'android';
      final url = Uri.parse(
          '$_baseUrl/navigators.v1.TaskService/RegisterDeviceToken');
      await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'token': token,
          'platform': platform,
        }),
      );
    } catch (_) {
      // Token registration failed -- will retry on next token refresh
    }
  }

  /// Handle foreground FCM message by showing a local notification.
  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null || _localPlugin == null) return;

    _localPlugin!.show(
      notification.hashCode,
      notification.title ?? 'Navigators',
      notification.body ?? '',
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

  /// Handle notification tap (from terminated or background state).
  /// Parses data payload for navigation context.
  void _handleNotificationTap(RemoteMessage message) {
    // Parse data payload for navigation (e.g., task_id -> navigate to task detail)
    // For now, log the tap -- navigation integration can be enhanced later
    final data = message.data;
    if (data.containsKey('task_id')) {
      // TODO: Navigate to task detail screen when navigation service is ready
    }
  }

  /// PUSH-03: Show local notification for pending sync data.
  ///
  /// Called by SyncScheduler when device reconnects and outbox has pending items.
  /// Uses flutter_local_notifications (not FCM) since this is client-side only.
  Future<void> showSyncAlert(int pendingCount) async {
    if (_localPlugin == null || pendingCount == 0) return;

    await _localPlugin!.show(
      0, // Fixed notification ID -- replaces previous sync alert
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

/// Riverpod provider for NotificationService.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final auth = ref.watch(authProvider);
  const envUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  final baseUrl = envUrl.isNotEmpty ? envUrl : 'http://localhost:8080';
  return NotificationService(
    baseUrl: baseUrl,
    getAccessToken: () => auth.accessToken,
  );
});
