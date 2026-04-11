import 'package:drift/drift.dart';

/// Operation log outbox table.
/// Every field write is recorded here and pushed to server during sync.
class SyncOperations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityType => text()(); // 'contact_log', 'survey_response', etc.
  TextColumn get entityId => text()(); // UUID of the created/updated entity
  TextColumn get operationType => text()(); // 'create', 'update', 'delete'
  BlobColumn get payload => blob()(); // JSON-encoded operation data
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending, in_progress, failed
}
