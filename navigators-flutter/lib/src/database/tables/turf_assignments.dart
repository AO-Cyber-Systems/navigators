import 'package:drift/drift.dart';

/// Local cache of turf assignments for the current navigator.
/// Used to determine which turfs to sync data for.
class TurfAssignments extends Table {
  TextColumn get turfId => text()();
  TextColumn get turfName => text()();
  DateTimeColumn get assignedAt => dateTime()();
  TextColumn get boundaryGeojson => text()(); // For FMTC region calculation

  @override
  Set<Column> get primaryKey => {turfId};
}
