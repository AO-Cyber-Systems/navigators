import 'package:drift/drift.dart';

/// Local task note storage for offline-created notes.
/// Notes created offline have syncedAt == null until pushed to server.
class TaskNotes extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text()();
  TextColumn get taskId => text()();
  TextColumn get userId => text()();
  TextColumn get content => text()();
  TextColumn get visibility =>
      text().withDefault(const Constant('team'))(); // team, org
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
