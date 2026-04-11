import 'package:drift/drift.dart';

/// Local event storage synced from server.
/// Events are pulled from server and stored locally for offline access.
class Events extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text()();
  TextColumn get title => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get eventType => text()(); // canvass, phone_bank, meeting, other
  TextColumn get status => text().withDefault(const Constant('scheduled'))();
  DateTimeColumn get startsAt => dateTime()();
  DateTimeColumn get endsAt => dateTime()();
  TextColumn get locationName => text().nullable()();
  RealColumn get locationLat => real().nullable()();
  RealColumn get locationLng => real().nullable()();
  TextColumn get linkedTurfId => text().nullable()();
  IntColumn get maxAttendees => integer().nullable()();
  IntColumn get rsvpCount => integer().withDefault(const Constant(0))();
  TextColumn get createdBy => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
