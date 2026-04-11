import 'package:drift/drift.dart';

/// Local call script storage, pulled from server.
/// Call scripts are admin-created text content, synced to devices for offline use.
/// Supports {{variable}} interpolation at display time (Flutter side).
class CallScripts extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text()();
  TextColumn get title => text()();
  TextColumn get content => text().withDefault(const Constant(''))();
  IntColumn get version => integer().withDefault(const Constant(1))();
  BoolColumn get isActive =>
      boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
