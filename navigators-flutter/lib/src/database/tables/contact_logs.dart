import 'package:drift/drift.dart';

/// Local contact log storage for field interactions.
/// Contact logs created offline have syncedAt == null until pushed to server.
class ContactLogs extends Table {
  TextColumn get id => text()(); // Client-generated UUID
  TextColumn get voterId => text()();
  TextColumn get turfId => text()();
  TextColumn get userId => text()();
  TextColumn get contactType => text()(); // door_knock, phone, text, other
  TextColumn get outcome => text()(); // support, oppose, undecided, not_home, refused, moved
  TextColumn get notes => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()(); // null = not yet synced

  @override
  Set<Column> get primaryKey => {id};
}
