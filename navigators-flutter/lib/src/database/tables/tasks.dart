import 'package:drift/drift.dart';

/// Local task storage synced from server.
/// Tasks are pulled from server and stored locally for offline access.
class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text()();
  TextColumn get title => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get taskType => text()(); // contact_list, event, data_entry, custom
  TextColumn get priority => text().withDefault(const Constant('medium'))();
  TextColumn get status => text().withDefault(const Constant('open'))();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get linkedEntityType => text().nullable()(); // turf, voter, voter_list
  TextColumn get linkedEntityId => text().nullable()();
  IntColumn get progressPct => integer().withDefault(const Constant(0))();
  IntColumn get totalCount => integer().withDefault(const Constant(0))();
  IntColumn get completedCount => integer().withDefault(const Constant(0))();
  TextColumn get createdBy => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
