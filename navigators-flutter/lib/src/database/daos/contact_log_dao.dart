import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/contact_logs.dart';

part 'contact_log_dao.g.dart';

@DriftAccessor(tables: [ContactLogs])
class ContactLogDao extends DatabaseAccessor<NavigatorsDatabase>
    with _$ContactLogDaoMixin {
  ContactLogDao(super.db);

  /// Insert a new contact log.
  Future<int> insertContactLog(ContactLogsCompanion log) {
    return into(contactLogs).insert(log);
  }

  /// Watch contact logs for a voter, newest first.
  Stream<List<ContactLog>> watchContactLogsForVoter(String voterId) {
    return (select(contactLogs)
          ..where((t) => t.voterId.equals(voterId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// Get all contact logs that have not been synced to server.
  Future<List<ContactLog>> getUnsyncedContactLogs() {
    return (select(contactLogs)..where((t) => t.syncedAt.isNull())).get();
  }

  /// Mark a contact log as synced with server timestamp.
  Future<void> markContactLogSynced(String id, DateTime syncedAt) {
    return (update(contactLogs)..where((t) => t.id.equals(id)))
        .write(ContactLogsCompanion(syncedAt: Value(syncedAt)));
  }

  /// Bulk upsert contact logs from server pull.
  Future<void> upsertContactLogs(List<ContactLogsCompanion> logs) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(contactLogs, logs);
    });
  }
}
