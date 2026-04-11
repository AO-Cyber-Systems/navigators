import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:eden_platform_flutter/eden_platform.dart';

import '../database/database.dart';

/// SyncClient communicates with the server SyncService via ConnectRPC JSON protocol.
/// Follows the same pattern as VoterService (HTTP POST with JSON body).
class SyncClient {
  final String _baseUrl;
  final String? Function() _getAccessToken;

  SyncClient({
    required String baseUrl,
    required String? Function() getAccessToken,
  })  : _baseUrl = baseUrl,
        _getAccessToken = getAccessToken;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_getAccessToken() != null)
          'Authorization': 'Bearer ${_getAccessToken()}',
      };

  Future<Map<String, dynamic>> _post(
      String method, Map<String, dynamic> body) async {
    final url = Uri.parse('$_baseUrl/navigators.v1.SyncService/$method');
    final response =
        await http.post(url, headers: _headers, body: jsonEncode(body));
    if (response.statusCode != 200) {
      throw Exception('$method failed: ${response.statusCode} ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Pull voter updates since the given cursor.
  Future<PullVoterUpdatesResult> pullVoterUpdates({
    required String sinceCursor,
    required List<String> turfIds,
    int batchSize = 500,
  }) async {
    final result = await _post('PullVoterUpdates', {
      'sinceCursor': sinceCursor,
      'turfIds': turfIds,
      'batchSize': batchSize,
    });

    final voters = (result['voters'] as List<dynamic>? ?? [])
        .map((v) => SyncVoterData.fromJson(v as Map<String, dynamic>))
        .toList();

    return PullVoterUpdatesResult(
      voters: voters,
      nextCursor: result['nextCursor'] as String? ?? '',
      hasMore: result['hasMore'] as bool? ?? false,
    );
  }

  /// Pull contact log updates since the given cursor.
  Future<PullContactLogsResult> pullContactLogs({
    required String sinceCursor,
    required List<String> turfIds,
    int batchSize = 500,
  }) async {
    final result = await _post('PullContactLogs', {
      'sinceCursor': sinceCursor,
      'turfIds': turfIds,
      'batchSize': batchSize,
    });

    final logs = (result['contactLogs'] as List<dynamic>? ?? [])
        .map((l) => SyncContactLogData.fromJson(l as Map<String, dynamic>))
        .toList();

    return PullContactLogsResult(
      contactLogs: logs,
      nextCursor: result['nextCursor'] as String? ?? '',
      hasMore: result['hasMore'] as bool? ?? false,
    );
  }

  /// Pull survey form updates since the given cursor.
  Future<PullSurveyFormsResult> pullSurveyForms({
    required String sinceCursor,
    int batchSize = 500,
  }) async {
    final result = await _post('PullSurveyForms', {
      'sinceCursor': sinceCursor,
      'batchSize': batchSize,
    });

    final forms = (result['surveyForms'] as List<dynamic>? ?? [])
        .map((f) => SyncSurveyFormData.fromJson(f as Map<String, dynamic>))
        .toList();

    return PullSurveyFormsResult(
      surveyForms: forms,
      nextCursor: result['nextCursor'] as String? ?? '',
      hasMore: result['hasMore'] as bool? ?? false,
    );
  }

  /// Pull survey response updates since the given cursor.
  Future<PullSurveyResponsesResult> pullSurveyResponses({
    required String sinceCursor,
    required List<String> turfIds,
    int batchSize = 500,
  }) async {
    final result = await _post('PullSurveyResponses', {
      'sinceCursor': sinceCursor,
      'turfIds': turfIds,
      'batchSize': batchSize,
    });

    final responses = (result['surveyResponses'] as List<dynamic>? ?? [])
        .map((r) => SyncSurveyResponseData.fromJson(r as Map<String, dynamic>))
        .toList();

    return PullSurveyResponsesResult(
      surveyResponses: responses,
      nextCursor: result['nextCursor'] as String? ?? '',
      hasMore: result['hasMore'] as bool? ?? false,
    );
  }

  /// Pull voter note updates since the given cursor.
  Future<PullVoterNotesResult> pullVoterNotes({
    required String sinceCursor,
    required List<String> turfIds,
    int batchSize = 500,
  }) async {
    final result = await _post('PullVoterNotes', {
      'sinceCursor': sinceCursor,
      'turfIds': turfIds,
      'batchSize': batchSize,
    });

    final notes = (result['voterNotes'] as List<dynamic>? ?? [])
        .map((n) => SyncVoterNoteData.fromJson(n as Map<String, dynamic>))
        .toList();

    return PullVoterNotesResult(
      voterNotes: notes,
      nextCursor: result['nextCursor'] as String? ?? '',
      hasMore: result['hasMore'] as bool? ?? false,
    );
  }

  /// Push a batch of sync operations to the server.
  /// Returns the raw response map with processedOperationIds and errors.
  Future<Map<String, dynamic>> pushSyncBatch(
      List<Map<String, dynamic>> operations) async {
    return _post('PushSyncBatch', {'operations': operations});
  }

  /// Get the sync manifest (turf assignments with metadata).
  Future<SyncManifest> getSyncManifest() async {
    final result = await _post('GetSyncManifest', {});

    final assignments =
        (result['turfAssignments'] as List<dynamic>? ?? [])
            .map((a) =>
                TurfAssignmentData.fromJson(a as Map<String, dynamic>))
            .toList();

    return SyncManifest(
      turfAssignments: assignments,
      serverTime: result['serverTime'] as String? ?? '',
    );
  }

  /// Pull all voters for given turfs, looping with cursor until complete.
  /// Inserts into local Drift database via VoterDao batch upsert.
  Future<int> pullAllVoters(
    NavigatorsDatabase db,
    List<String> turfIds,
  ) async {
    final syncDao = db.syncDao;
    final voterDao = db.voterDao;

    // Get current cursor (or empty for full sync)
    final cursorRow = await syncDao.getCursor('voters');
    var cursor = cursorRow?.cursor ?? '';
    var totalPulled = 0;

    while (true) {
      final result = await pullVoterUpdates(
        sinceCursor: cursor,
        turfIds: turfIds,
      );

      if (result.voters.isEmpty) break;

      // Batch upsert voters
      final companions = result.voters.map((v) => v.toCompanion()).toList();
      await voterDao.upsertVoters(companions);

      totalPulled += result.voters.length;
      cursor = result.nextCursor;

      // Update cursor after each batch (preserves progress if interrupted)
      await syncDao.updateCursor('voters', cursor);

      if (!result.hasMore) break;
    }

    return totalPulled;
  }

  /// Pull all contact logs for given turfs, looping with cursor until complete.
  Future<int> pullAllContactLogs(
    NavigatorsDatabase db,
    List<String> turfIds,
  ) async {
    final syncDao = db.syncDao;
    final contactLogDao = db.contactLogDao;

    final cursorRow = await syncDao.getCursor('contact_logs');
    var cursor = cursorRow?.cursor ?? '';
    var totalPulled = 0;

    while (true) {
      final result = await pullContactLogs(
        sinceCursor: cursor,
        turfIds: turfIds,
      );

      if (result.contactLogs.isEmpty) break;

      final companions =
          result.contactLogs.map((cl) => cl.toCompanion()).toList();
      await contactLogDao.upsertContactLogs(companions);

      totalPulled += result.contactLogs.length;
      cursor = result.nextCursor;

      await syncDao.updateCursor('contact_logs', cursor);

      if (!result.hasMore) break;
    }

    return totalPulled;
  }
  /// Pull all survey forms, looping with cursor until complete.
  Future<int> pullAllSurveyForms(NavigatorsDatabase db) async {
    final syncDao = db.syncDao;
    final surveyDao = db.surveyDao;

    final cursorRow = await syncDao.getCursor('survey_forms');
    var cursor = cursorRow?.cursor ?? '';
    var totalPulled = 0;

    while (true) {
      final result = await pullSurveyForms(sinceCursor: cursor);
      if (result.surveyForms.isEmpty) break;

      final companions =
          result.surveyForms.map((f) => f.toCompanion()).toList();
      await surveyDao.upsertSurveyForms(companions);

      totalPulled += result.surveyForms.length;
      cursor = result.nextCursor;
      await syncDao.updateCursor('survey_forms', cursor);

      if (!result.hasMore) break;
    }

    return totalPulled;
  }

  /// Pull all survey responses for given turfs, looping with cursor until complete.
  Future<int> pullAllSurveyResponses(
    NavigatorsDatabase db,
    List<String> turfIds,
  ) async {
    final syncDao = db.syncDao;
    final surveyDao = db.surveyDao;

    final cursorRow = await syncDao.getCursor('survey_responses');
    var cursor = cursorRow?.cursor ?? '';
    var totalPulled = 0;

    while (true) {
      final result = await pullSurveyResponses(
        sinceCursor: cursor,
        turfIds: turfIds,
      );
      if (result.surveyResponses.isEmpty) break;

      final companions =
          result.surveyResponses.map((r) => r.toCompanion()).toList();
      await surveyDao.upsertSurveyResponses(companions);

      totalPulled += result.surveyResponses.length;
      cursor = result.nextCursor;
      await syncDao.updateCursor('survey_responses', cursor);

      if (!result.hasMore) break;
    }

    return totalPulled;
  }

  /// Pull all voter notes for given turfs, looping with cursor until complete.
  Future<int> pullAllVoterNotes(
    NavigatorsDatabase db,
    List<String> turfIds,
  ) async {
    final syncDao = db.syncDao;
    final voterNoteDao = db.voterNoteDao;

    final cursorRow = await syncDao.getCursor('voter_notes');
    var cursor = cursorRow?.cursor ?? '';
    var totalPulled = 0;

    while (true) {
      final result = await pullVoterNotes(
        sinceCursor: cursor,
        turfIds: turfIds,
      );
      if (result.voterNotes.isEmpty) break;

      final companions =
          result.voterNotes.map((n) => n.toCompanion()).toList();
      await voterNoteDao.upsertVoterNotes(companions);

      totalPulled += result.voterNotes.length;
      cursor = result.nextCursor;
      await syncDao.updateCursor('voter_notes', cursor);

      if (!result.hasMore) break;
    }

    return totalPulled;
  }
}

// --- Data Models ---

class PullVoterUpdatesResult {
  final List<SyncVoterData> voters;
  final String nextCursor;
  final bool hasMore;

  const PullVoterUpdatesResult({
    required this.voters,
    required this.nextCursor,
    required this.hasMore,
  });
}

class PullContactLogsResult {
  final List<SyncContactLogData> contactLogs;
  final String nextCursor;
  final bool hasMore;

  const PullContactLogsResult({
    required this.contactLogs,
    required this.nextCursor,
    required this.hasMore,
  });
}

class SyncManifest {
  final List<TurfAssignmentData> turfAssignments;
  final String serverTime;

  const SyncManifest({
    required this.turfAssignments,
    required this.serverTime,
  });
}

class TurfAssignmentData {
  final String turfId;
  final String turfName;
  final String boundaryGeojson;
  final int voterCount;

  const TurfAssignmentData({
    required this.turfId,
    required this.turfName,
    required this.boundaryGeojson,
    required this.voterCount,
  });

  factory TurfAssignmentData.fromJson(Map<String, dynamic> json) {
    return TurfAssignmentData(
      turfId: json['turfId'] as String? ?? '',
      turfName: json['turfName'] as String? ?? '',
      boundaryGeojson: json['boundaryGeojson'] as String? ?? '',
      voterCount: (json['voterCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class SyncVoterData {
  final String id;
  final String turfId;
  final String firstName;
  final String lastName;
  final String middleName;
  final String suffix;
  final int yearOfBirth;
  final String resStreetAddress;
  final String resCity;
  final String resState;
  final String resZip;
  final String party;
  final String status;
  final double latitude;
  final double longitude;
  final String votingHistory;
  final String phone;
  final String email;
  final int walkSequence;
  final String serverUpdatedAt;

  const SyncVoterData({
    required this.id,
    required this.turfId,
    required this.firstName,
    required this.lastName,
    required this.middleName,
    required this.suffix,
    required this.yearOfBirth,
    required this.resStreetAddress,
    required this.resCity,
    required this.resState,
    required this.resZip,
    required this.party,
    required this.status,
    required this.latitude,
    required this.longitude,
    required this.votingHistory,
    required this.phone,
    required this.email,
    required this.walkSequence,
    required this.serverUpdatedAt,
  });

  factory SyncVoterData.fromJson(Map<String, dynamic> json) {
    return SyncVoterData(
      id: json['id'] as String? ?? '',
      turfId: json['turfId'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      middleName: json['middleName'] as String? ?? '',
      suffix: json['suffix'] as String? ?? '',
      yearOfBirth: (json['yearOfBirth'] as num?)?.toInt() ?? 0,
      resStreetAddress: json['resStreetAddress'] as String? ?? '',
      resCity: json['resCity'] as String? ?? '',
      resState: json['resState'] as String? ?? '',
      resZip: json['resZip'] as String? ?? '',
      party: json['party'] as String? ?? '',
      status: json['status'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      votingHistory: json['votingHistory'] as String? ?? '[]',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      walkSequence: (json['walkSequence'] as num?)?.toInt() ?? 0,
      serverUpdatedAt: json['serverUpdatedAt'] as String? ?? '',
    );
  }

  /// Convert to Drift companion for batch upsert.
  VotersCompanion toCompanion() {
    return VotersCompanion(
      id: Value(id),
      turfId: Value(turfId),
      firstName: Value(firstName),
      lastName: Value(lastName),
      middleName: Value(middleName),
      suffix: Value(suffix),
      yearOfBirth: Value(yearOfBirth),
      resStreetAddress: Value(resStreetAddress),
      resCity: Value(resCity),
      resState: Value(resState),
      resZip: Value(resZip),
      party: Value(party),
      status: Value(status),
      latitude: Value(latitude),
      longitude: Value(longitude),
      votingHistory: Value(votingHistory),
      phone: Value(phone),
      email: Value(email),
      walkSequence: Value(walkSequence),
      serverUpdatedAt: Value(
        serverUpdatedAt.isNotEmpty
            ? DateTime.parse(serverUpdatedAt)
            : DateTime.now(),
      ),
      localUpdatedAt: Value(DateTime.now()),
    );
  }
}

class SyncContactLogData {
  final String id;
  final String voterId;
  final String turfId;
  final String userId;
  final String contactType;
  final String outcome;
  final String notes;
  final String doorStatus;
  final int? sentiment;
  final String createdAt;

  const SyncContactLogData({
    required this.id,
    required this.voterId,
    required this.turfId,
    required this.userId,
    required this.contactType,
    required this.outcome,
    required this.notes,
    required this.doorStatus,
    required this.sentiment,
    required this.createdAt,
  });

  factory SyncContactLogData.fromJson(Map<String, dynamic> json) {
    return SyncContactLogData(
      id: json['id'] as String? ?? '',
      voterId: json['voterId'] as String? ?? '',
      turfId: json['turfId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      contactType: json['contactType'] as String? ?? '',
      outcome: json['outcome'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      doorStatus: json['doorStatus'] as String? ?? '',
      sentiment: (json['sentiment'] as num?)?.toInt(),
      createdAt: json['createdAt'] as String? ?? '',
    );
  }

  ContactLogsCompanion toCompanion() {
    return ContactLogsCompanion(
      id: Value(id),
      voterId: Value(voterId),
      turfId: Value(turfId),
      userId: Value(userId),
      contactType: Value(contactType),
      outcome: Value(outcome),
      notes: Value(notes),
      doorStatus: Value(doorStatus),
      sentiment: Value(sentiment),
      createdAt: Value(
        createdAt.isNotEmpty ? DateTime.parse(createdAt) : DateTime.now(),
      ),
      syncedAt: Value(DateTime.now()),
    );
  }
}

class PullSurveyFormsResult {
  final List<SyncSurveyFormData> surveyForms;
  final String nextCursor;
  final bool hasMore;

  const PullSurveyFormsResult({
    required this.surveyForms,
    required this.nextCursor,
    required this.hasMore,
  });
}

class PullSurveyResponsesResult {
  final List<SyncSurveyResponseData> surveyResponses;
  final String nextCursor;
  final bool hasMore;

  const PullSurveyResponsesResult({
    required this.surveyResponses,
    required this.nextCursor,
    required this.hasMore,
  });
}

class PullVoterNotesResult {
  final List<SyncVoterNoteData> voterNotes;
  final String nextCursor;
  final bool hasMore;

  const PullVoterNotesResult({
    required this.voterNotes,
    required this.nextCursor,
    required this.hasMore,
  });
}

class SyncSurveyFormData {
  final String id;
  final String companyId;
  final String title;
  final String description;
  final String schema;
  final int version;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  const SyncSurveyFormData({
    required this.id,
    required this.companyId,
    required this.title,
    required this.description,
    required this.schema,
    required this.version,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SyncSurveyFormData.fromJson(Map<String, dynamic> json) {
    return SyncSurveyFormData(
      id: json['id'] as String? ?? '',
      companyId: json['companyId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      schema: json['schema'] as String? ?? '{}',
      version: (json['version'] as num?)?.toInt() ?? 1,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }

  SurveyFormsCompanion toCompanion() {
    return SurveyFormsCompanion(
      id: Value(id),
      companyId: Value(companyId),
      title: Value(title),
      description: Value(description),
      schema: Value(schema),
      version: Value(version),
      isActive: Value(isActive),
      createdAt: Value(
        createdAt.isNotEmpty ? DateTime.parse(createdAt) : DateTime.now(),
      ),
      updatedAt: Value(
        updatedAt.isNotEmpty ? DateTime.parse(updatedAt) : DateTime.now(),
      ),
    );
  }
}

class SyncSurveyResponseData {
  final String id;
  final String formId;
  final int formVersion;
  final String voterId;
  final String userId;
  final String turfId;
  final String? contactLogId;
  final String responsesJson;
  final String createdAt;

  const SyncSurveyResponseData({
    required this.id,
    required this.formId,
    required this.formVersion,
    required this.voterId,
    required this.userId,
    required this.turfId,
    this.contactLogId,
    required this.responsesJson,
    required this.createdAt,
  });

  factory SyncSurveyResponseData.fromJson(Map<String, dynamic> json) {
    return SyncSurveyResponseData(
      id: json['id'] as String? ?? '',
      formId: json['formId'] as String? ?? '',
      formVersion: (json['formVersion'] as num?)?.toInt() ?? 1,
      voterId: json['voterId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      turfId: json['turfId'] as String? ?? '',
      contactLogId: json['contactLogId'] as String?,
      responsesJson: json['responsesJson'] as String? ?? '{}',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }

  SurveyResponsesCompanion toCompanion() {
    return SurveyResponsesCompanion(
      id: Value(id),
      formId: Value(formId),
      formVersion: Value(formVersion),
      voterId: Value(voterId),
      userId: Value(userId),
      turfId: Value(turfId),
      contactLogId: Value(contactLogId),
      responsesJson: Value(responsesJson),
      createdAt: Value(
        createdAt.isNotEmpty ? DateTime.parse(createdAt) : DateTime.now(),
      ),
      syncedAt: Value(DateTime.now()),
    );
  }
}

class SyncVoterNoteData {
  final String id;
  final String voterId;
  final String userId;
  final String turfId;
  final String content;
  final String visibility;
  final String createdAt;
  final String updatedAt;

  const SyncVoterNoteData({
    required this.id,
    required this.voterId,
    required this.userId,
    required this.turfId,
    required this.content,
    required this.visibility,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SyncVoterNoteData.fromJson(Map<String, dynamic> json) {
    return SyncVoterNoteData(
      id: json['id'] as String? ?? '',
      voterId: json['voterId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      turfId: json['turfId'] as String? ?? '',
      content: json['content'] as String? ?? '',
      visibility: json['visibility'] as String? ?? 'team',
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }

  VoterNotesCompanion toCompanion() {
    return VoterNotesCompanion(
      id: Value(id),
      voterId: Value(voterId),
      userId: Value(userId),
      turfId: Value(turfId),
      content: Value(content),
      visibility: Value(visibility),
      createdAt: Value(
        createdAt.isNotEmpty ? DateTime.parse(createdAt) : DateTime.now(),
      ),
      updatedAt: Value(
        updatedAt.isNotEmpty ? DateTime.parse(updatedAt) : DateTime.now(),
      ),
      syncedAt: Value(DateTime.now()),
    );
  }
}

// --- Riverpod Provider ---

final syncClientProvider = Provider<SyncClient>((ref) {
  final auth = ref.watch(authProvider);
  const envUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  final baseUrl = envUrl.isNotEmpty ? envUrl : 'http://localhost:8080';
  return SyncClient(
    baseUrl: baseUrl,
    getAccessToken: () => auth.accessToken,
  );
});
