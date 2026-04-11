import 'dart:convert';
import 'dart:math';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'src/app.dart';
import 'src/database/database.dart';
import 'src/sync/sync_scheduler.dart';

/// Top-level background message handler for FCM.
///
/// MUST be a top-level function (not inside a class).
/// Runs in a separate isolate when the app is in background/terminated.
///
/// NOTE: Uncomment Firebase.initializeApp() after running `flutterfire configure`
/// to generate firebase_options.dart.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Must init Firebase in background isolate:
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Background message received -- handled by system notification tray
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FMTCObjectBoxBackend().initialise();

  // Initialize Firebase for push notifications.
  // NOTE: Uncomment after running `flutterfire configure`:
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Register background message handler (must be done before runApp)
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Retrieve encryption key from secure storage.
  // Key only exists after first login; if absent, database init is deferred
  // until the user authenticates (handled in app.dart).
  const secureStorage = FlutterSecureStorage();
  final encryptionKey = await secureStorage.read(key: 'db_encryption_key');
  NavigatorsDatabase? database;

  if (encryptionKey != null && encryptionKey.isNotEmpty) {
    database = NavigatorsDatabase.create(encryptionKey);
  }

  // Initialize WorkManager for periodic background sync
  final scheduler = SyncScheduler();
  await scheduler.initialize();
  scheduler.startConnectivityListener();

  runApp(
    ProviderScope(
      overrides: [
        if (database != null)
          databaseProvider.overrideWithValue(database),
        syncSchedulerProvider.overrideWithValue(scheduler),
      ],
      child: const NavigatorsApp(),
    ),
  );
}

/// Generate a random 32-byte encryption key encoded as base64.
/// Called on first login to create the database encryption key.
String generateEncryptionKey() {
  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  return base64Encode(bytes);
}
