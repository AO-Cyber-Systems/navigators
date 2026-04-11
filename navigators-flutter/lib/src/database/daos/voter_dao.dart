import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/voters.dart';

part 'voter_dao.g.dart';

@DriftAccessor(tables: [Voters])
class VoterDao extends DatabaseAccessor<NavigatorsDatabase>
    with _$VoterDaoMixin {
  VoterDao(super.db);

  /// Watch all voters in a given turf, ordered by walk sequence.
  Stream<List<Voter>> watchVotersInTurf(String turfId) {
    return (select(voters)
          ..where((v) => v.turfId.equals(turfId))
          ..orderBy([(v) => OrderingTerm.asc(v.walkSequence)]))
        .watch();
  }

  /// Get a single voter by ID.
  Future<Voter?> getVoterById(String id) {
    return (select(voters)..where((v) => v.id.equals(id))).getSingleOrNull();
  }

  /// Bulk upsert voters using a single transaction batch.
  Future<void> upsertVoters(List<VotersCompanion> voterList) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(voters, voterList);
    });
  }

  /// Delete all voters for a given turf (used on turf reassignment).
  Future<int> deleteVotersForTurf(String turfId) {
    return (delete(voters)..where((v) => v.turfId.equals(turfId))).go();
  }

  /// Count voters in a turf.
  Future<int> countVotersInTurf(String turfId) async {
    final count = voters.id.count();
    final query = selectOnly(voters)
      ..addColumns([count])
      ..where(voters.turfId.equals(turfId));
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }
}
