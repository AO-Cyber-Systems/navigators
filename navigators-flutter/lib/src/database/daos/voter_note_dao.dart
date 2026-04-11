import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/voter_notes.dart';
import 'sync_dao.dart';

part 'voter_note_dao.g.dart';

@DriftAccessor(tables: [VoterNotes])
class VoterNoteDao extends DatabaseAccessor<NavigatorsDatabase>
    with _$VoterNoteDaoMixin {
  VoterNoteDao(super.db);

  /// Insert a voter note and enqueue a sync operation in a single transaction.
  Future<void> insertNoteWithOutbox(
    VoterNotesCompanion note,
    SyncDao syncDao,
  ) async {
    await syncDao.writeWithOutbox(
      attachedDatabase,
      dataWrite: () async {
        await into(voterNotes).insert(note);
      },
      entityType: 'voter_note',
      entityId: note.id.value,
      operationType: 'create',
      payload: {
        'id': note.id.value,
        'voter_id': note.voterId.value,
        'user_id': note.userId.value,
        'turf_id': note.turfId.value,
        'content': note.content.value,
        'visibility': note.visibility.value,
        'created_at': note.createdAt.value.toIso8601String(),
        'updated_at': note.updatedAt.value.toIso8601String(),
      },
    );
  }

  /// Watch voter notes for a voter, newest first.
  Stream<List<VoterNote>> watchNotesForVoter(String voterId) {
    return (select(voterNotes)
          ..where((t) => t.voterId.equals(voterId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// Bulk upsert voter notes from server pull sync.
  Future<void> upsertVoterNotes(List<VoterNotesCompanion> notes) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(voterNotes, notes);
    });
  }
}
