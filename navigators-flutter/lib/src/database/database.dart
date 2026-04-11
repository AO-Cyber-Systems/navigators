import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'tables/voters.dart';
import 'tables/contact_logs.dart';
import 'tables/sync_operations.dart';
import 'tables/sync_cursors.dart';
import 'tables/turf_assignments.dart';
import 'daos/voter_dao.dart';
import 'daos/sync_dao.dart';
import 'daos/contact_log_dao.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Voters,
    ContactLogs,
    SyncOperations,
    SyncCursors,
    TurfAssignments,
  ],
  daos: [
    VoterDao,
    SyncDao,
    ContactLogDao,
  ],
)
class NavigatorsDatabase extends _$NavigatorsDatabase {
  NavigatorsDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          // Step-by-step migrations will go here as schema evolves
        },
        beforeOpen: (details) async {
          // Enable WAL mode for better concurrent read/write performance
          await customStatement('PRAGMA journal_mode=WAL');
          // Enable foreign keys
          await customStatement('PRAGMA foreign_keys=ON');
        },
      );

  /// Factory: creates encrypted database with background isolate support.
  ///
  /// The [encryptionKey] is retrieved from flutter_secure_storage before
  /// calling this factory. SQLite3MultipleCiphers encrypts the database
  /// with AES-256 using PRAGMA key.
  static NavigatorsDatabase create(String encryptionKey) {
    return NavigatorsDatabase(
      driftDatabase(
        name: 'navigators',
        native: DriftNativeOptions(
          shareAcrossIsolates: true,
          databaseDirectory: getApplicationSupportDirectory,
          setup: (rawDb) {
            // Verify that SQLite3MultipleCiphers is available
            final cipherResult = rawDb.select('PRAGMA cipher');
            assert(cipherResult.isNotEmpty,
                'SQLite3MultipleCiphers is not available. '
                'Check pubspec.yaml hooks section has sqlite3: source: sqlite3mc');
            // Set the encryption key (AES-256)
            rawDb.execute("PRAGMA key = '$encryptionKey'");
          },
        ),
      ),
    );
  }
}

/// Riverpod provider for the encrypted Drift database.
///
/// This provider must be overridden in main.dart after retrieving the
/// encryption key from flutter_secure_storage:
///
/// ```dart
/// ProviderScope(
///   overrides: [
///     databaseProvider.overrideWithValue(NavigatorsDatabase.create(key)),
///   ],
///   child: const MyApp(),
/// )
/// ```
final databaseProvider = Provider<NavigatorsDatabase>((ref) {
  throw UnimplementedError(
    'databaseProvider must be overridden with NavigatorsDatabase.create(encryptionKey)',
  );
});
