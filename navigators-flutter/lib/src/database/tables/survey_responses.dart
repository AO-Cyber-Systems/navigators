import 'package:drift/drift.dart';

/// Local survey response storage for offline-created responses.
/// Responses created offline have syncedAt == null until pushed to server.
class SurveyResponses extends Table {
  TextColumn get id => text()();
  TextColumn get formId => text()();
  IntColumn get formVersion => integer()();
  TextColumn get voterId => text()();
  TextColumn get userId => text()();
  TextColumn get turfId => text()();
  TextColumn get contactLogId => text().nullable()();
  TextColumn get responsesJson => text()(); // JSON string
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
