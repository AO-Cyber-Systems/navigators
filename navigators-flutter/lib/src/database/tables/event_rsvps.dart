import 'package:drift/drift.dart';

/// Local RSVP storage synced from server.
/// Tracks user RSVP status for events.
class EventRsvps extends Table {
  TextColumn get id => text()();
  TextColumn get eventId => text()();
  TextColumn get userId => text()();
  TextColumn get status => text().withDefault(const Constant('going'))();
  TextColumn get displayName => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
