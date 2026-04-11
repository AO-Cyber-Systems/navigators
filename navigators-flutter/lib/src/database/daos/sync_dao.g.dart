// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_dao.dart';

// ignore_for_file: type=lint
mixin _$SyncDaoMixin on DatabaseAccessor<NavigatorsDatabase> {
  $SyncOperationsTable get syncOperations => attachedDatabase.syncOperations;
  $SyncCursorsTable get syncCursors => attachedDatabase.syncCursors;
  SyncDaoManager get managers => SyncDaoManager(this);
}

class SyncDaoManager {
  final _$SyncDaoMixin _db;
  SyncDaoManager(this._db);
  $$SyncOperationsTableTableManager get syncOperations =>
      $$SyncOperationsTableTableManager(
        _db.attachedDatabase,
        _db.syncOperations,
      );
  $$SyncCursorsTableTableManager get syncCursors =>
      $$SyncCursorsTableTableManager(_db.attachedDatabase, _db.syncCursors);
}
