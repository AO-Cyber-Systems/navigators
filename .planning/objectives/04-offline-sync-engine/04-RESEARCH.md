# Objective 4: Offline Sync Engine - Research

**Researched:** 2026-04-10
**Domain:** Flutter offline-first architecture, Drift ORM, encrypted SQLite, sync protocols
**Confidence:** HIGH

## Summary

Objective 4 implements the core offline-first capability for Navigators: Navigators download their turf data (voters, map tiles, contact logs, tasks) before going into the field, work entirely offline, and have data automatically sync back when connectivity returns. This is critical for rural Maine where cellular coverage is unreliable.

The standard approach uses Drift (Flutter's type-safe SQLite ORM) with SQLite3MultipleCiphers for AES-256 encryption at rest. The sync protocol follows an operation-log pattern: field interactions are written to a local `sync_operations` queue table, and a background sync engine pushes pending operations to the server when connectivity is available. Pull sync uses cursor-based delta sync to download only changes since last sync.

**Primary recommendation:** Use Drift 2.32+ with `drift_flutter` 0.3+ for the local database, SQLite3MultipleCiphers for encryption (NOT the deprecated `sqlcipher_flutter_libs`), an operation-log outbox pattern for push sync, and cursor-based delta sync for pull. Use `connectivity_plus` for network monitoring and `workmanager` for background sync scheduling. Sync RPCs use standard ConnectRPC unary calls (batched), NOT streaming -- streaming adds complexity without benefit for this use case.

<phase_requirements>
## Objective Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SYNC-01 | Navigator can download turf data (voters, map tiles, tasks, scripts) before going into field | Drift tables mirror server data; bulk download via batched unary RPCs scoped to assigned turfs; FMTC already handles map tiles |
| SYNC-02 | All field interactions stored locally in Drift/SQLite and persist through app restarts | Drift with `drift_flutter` provides persistent SQLite storage; tables for contact_logs, survey_responses, notes with `synced` flag |
| SYNC-03 | Local voter data encrypted at rest via sqlcipher (AES-256) | SQLite3MultipleCiphers bundled via `sqlite3: source: sqlite3mc` in pubspec hooks; PRAGMA key on database open |
| SYNC-04 | Background sync when connectivity available with operation-log pattern | `sync_operations` outbox table; `workmanager` for background scheduling; `connectivity_plus` for network detection; batched push via ConnectRPC unary calls |
| SYNC-05 | Conflict resolution via last-write-wins with server timestamps for concurrent edits | Server-authoritative timestamps on all mutable entities; `updated_at` comparison; contact_logs are append-only (no conflicts) |
| SYNC-06 | Sync status indicator -- Navigator always knows what's synced vs pending | Riverpod provider watches `sync_operations` table count; exposes pending count + last sync timestamp |
| SYNC-07 | Forced sync on app open when online | AppLifecycleListener triggers sync on resume; initial sync check in app startup flow |
</phase_requirements>

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| drift | ^2.32.1 | Type-safe SQLite ORM | Only Flutter ORM with built-in isolate support, reactive streams, schema migrations, code generation |
| drift_flutter | ^0.3.0 | Flutter-specific database opener | Handles platform paths, background isolates, `shareAcrossIsolates` for WorkManager |
| drift_dev | ^2.32.1 | Code generation for Drift | Generates type-safe query classes from table definitions |
| build_runner | ^2.13.1 | Dart code generation runner | Required by drift_dev for code generation |
| connectivity_plus | ^7.0.0 | Network connectivity monitoring | Official Flutter community plugin; stream-based connectivity changes |
| workmanager | ^0.5.2 | Background task scheduling | Flutter wrapper around Android WorkManager and iOS BGTaskScheduler |
| path_provider | ^2.1.5 | Platform-specific file paths | Required by drift_flutter for database file location |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| internet_connection_checker_plus | ^3.0.1 | Verify actual internet (not just WiFi) | Before sync attempts; connectivity_plus only detects network type, not internet access |
| crypto | ^3.0.6 | HMAC/hash for sync integrity | Optional: verify batch integrity during sync |

### Encryption Setup (NOT a package dependency)

SQLite3MultipleCiphers is bundled via build hooks, not a pub dependency:

```yaml
# In pubspec.yaml at workspace root
hooks:
  user_defines:
    sqlite3:
      source: sqlite3mc
```

This replaces the deprecated `sqlcipher_flutter_libs` package. The `sqlite3` package (transitive dep of `drift_flutter`) version 3.x includes SQLite3MultipleCiphers support.

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Drift | Isar | Isar is NoSQL, no SQL support, less mature migration tooling; Drift's SQL foundation matches server-side PostgreSQL schema |
| Drift | Floor | Floor generates more boilerplate, lacks built-in isolate support |
| workmanager | background_fetch | background_fetch has less control over constraints and retry policies |
| connectivity_plus | dart:io InternetAddress.lookup | Lower-level, no stream API, platform-inconsistent |
| SQLite3MultipleCiphers | sqlcipher_flutter_libs | sqlcipher_flutter_libs is DEPRECATED as of drift 2.32.0; do NOT use |

**Installation:**
```bash
flutter pub add drift drift_flutter connectivity_plus workmanager path_provider internet_connection_checker_plus
flutter pub add --dev drift_dev build_runner
```

## Architecture Patterns

### Recommended Project Structure

```
navigators-flutter/lib/src/
  database/
    database.dart              # @DriftDatabase definition, opens encrypted DB
    database.g.dart            # Generated code
    tables/
      voters.dart              # Voters table (mirrors server schema)
      contact_logs.dart        # Contact logs table (field interactions)
      sync_operations.dart     # Operation log / outbox table
      turfs.dart               # Turf metadata + boundary cache
      survey_responses.dart    # Door knock survey answers
      sync_cursors.dart        # Track last-sync cursor per entity type
    daos/
      voter_dao.dart           # Voter queries (search, filter, by-turf)
      sync_dao.dart            # Sync queue operations (enqueue, dequeue, count pending)
      contact_log_dao.dart     # Contact log CRUD
  sync/
    sync_engine.dart           # Orchestrates push/pull sync cycle
    sync_scheduler.dart        # WorkManager + connectivity_plus integration
    sync_status.dart           # Riverpod providers for sync state
    push_sync.dart             # Reads outbox, batches to server
    pull_sync.dart             # Cursor-based delta download
    conflict_resolver.dart     # Last-write-wins logic
  services/
    voter_service.dart         # MODIFIED: reads from local DB first, falls back to network
    map_service.dart           # MODIFIED: reads from local DB for offline turf data
    tile_cache_service.dart    # UNCHANGED: already handles offline tiles via FMTC
```

### Pattern 1: Operation Log / Transactional Outbox

**What:** Every write operation in the field is recorded as an entry in a `sync_operations` table alongside the actual data write, in a single database transaction. The sync engine later reads this table and pushes operations to the server in order.

**When to use:** All field-generated data (contact logs, survey responses, notes, tag assignments).

**Example:**
```dart
// Table definition
class SyncOperations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityType => text()();        // 'contact_log', 'survey_response', 'note'
  TextColumn get entityId => text()();          // UUID of the created/updated entity
  TextColumn get operationType => text()();     // 'create', 'update', 'delete'
  BlobColumn get payload => blob()();           // JSON-encoded operation data
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending, in_progress, failed
}

// Writing a contact log with outbox entry in one transaction
Future<void> recordContactLog(ContactLogCompanion log) async {
  await database.transaction(() async {
    final id = await database.into(database.contactLogs).insert(log);
    await database.into(database.syncOperations).insert(
      SyncOperationsCompanion.insert(
        entityType: 'contact_log',
        entityId: id.toString(),
        operationType: 'create',
        payload: Uint8List.fromList(utf8.encode(jsonEncode(log.toJson()))),
      ),
    );
  });
}
```

### Pattern 2: Cursor-Based Delta Pull Sync

**What:** Each entity type has a sync cursor (timestamp or sequence number). Pull sync requests "give me everything changed since cursor X" from the server, scoped to the Navigator's assigned turfs.

**When to use:** Downloading voter data, turf metadata, task assignments, scripts.

**Example:**
```dart
// Table definition
class SyncCursors extends Table {
  TextColumn get entityType => text()();  // Primary key
  TextColumn get cursor => text()();       // ISO timestamp or sequence number
  DateTimeColumn get lastSyncAt => dateTime()();

  @override
  Set<Column> get primaryKey => {entityType};
}

// Pull sync for voters
Future<void> pullVoterUpdates() async {
  final cursorRow = await (database.select(database.syncCursors)
    ..where((t) => t.entityType.equals('voters')))
    .getSingleOrNull();

  final cursor = cursorRow?.cursor ?? '';  // Empty = full sync

  // Unary RPC call with cursor
  final response = await syncClient.pullVoterUpdates(
    PullVoterUpdatesRequest(
      sinceCursor: cursor,
      turfIds: assignedTurfIds,
      batchSize: 500,
    ),
  );

  await database.batch((batch) {
    for (final voter in response.voters) {
      batch.insert(
        database.voters,
        voter.toCompanion(),
        mode: InsertMode.insertOrReplace,
      );
    }
  });

  // Update cursor
  await database.into(database.syncCursors).insertOnConflictUpdate(
    SyncCursorsCompanion.insert(
      entityType: 'voters',
      cursor: response.nextCursor,
      lastSyncAt: DateTime.now(),
    ),
  );
}
```

### Pattern 3: Repository Pattern with Offline-First Reads

**What:** Service layer reads from local Drift DB first, returns cached data immediately. Network calls update the local DB, and Drift's reactive streams auto-update the UI.

**When to use:** All read operations in the app.

**Example:**
```dart
// Voter repository provides stream from local DB
Stream<List<LocalVoter>> watchVotersInTurf(String turfId) {
  return (database.select(database.voters)
    ..where((v) => v.turfId.equals(turfId))
    ..orderBy([(v) => OrderingTerm.asc(v.walkSequence)]))
    .watch();
}
```

### Anti-Patterns to Avoid

- **Direct network calls for field data:** Never call the API for data that should be locally cached. The walk list screen currently calls `mapService.generateWalkList()` over HTTP -- this MUST read from local DB when offline.
- **Syncing entire dataset on every sync:** Always use cursor-based delta sync. A turf may have 2000 voters; re-downloading all of them every sync wastes battery and bandwidth.
- **Storing encryption key in plain text:** The SQLCipher passphrase should be derived from user credentials or stored in platform secure storage (Keychain on iOS, EncryptedSharedPreferences on Android).
- **Sync during active field work:** Sync should be non-blocking. Never show a blocking spinner during sync -- the user may be at a door. Use background sync and update UI reactively via Drift streams.
- **Single giant sync operation:** Break sync into phases (pull metadata first, then voters, then push pending). If connectivity drops mid-sync, partial progress is preserved.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| SQLite ORM / query building | Raw SQL strings | Drift | Type safety, code gen, reactive streams, migration tooling |
| Encryption at rest | Manual file encryption | SQLite3MultipleCiphers via Drift | Transparent encryption, no app-level encrypt/decrypt, battle-tested AES-256 |
| Background task scheduling | Manual timers / isolate spawning | workmanager | OS-level scheduling, survives app kill, respects battery optimization |
| Network monitoring | Periodic ping checks | connectivity_plus + internet_connection_checker_plus | Stream-based, platform-native, handles edge cases (captive portals) |
| Offline map tiles | Manual tile downloading | FMTC (already in use) | Already implemented in TileCacheService; no changes needed |
| Database isolate management | Manual isolate communication | drift_flutter shareAcrossIsolates | Handles IsolateNameServer, connection pooling, cleanup |

**Key insight:** The sync protocol itself (operation log + cursor-based pull) is custom but follows a well-established pattern. The building blocks (Drift, WorkManager, connectivity monitoring) should NOT be custom. The only custom code should be the sync orchestration logic and the server-side sync RPC handlers.

## Common Pitfalls

### Pitfall 1: Database Access from WorkManager Isolate
**What goes wrong:** WorkManager callback runs in a separate isolate. Attempting to access the main isolate's database instance crashes or deadlocks.
**Why it happens:** Dart isolates don't share memory. A database opened in the main isolate is not accessible from a WorkManager isolate.
**How to avoid:** Use `drift_flutter`'s `shareAcrossIsolates: true` in `DriftNativeOptions`. This creates a shared database isolate accessible from both main and background isolates via `IsolateNameServer`.
**Warning signs:** "Bad state: No element" errors in background tasks, or silent sync failures.

### Pitfall 2: Encryption Key Management
**What goes wrong:** Storing the SQLCipher passphrase in SharedPreferences (unencrypted) defeats the purpose of encryption.
**Why it happens:** Developers need the key available before opening the DB but don't want to prompt the user every time.
**How to avoid:** Store the encryption key in Flutter Secure Storage (uses iOS Keychain / Android EncryptedSharedPreferences). Derive the key from user credentials during login, store in secure storage, retrieve on app open.
**Warning signs:** Key visible in app data inspection, key lost on secure storage clear (need re-download).

### Pitfall 3: Sync Ordering and Idempotency
**What goes wrong:** Operations pushed out of order cause data inconsistency. Retried operations create duplicates.
**Why it happens:** Network failures mid-batch cause partial pushes. Retrying the batch re-sends already-processed operations.
**How to avoid:** Each sync operation has a client-generated UUID. Server uses upsert (INSERT ON CONFLICT) keyed on this UUID. Operations are processed in creation order. Server returns which UUIDs were processed so the client can dequeue them.
**Warning signs:** Duplicate contact logs, operations stuck in "in_progress" state.

### Pitfall 4: iOS Background Limitations
**What goes wrong:** Background sync never runs on iOS, or runs once and stops.
**Why it happens:** iOS BGTaskScheduler is "best effort" -- the OS decides when/if to run background tasks based on battery, usage patterns, and system load. Minimum interval is ~15 minutes and not guaranteed.
**How to avoid:** Do NOT rely solely on background sync for iOS. Implement aggressive foreground sync: sync on app open (SYNC-07), sync on connectivity change, sync when navigating between screens. Background sync is a bonus, not the primary mechanism.
**Warning signs:** iOS users showing large pending sync queues after overnight.

### Pitfall 5: Large Initial Download Blocking UI
**What goes wrong:** First turf download of 2000+ voters freezes the app.
**Why it happens:** Drift batch inserts on the main isolate block the UI thread.
**How to avoid:** Use `drift_flutter`'s background isolate support (`createInBackground`). Show download progress. Break downloads into pages (500 voters per batch). Use `database.batch()` for bulk inserts (single transaction, much faster than individual inserts).
**Warning signs:** ANR dialogs on Android, frozen UI during "Preparing offline data."

### Pitfall 6: Stale Sync Cursors After Re-Assignment
**What goes wrong:** Navigator gets reassigned to a different turf but still has old turf's data and cursors.
**Why it happens:** Sync cursors are per-entity-type, not per-turf. Turf reassignment isn't detected.
**How to avoid:** On app open, fetch current turf assignments from server. If assignments changed, clear local data for removed turfs and reset cursors for new turfs. Track turf assignments in a local table.
**Warning signs:** Navigator sees voters from old turf, or new turf shows empty.

## Code Examples

### Database Definition with Encryption

```dart
// database.dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

part 'database.g.dart';

@DriftDatabase(tables: [
  Voters, ContactLogs, SyncOperations, SyncCursors,
  Turfs, SurveyResponses, TurfAssignments,
])
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
      // Step-by-step migrations will go here
    },
    beforeOpen: (details) async {
      // Enable WAL mode for better concurrent read/write
      await customStatement('PRAGMA journal_mode=WAL');
      // Enable foreign keys
      await customStatement('PRAGMA foreign_keys=ON');
    },
  );

  /// Factory: creates encrypted database with background isolate
  static NavigatorsDatabase create(String encryptionKey) {
    return NavigatorsDatabase(
      driftDatabase(
        name: 'navigators',
        native: DriftNativeOptions(
          shareAcrossIsolates: true,  // Allows WorkManager access
          databaseDirectory: getApplicationSupportDirectory,
          setup: (rawDb) {
            // Verify cipher is available
            final result = rawDb.select('PRAGMA cipher;');
            assert(result.isNotEmpty, 'SQLite3MultipleCiphers not available');
            // Set encryption key
            rawDb.execute("PRAGMA key = '$encryptionKey';");
          },
        ),
      ),
    );
  }
}
```

### Voters Table Definition

```dart
// tables/voters.dart
import 'package:drift/drift.dart';

/// Local cache of voter data from assigned turfs.
/// Mirrors server schema but includes sync metadata.
class Voters extends Table {
  TextColumn get id => text()();                    // Server UUID
  TextColumn get turfId => text()();                // Which turf this voter belongs to
  TextColumn get firstName => text()();
  TextColumn get lastName => text()();
  TextColumn get middleName => text().withDefault(const Constant(''))();
  TextColumn get suffix => text().withDefault(const Constant(''))();
  IntColumn get yearOfBirth => integer().nullable()();
  TextColumn get resStreetAddress => text().withDefault(const Constant(''))();
  TextColumn get resCity => text().withDefault(const Constant(''))();
  TextColumn get resState => text().withDefault(const Constant(''))();
  TextColumn get resZip => text().withDefault(const Constant(''))();
  TextColumn get party => text().withDefault(const Constant(''))();
  TextColumn get status => text().withDefault(const Constant(''))();
  RealColumn get latitude => real().withDefault(const Constant(0.0))();
  RealColumn get longitude => real().withDefault(const Constant(0.0))();
  TextColumn get votingHistory => text().withDefault(const Constant('[]'))();
  TextColumn get phone => text().withDefault(const Constant(''))();
  TextColumn get email => text().withDefault(const Constant(''))();
  IntColumn get walkSequence => integer().withDefault(const Constant(0))();
  DateTimeColumn get serverUpdatedAt => dateTime()(); // Server timestamp for LWW
  DateTimeColumn get localUpdatedAt => dateTime()();  // When we last wrote locally

  @override
  Set<Column> get primaryKey => {id};
}
```

### Sync Operation Enqueue + Push

```dart
// sync/push_sync.dart

/// Push pending operations to server in batches.
Future<int> pushPendingOperations(NavigatorsDatabase db, SyncClient client) async {
  final pending = await (db.select(db.syncOperations)
    ..where((t) => t.status.equals('pending'))
    ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
    ..limit(50))
    .get();

  if (pending.isEmpty) return 0;

  // Mark as in_progress
  final ids = pending.map((op) => op.id).toList();
  await (db.update(db.syncOperations)
    ..where((t) => t.id.isIn(ids)))
    .write(const SyncOperationsCompanion(status: Value('in_progress')));

  try {
    // Batch push via unary RPC
    final response = await client.pushSyncBatch(PushSyncBatchRequest(
      operations: pending.map((op) => SyncOperation(
        clientOperationId: op.id.toString(),
        entityType: op.entityType,
        entityId: op.entityId,
        operationType: op.operationType,
        payload: op.payload,
        clientTimestamp: op.createdAt.toIso8601String(),
      )).toList(),
    ));

    // Dequeue successfully processed operations
    final processedIds = response.processedOperationIds
        .map((id) => int.parse(id))
        .toList();
    await (db.delete(db.syncOperations)
      ..where((t) => t.id.isIn(processedIds)))
      .go();

    // Mark failures for retry
    final failedIds = ids.where((id) => !processedIds.contains(id)).toList();
    if (failedIds.isNotEmpty) {
      await (db.update(db.syncOperations)
        ..where((t) => t.id.isIn(failedIds)))
        .write(const SyncOperationsCompanion(
          status: Value('pending'),
          // retryCount incremented via custom expression
        ));
    }

    return processedIds.length;
  } catch (e) {
    // Reset to pending on network failure
    await (db.update(db.syncOperations)
      ..where((t) => t.id.isIn(ids)))
      .write(const SyncOperationsCompanion(status: Value('pending')));
    rethrow;
  }
}
```

### WorkManager Background Sync Setup

```dart
// sync/sync_scheduler.dart
import 'package:workmanager/workmanager.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

const _syncTaskName = 'navigators_background_sync';

/// Top-level function required by WorkManager (runs in separate isolate)
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == _syncTaskName) {
      // Database accessible because shareAcrossIsolates: true
      final db = NavigatorsDatabase.create(await _getEncryptionKey());
      try {
        final engine = SyncEngine(db);
        await engine.runSyncCycle();
        return true;
      } finally {
        await db.close();
      }
    }
    return false;
  });
}

class SyncScheduler {
  final Connectivity _connectivity = Connectivity();

  Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher);

    // Register periodic background sync (minimum 15 min on Android)
    await Workmanager().registerPeriodicTask(
      _syncTaskName,
      _syncTaskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );

    // Also listen for connectivity changes for immediate foreground sync
    _connectivity.onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) {
        // Trigger immediate foreground sync
        SyncEngine.instance?.runSyncCycle();
      }
    });
  }
}
```

### Sync Status Provider

```dart
// sync/sync_status.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SyncStatus {
  final int pendingOperations;
  final DateTime? lastSyncAt;
  final bool isSyncing;
  final String? lastError;

  const SyncStatus({
    this.pendingOperations = 0,
    this.lastSyncAt,
    this.isSyncing = false,
    this.lastError,
  });

  bool get hasPending => pendingOperations > 0;
  bool get isFullySynced => pendingOperations == 0 && lastError == null;
}

// Watches the sync_operations table count reactively
final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final db = ref.watch(databaseProvider);
  // Drift's .watch() emits new value whenever table changes
  final pendingCount = db.syncOperations.count(
    where: (t) => t.status.equals('pending') | t.status.equals('in_progress'),
  );
  return pendingCount.watchSingle().map((count) => SyncStatus(
    pendingOperations: count,
    lastSyncAt: /* read from sync_cursors */,
  ));
});
```

## Server-Side Sync RPCs (Go/ConnectRPC)

### Proto Definition for Sync Service

```protobuf
service SyncService {
  // Pull: Client requests changes since cursor, scoped to their turfs
  rpc PullVoterUpdates(PullVoterUpdatesRequest) returns (PullVoterUpdatesResponse);
  rpc PullTurfMetadata(PullTurfMetadataRequest) returns (PullTurfMetadataResponse);

  // Push: Client sends batch of operations from outbox
  rpc PushSyncBatch(PushSyncBatchRequest) returns (PushSyncBatchResponse);

  // Check: Client asks what assignments have changed
  rpc GetSyncManifest(GetSyncManifestRequest) returns (GetSyncManifestResponse);
}

message PullVoterUpdatesRequest {
  string since_cursor = 1;     // ISO timestamp or empty for full sync
  repeated string turf_ids = 2; // Scoped to assigned turfs
  int32 batch_size = 3;         // Max voters per response (default 500)
}

message PullVoterUpdatesResponse {
  repeated SyncVoter voters = 1;
  string next_cursor = 2;       // Use as since_cursor in next call
  bool has_more = 3;            // More pages available
}

message PushSyncBatchRequest {
  repeated SyncOperation operations = 1;
}

message PushSyncBatchResponse {
  repeated string processed_operation_ids = 1;  // Client UUIDs that succeeded
  repeated SyncError errors = 2;                 // Failures with reasons
}
```

**Design decision: Unary RPCs, not streaming.** Server-streaming would add complexity (connection management, partial failure recovery, HTTP/2 requirement) for minimal benefit. Batched unary calls with cursor-based pagination achieve the same result with simpler error handling and work over HTTP/1.1 with the Connect protocol.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `sqlcipher_flutter_libs` for encryption | SQLite3MultipleCiphers via `sqlite3: source: sqlite3mc` hook | drift 2.32.0 (2025) | `sqlcipher_flutter_libs` is DEPRECATED; must use new approach |
| Manual isolate management for background DB | `drift_flutter` `shareAcrossIsolates: true` | drift_flutter 0.3.0 (2025) | Eliminates manual IsolateNameServer code |
| `NativeDatabase(File(...))` | `driftDatabase(name: ..., native: DriftNativeOptions(...))` | drift_flutter 0.2+ | Handles platform paths automatically |
| `connectivity` package | `connectivity_plus` ^7.0.0 | 2024 | Old package unmaintained; plus version is Flutter community standard |

**Deprecated/outdated:**
- `sqlcipher_flutter_libs`: Removed in favor of SQLite3MultipleCiphers. Do NOT add this package.
- `encrypted_drift` / `sqflite_sqlcipher`: Alternative approach but less recommended; uses sqflite backend instead of native sqlite3.
- `moor` / `moor_flutter`: Old name for Drift. All APIs renamed.

## Open Questions

1. **Encryption Key Derivation Strategy**
   - What we know: Key must be available before DB open, must survive app restarts, must not be plain text.
   - What's unclear: Should the key be derived from user password (ties DB to auth), server-provided per-device, or randomly generated and stored in secure storage?
   - Recommendation: Generate random key on first login, store in `flutter_secure_storage`. If user logs out, key is cleared and DB is deleted. Simple, secure, no password dependency.

2. **Turf Reassignment During Field Work**
   - What we know: Admins can reassign turfs at any time. Navigator may have local data for old turf.
   - What's unclear: Should old turf data be deleted immediately, or kept until next full sync?
   - Recommendation: On sync, compare server turf assignments to local. For removed turfs: keep pending sync operations (push first), then delete local voter data for that turf. Prevents data loss.

3. **Conflict Window for Concurrent Edits**
   - What we know: Last-write-wins with server timestamps. Contact logs are append-only.
   - What's unclear: What if two Navigators are assigned to the same turf and contact the same voter? Both create contact_logs -- no conflict (append-only). But what about survey responses?
   - Recommendation: Survey responses should also be append-only (each visit creates a new response). Voter-level metadata edits (tags, notes) use LWW with server timestamp. This eliminates most real-world conflicts.

4. **Full Re-Sync Trigger**
   - What we know: Cursor-based sync works for incremental updates. But cursors can become invalid (server data migration, etc.).
   - What's unclear: How to detect when a full re-sync is needed.
   - Recommendation: Server returns a `cursor_valid: false` flag when cursor is too old or invalid. Client resets cursor and does full pull for that entity type. Also allow manual "re-download" from UI.

## Sources

### Primary (HIGH confidence)
- [Drift Official Docs - Setup](https://drift.simonbinder.eu/setup/) - Table definitions, database creation, drift_flutter setup
- [Drift Official Docs - Encryption](https://drift.simonbinder.eu/platforms/encryption/) - SQLite3MultipleCiphers setup, PRAGMA key, migration from sqlcipher_flutter_libs
- [Drift Official Docs - Isolates](https://drift.simonbinder.eu/isolates/) - shareAcrossIsolates, background isolate patterns, DriftIsolate
- [Drift Official Docs - Migrations](https://drift.simonbinder.eu/migrations/) - Schema versioning, onUpgrade, step-by-step migrations
- [Drift Official Docs - Tables](https://drift.simonbinder.eu/dart_api/tables/) - Column types, constraints, indexes, composite primary keys
- [drift_flutter pub.dev](https://pub.dev/packages/drift_flutter) - v0.3.0, DriftNativeOptions API
- [ConnectRPC Dart Client](https://connectrpc.com/docs/dart/using-clients/) - Streaming support, transport types
- [ConnectRPC Go Streaming](https://connectrpc.com/docs/go/streaming/) - Server-streaming handler implementation
- [Flutter Official - Offline-First Architecture](https://docs.flutter.dev/app-architecture/design-patterns/offline-first) - Repository pattern, sync strategies

### Secondary (MEDIUM confidence)
- [connectivity_plus pub.dev](https://pub.dev/packages/connectivity_plus) - v7.0.0, stream API
- [workmanager pub.dev](https://pub.dev/packages/workmanager) - v0.5.2, periodic tasks, constraints
- [internet_connection_checker_plus pub.dev](https://pub.dev/packages/internet_connection_checker_plus) - v3.0.1, actual internet verification

### Tertiary (LOW confidence)
- [GeekyAnts - Offline-First Flutter Blueprint](https://geekyants.com/blog/offline-first-flutter-implementation-blueprint-for-real-world-apps) - Transactional outbox pattern details
- [Dev.to - Offline-First Architecture Parts 1 & 2](https://dev.to/anurag_dev/implementing-offline-first-architecture-in-flutter-part-2-building-sync-mechanisms-and-handling-4mb1) - Sync mechanism patterns

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Drift, drift_flutter, SQLite3MultipleCiphers are well-documented with official docs verified
- Architecture: HIGH - Operation log / outbox pattern is industry standard; Flutter official docs endorse repository pattern
- Encryption: HIGH - SQLite3MultipleCiphers setup verified from official Drift encryption docs
- Sync protocol: MEDIUM - Custom implementation following established patterns; no off-the-shelf solution fits exactly
- WorkManager iOS reliability: MEDIUM - iOS background execution is inherently unreliable; mitigation strategies documented
- Pitfalls: HIGH - Well-known issues in offline-first Flutter development, verified across multiple sources

**Research date:** 2026-04-10
**Valid until:** 2026-05-10 (30 days - Drift ecosystem is stable)
