import 'package:drift/drift.dart';

/// Local task assignment storage synced from server.
class TaskAssignments extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text()();
  TextColumn get userId => text()();
  TextColumn get assignedBy => text()();
  DateTimeColumn get assignedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
