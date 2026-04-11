import 'package:drift/drift.dart';

/// Per-entity sync cursor tracking.
/// Tracks the last sync position for each entity type (voters, contact_logs, etc.).
class SyncCursors extends Table {
  TextColumn get entityType => text()(); // Primary key: 'voters', 'contact_logs', etc.
  TextColumn get cursor => text()(); // ISO timestamp or sequence number
  DateTimeColumn get lastSyncAt => dateTime()();

  @override
  Set<Column> get primaryKey => {entityType};
}
