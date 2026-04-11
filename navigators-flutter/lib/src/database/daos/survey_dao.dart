import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/survey_forms.dart';
import '../tables/survey_responses.dart';
import 'sync_dao.dart';

part 'survey_dao.g.dart';

@DriftAccessor(tables: [SurveyForms, SurveyResponses])
class SurveyDao extends DatabaseAccessor<NavigatorsDatabase>
    with _$SurveyDaoMixin {
  SurveyDao(super.db);

  /// Bulk upsert survey forms from server pull sync.
  Future<void> upsertSurveyForms(List<SurveyFormsCompanion> forms) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(surveyForms, forms);
    });
  }

  /// Get all active survey forms.
  Future<List<SurveyForm>> getActiveSurveyForms() {
    return (select(surveyForms)
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  /// Watch active survey forms for reactive UI.
  Stream<List<SurveyForm>> watchActiveSurveyForms() {
    return (select(surveyForms)
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// Insert a survey response and enqueue a sync operation in a single transaction.
  Future<void> insertResponseWithOutbox(
    SurveyResponsesCompanion response,
    SyncDao syncDao,
  ) async {
    await syncDao.writeWithOutbox(
      attachedDatabase,
      dataWrite: () async {
        await into(surveyResponses).insert(response);
      },
      entityType: 'survey_response',
      entityId: response.id.value,
      operationType: 'create',
      payload: {
        'id': response.id.value,
        'form_id': response.formId.value,
        'form_version': response.formVersion.value,
        'voter_id': response.voterId.value,
        'user_id': response.userId.value,
        'turf_id': response.turfId.value,
        'contact_log_id': response.contactLogId.value,
        'responses': response.responsesJson.value,
        'created_at': response.createdAt.value.toIso8601String(),
      },
    );
  }

  /// Watch survey responses for a voter, newest first.
  Stream<List<SurveyResponse>> watchResponsesForVoter(String voterId) {
    return (select(surveyResponses)
          ..where((t) => t.voterId.equals(voterId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// Bulk upsert survey responses from server pull sync.
  Future<void> upsertSurveyResponses(
      List<SurveyResponsesCompanion> responses) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(surveyResponses, responses);
    });
  }
}
