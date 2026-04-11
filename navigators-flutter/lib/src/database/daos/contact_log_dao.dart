import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/contact_logs.dart';
import 'sync_dao.dart';

part 'contact_log_dao.g.dart';

@DriftAccessor(tables: [ContactLogs])
class ContactLogDao extends DatabaseAccessor<NavigatorsDatabase>
    with _$ContactLogDaoMixin {
  ContactLogDao(super.db);

  /// Insert a new contact log.
  Future<int> insertContactLog(ContactLogsCompanion log) {
    return into(contactLogs).insert(log);
  }

  /// Insert a contact log and enqueue a sync operation in a single transaction.
  /// Guarantees that every locally recorded contact log has a corresponding
  /// outbox entry for push sync.
  Future<void> insertContactLogWithOutbox(
    ContactLogsCompanion log,
    SyncDao syncDao,
  ) async {
    await syncDao.writeWithOutbox(
      attachedDatabase,
      dataWrite: () async {
        await into(contactLogs).insert(log);
      },
      entityType: 'contact_log',
      entityId: log.id.value,
      operationType: 'create',
      payload: {
        'id': log.id.value,
        'voter_id': log.voterId.value,
        'turf_id': log.turfId.value,
        'user_id': log.userId.value,
        'contact_type': log.contactType.value,
        'outcome': log.outcome.value,
        'notes': log.notes.value,
        'created_at': log.createdAt.value.toIso8601String(),
      },
    );
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
