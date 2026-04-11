import 'package:drift/drift.dart';

/// Local training material metadata synced from server.
/// Content is fetched on-demand from MinIO via presigned URLs.
class TrainingMaterials extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text()();
  TextColumn get title => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get contentUrl => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isPublished => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
