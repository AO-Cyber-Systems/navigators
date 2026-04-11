import 'package:drift/drift.dart';

/// Local voter note storage for offline-created notes.
/// Notes created offline have syncedAt == null until pushed to server.
class VoterNotes extends Table {
  TextColumn get id => text()();
  TextColumn get voterId => text()();
  TextColumn get userId => text()();
  TextColumn get turfId => text()();
  TextColumn get content => text()();
  TextColumn get visibility =>
      text().withDefault(const Constant('team'))(); // private, team, org
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
