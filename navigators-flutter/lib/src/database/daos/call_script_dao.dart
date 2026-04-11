import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/call_scripts.dart';

part 'call_script_dao.g.dart';

@DriftAccessor(tables: [CallScripts])
class CallScriptDao extends DatabaseAccessor<NavigatorsDatabase>
    with _$CallScriptDaoMixin {
  CallScriptDao(super.db);

  /// Bulk upsert call scripts from server pull sync.
  Future<void> upsertCallScripts(List<CallScriptsCompanion> scripts) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(callScripts, scripts);
    });
  }

  /// Get all active call scripts.
  Future<List<CallScript>> getActiveCallScripts() {
    return (select(callScripts)
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  /// Watch active call scripts for reactive UI.
  Stream<List<CallScript>> watchActiveCallScripts() {
    return (select(callScripts)
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }
}
