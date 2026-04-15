import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'tables/voters.dart';
import 'tables/contact_logs.dart';
import 'tables/sync_operations.dart';
import 'tables/sync_cursors.dart';
import 'tables/turf_assignments.dart';
import 'tables/survey_forms.dart';
import 'tables/survey_responses.dart';
import 'tables/voter_notes.dart';
import 'tables/call_scripts.dart';
import 'tables/tasks.dart';
import 'tables/task_assignments.dart';
import 'tables/task_notes.dart';
import 'tables/events.dart';
import 'tables/event_rsvps.dart';
import 'tables/training_materials.dart';
import 'daos/voter_dao.dart';
import 'daos/sync_dao.dart';
import 'daos/contact_log_dao.dart';
import 'daos/survey_dao.dart';
import 'daos/voter_note_dao.dart';
import 'daos/call_script_dao.dart';
import 'daos/task_dao.dart';
import 'daos/event_dao.dart';
import 'daos/training_dao.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Voters,
    ContactLogs,
    SyncOperations,
    SyncCursors,
    TurfAssignments,
    SurveyForms,
    SurveyResponses,
    VoterNotes,
    CallScripts,
    Tasks,
    TaskAssignments,
    TaskNotes,
    Events,
    EventRsvps,
    TrainingMaterials,
  ],
  daos: [
    VoterDao,
    SyncDao,
    ContactLogDao,
    SurveyDao,
    VoterNoteDao,
    CallScriptDao,
    TaskDao,
    EventDao,
    TrainingDao,
  ],
)
class NavigatorsDatabase extends _$NavigatorsDatabase {
  NavigatorsDatabase(super.e);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(surveyForms);
            await m.createTable(surveyResponses);
            await m.createTable(voterNotes);
            await m.addColumn(contactLogs, contactLogs.doorStatus);
            await m.addColumn(contactLogs, contactLogs.sentiment);
          }
          if (from < 3) {
            await m.createTable(callScripts);
          }
          if (from < 4) {
            await m.createTable(tasks);
            await m.createTable(taskAssignments);
            await m.createTable(taskNotes);
          }
          if (from < 5) {
            await m.createTable(events);
            await m.createTable(eventRsvps);
            await m.createTable(trainingMaterials);
          }
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
  /// Create a database for web using WASM (no encryption).
  static NavigatorsDatabase createWeb() {
    return NavigatorsDatabase(
      driftDatabase(
        name: 'navigators_web',
        web: DriftWebOptions(
          sqlite3Wasm: Uri.parse('sqlite3.wasm'),
          driftWorker: Uri.parse('drift_worker.js'),
        ),
      ),
    );
  }

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
/// Mutable slot for the Drift database.
///
/// Populated either by:
///   * main.dart override (key already existed in secure storage at boot), or
///   * `_ensureDatabaseInitialized` in app.dart after first-login key
///     generation via `ref.read(databaseInitializerProvider.notifier).set(...)`.
final databaseInstanceProvider = StateProvider<NavigatorsDatabase?>((_) => null);

/// Riverpod provider for the encrypted Drift database.
///
/// Reads from [databaseInstanceProvider] and throws only if still unset.
/// main.dart's `ProviderScope` override is kept for the fast-path where the
/// encryption key was already present at app launch.
final databaseProvider = Provider<NavigatorsDatabase>((ref) {
  final db = ref.watch(databaseInstanceProvider);
  if (db != null) return db;
  throw UnimplementedError(
    'databaseProvider must be overridden with NavigatorsDatabase.create(encryptionKey)',
  );
});
