import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/training_materials.dart';

part 'training_dao.g.dart';

@DriftAccessor(tables: [TrainingMaterials])
class TrainingDao extends DatabaseAccessor<NavigatorsDatabase>
    with _$TrainingDaoMixin {
  TrainingDao(super.db);

  /// Watch published training materials ordered by sort order.
  Stream<List<TrainingMaterial>> watchPublishedMaterials() {
    return (select(trainingMaterials)
          ..where((t) => t.isPublished.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  /// Upsert a single training material.
  Future<void> upsertMaterial(TrainingMaterialsCompanion companion) async {
    await into(trainingMaterials).insertOnConflictUpdate(companion);
  }

  /// Bulk upsert training materials from server pull sync.
  Future<void> upsertMaterials(List<TrainingMaterialsCompanion> items) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(trainingMaterials, items);
    });
  }

  /// Delete all training materials (for sync reset).
  Future<void> deleteAllMaterials() async {
    await delete(trainingMaterials).go();
  }
}
