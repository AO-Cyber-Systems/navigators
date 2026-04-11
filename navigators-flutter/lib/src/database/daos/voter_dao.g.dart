// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'voter_dao.dart';

// ignore_for_file: type=lint
mixin _$VoterDaoMixin on DatabaseAccessor<NavigatorsDatabase> {
  $VotersTable get voters => attachedDatabase.voters;
  VoterDaoManager get managers => VoterDaoManager(this);
}

class VoterDaoManager {
  final _$VoterDaoMixin _db;
  VoterDaoManager(this._db);
  $$VotersTableTableManager get voters =>
      $$VotersTableTableManager(_db.attachedDatabase, _db.voters);
}
