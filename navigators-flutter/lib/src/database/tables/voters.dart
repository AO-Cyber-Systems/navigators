import 'package:drift/drift.dart';

/// Local cache of voter data from assigned turfs.
/// Mirrors server schema but includes sync metadata.
class Voters extends Table {
  TextColumn get id => text()();
  TextColumn get turfId => text()();
  TextColumn get firstName => text()();
  TextColumn get lastName => text()();
  TextColumn get middleName => text().withDefault(const Constant(''))();
  TextColumn get suffix => text().withDefault(const Constant(''))();
  IntColumn get yearOfBirth => integer().nullable()();
  TextColumn get resStreetAddress => text().withDefault(const Constant(''))();
  TextColumn get resCity => text().withDefault(const Constant(''))();
  TextColumn get resState => text().withDefault(const Constant(''))();
  TextColumn get resZip => text().withDefault(const Constant(''))();
  TextColumn get party => text().withDefault(const Constant(''))();
  TextColumn get status => text().withDefault(const Constant(''))();
  RealColumn get latitude => real().withDefault(const Constant(0.0))();
  RealColumn get longitude => real().withDefault(const Constant(0.0))();
  TextColumn get votingHistory => text().withDefault(const Constant('[]'))();
  TextColumn get phone => text().withDefault(const Constant(''))();
  TextColumn get email => text().withDefault(const Constant(''))();
  IntColumn get walkSequence => integer().withDefault(const Constant(0))();
  DateTimeColumn get serverUpdatedAt => dateTime()();
  DateTimeColumn get localUpdatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
