import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'src/app.dart';
import 'src/database/database.dart';
import 'src/sync/sync_scheduler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // FMTC (offline tiles) only works on native platforms (not web)
  if (!kIsWeb) {
    try {
      await FMTCObjectBoxBackend().initialise();
    } catch (e) {
      debugPrint('FMTC init failed (expected on web): $e');
    }
  }

  // On web: use unencrypted in-memory database (no secure storage).
  // On native: use encrypted database from flutter_secure_storage.
  NavigatorsDatabase? database;
  SyncScheduler? scheduler;

  if (kIsWeb) {
    database = NavigatorsDatabase.createWeb();
  } else {
    const secureStorage = FlutterSecureStorage();
    final encryptionKey = await secureStorage.read(key: 'db_encryption_key');

    if (encryptionKey != null && encryptionKey.isNotEmpty) {
      database = NavigatorsDatabase.create(encryptionKey);
    }

    scheduler = SyncScheduler();
    await scheduler.initialize();
    scheduler.startConnectivityListener();
  }

  runApp(
    ProviderScope(
      overrides: [
        if (database != null)
          databaseProvider.overrideWithValue(database),
        if (scheduler != null)
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
