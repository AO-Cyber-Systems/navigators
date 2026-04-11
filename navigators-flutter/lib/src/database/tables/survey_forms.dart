import 'package:drift/drift.dart';

/// Local survey form storage, pulled from server.
/// Survey forms are admin-created and synced to devices for offline use.
class SurveyForms extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text()();
  TextColumn get title => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get schema => text()(); // JSON string of form definition
  IntColumn get version => integer().withDefault(const Constant(1))();
  BoolColumn get isActive =>
      boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
