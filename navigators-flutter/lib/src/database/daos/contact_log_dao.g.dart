// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contact_log_dao.dart';

// ignore_for_file: type=lint
mixin _$ContactLogDaoMixin on DatabaseAccessor<NavigatorsDatabase> {
  $ContactLogsTable get contactLogs => attachedDatabase.contactLogs;
  ContactLogDaoManager get managers => ContactLogDaoManager(this);
}

class ContactLogDaoManager {
  final _$ContactLogDaoMixin _db;
  ContactLogDaoManager(this._db);
  $$ContactLogsTableTableManager get contactLogs =>
      $$ContactLogsTableTableManager(_db.attachedDatabase, _db.contactLogs);
}
