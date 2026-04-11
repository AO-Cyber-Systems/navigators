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

  /// Pull call script updates since the given cursor.
  Future<PullCallScriptsResult> pullCallScripts({
    required String sinceCursor,
    int batchSize = 500,
  }) async {
    final result = await _post('PullCallScripts', {
      'sinceCursor': sinceCursor,
      'batchSize': batchSize,
    });

    final scripts = (result['callScripts'] as List<dynamic>? ?? [])
        .map((s) => SyncCallScriptData.fromJson(s as Map<String, dynamic>))
        .toList();

    return PullCallScriptsResult(
      callScripts: scripts,
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

  /// Pull all call scripts, looping with cursor until complete.
  Future<int> pullAllCallScripts(NavigatorsDatabase db) async {
    final syncDao = db.syncDao;
    final callScriptDao = db.callScriptDao;

    final cursorRow = await syncDao.getCursor('call_scripts');
    var cursor = cursorRow?.cursor ?? '';
    var totalPulled = 0;

    while (true) {
      final result = await pullCallScripts(sinceCursor: cursor);
      if (result.callScripts.isEmpty) break;

      final companions =
          result.callScripts.map((s) => s.toCompanion()).toList();
      await callScriptDao.upsertCallScripts(companions);

      totalPulled += result.callScripts.length;
      cursor = result.nextCursor;
      await syncDao.updateCursor('call_scripts', cursor);

      if (!result.hasMore) break;
    }

    return totalPulled;
  }

  /// Pull task updates since the given cursor.
  Future<PullTasksResult> pullTasks({
    required String sinceCursor,
    int batchSize = 500,
  }) async {
    final result = await _post('PullTasks', {
      'sinceCursor': sinceCursor,
      'batchSize': batchSize,
    });

    final tasks = (result['tasks'] as List<dynamic>? ?? [])
        .map((t) => SyncTaskData.fromJson(t as Map<String, dynamic>))
        .toList();

    final assignments =
        (result['taskAssignments'] as List<dynamic>? ?? [])
            .map((a) =>
                SyncTaskAssignmentData.fromJson(a as Map<String, dynamic>))
            .toList();

    return PullTasksResult(
      tasks: tasks,
      taskAssignments: assignments,
      nextCursor: result['nextCursor'] as String? ?? '',
      hasMore: result['hasMore'] as bool? ?? false,
    );
  }

  /// Pull task note updates since the given cursor.
  Future<PullTaskNotesResult> pullTaskNotes({
    required String sinceCursor,
    int batchSize = 500,
  }) async {
    final result = await _post('PullTaskNotes', {
      'sinceCursor': sinceCursor,
      'batchSize': batchSize,
    });

    final notes = (result['taskNotes'] as List<dynamic>? ?? [])
        .map((n) => SyncTaskNoteData.fromJson(n as Map<String, dynamic>))
        .toList();

    return PullTaskNotesResult(
      taskNotes: notes,
      nextCursor: result['nextCursor'] as String? ?? '',
      hasMore: result['hasMore'] as bool? ?? false,
    );
  }

  /// Pull all tasks, looping with cursor until complete.
  Future<int> pullAllTasks(NavigatorsDatabase db) async {
    final syncDao = db.syncDao;
    final taskDao = db.taskDao;

    final cursorRow = await syncDao.getCursor('tasks');
    var cursor = cursorRow?.cursor ?? '';
    var totalPulled = 0;

    while (true) {
      final result = await pullTasks(sinceCursor: cursor);
      if (result.tasks.isEmpty) break;

      final taskCompanions =
          result.tasks.map((t) => t.toCompanion()).toList();
      await taskDao.upsertTasks(taskCompanions);

      if (result.taskAssignments.isNotEmpty) {
        final assignmentCompanions =
            result.taskAssignments.map((a) => a.toCompanion()).toList();
        await taskDao.upsertTaskAssignments(assignmentCompanions);
      }

      totalPulled += result.tasks.length;
      cursor = result.nextCursor;
      await syncDao.updateCursor('tasks', cursor);

      if (!result.hasMore) break;
    }

    return totalPulled;
  }

  /// Pull all task notes, looping with cursor until complete.
  Future<int> pullAllTaskNotes(NavigatorsDatabase db) async {
    final syncDao = db.syncDao;
    final taskDao = db.taskDao;

    final cursorRow = await syncDao.getCursor('task_notes');
    var cursor = cursorRow?.cursor ?? '';
    var totalPulled = 0;

    while (true) {
      final result = await pullTaskNotes(sinceCursor: cursor);
      if (result.taskNotes.isEmpty) break;

      final companions =
          result.taskNotes.map((n) => n.toCompanion()).toList();
      await taskDao.upsertTaskNotes(companions);

      totalPulled += result.taskNotes.length;
      cursor = result.nextCursor;
      await syncDao.updateCursor('task_notes', cursor);

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

class PullCallScriptsResult {
  final List<SyncCallScriptData> callScripts;
  final String nextCursor;
  final bool hasMore;

  const PullCallScriptsResult({
    required this.callScripts,
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

class SyncCallScriptData {
  final String id;
  final String companyId;
  final String title;
  final String content;
  final int version;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  const SyncCallScriptData({
    required this.id,
    required this.companyId,
    required this.title,
    required this.content,
    required this.version,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SyncCallScriptData.fromJson(Map<String, dynamic> json) {
    return SyncCallScriptData(
      id: json['id'] as String? ?? '',
      companyId: json['companyId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      version: (json['version'] as num?)?.toInt() ?? 1,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }

  CallScriptsCompanion toCompanion() {
    return CallScriptsCompanion(
      id: Value(id),
      companyId: Value(companyId),
      title: Value(title),
      content: Value(content),
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

class PullTasksResult {
  final List<SyncTaskData> tasks;
  final List<SyncTaskAssignmentData> taskAssignments;
  final String nextCursor;
  final bool hasMore;

  const PullTasksResult({
    required this.tasks,
    required this.taskAssignments,
    required this.nextCursor,
    required this.hasMore,
  });
}

class PullTaskNotesResult {
  final List<SyncTaskNoteData> taskNotes;
  final String nextCursor;
  final bool hasMore;

  const PullTaskNotesResult({
    required this.taskNotes,
    required this.nextCursor,
    required this.hasMore,
  });
}

class SyncTaskData {
  final String id;
  final String companyId;
  final String title;
  final String description;
  final String taskType;
  final String priority;
  final String status;
  final String? dueDate;
  final String? linkedEntityType;
  final String? linkedEntityId;
  final int progressPct;
  final int totalCount;
  final int completedCount;
  final String createdBy;
  final String createdAt;
  final String updatedAt;

  const SyncTaskData({
    required this.id,
    required this.companyId,
    required this.title,
    required this.description,
    required this.taskType,
    required this.priority,
    required this.status,
    this.dueDate,
    this.linkedEntityType,
    this.linkedEntityId,
    required this.progressPct,
    required this.totalCount,
    required this.completedCount,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SyncTaskData.fromJson(Map<String, dynamic> json) {
    return SyncTaskData(
      id: json['id'] as String? ?? '',
      companyId: json['companyId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      taskType: json['taskType'] as String? ?? 'custom',
      priority: json['priority'] as String? ?? 'medium',
      status: json['status'] as String? ?? 'open',
      dueDate: json['dueDate'] as String?,
      linkedEntityType: json['linkedEntityType'] as String?,
      linkedEntityId: json['linkedEntityId'] as String?,
      progressPct: (json['progressPct'] as num?)?.toInt() ?? 0,
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
      completedCount: (json['completedCount'] as num?)?.toInt() ?? 0,
      createdBy: json['createdBy'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }

  TasksCompanion toCompanion() {
    return TasksCompanion(
      id: Value(id),
      companyId: Value(companyId),
      title: Value(title),
      description: Value(description),
      taskType: Value(taskType),
      priority: Value(priority),
      status: Value(status),
      dueDate: Value(
        dueDate != null && dueDate!.isNotEmpty
            ? DateTime.parse(dueDate!)
            : null,
      ),
      linkedEntityType: Value(linkedEntityType),
      linkedEntityId: Value(linkedEntityId),
      progressPct: Value(progressPct),
      totalCount: Value(totalCount),
      completedCount: Value(completedCount),
      createdBy: Value(createdBy),
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

class SyncTaskAssignmentData {
  final String id;
  final String taskId;
  final String userId;
  final String assignedBy;
  final String assignedAt;

  const SyncTaskAssignmentData({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.assignedBy,
    required this.assignedAt,
  });

  factory SyncTaskAssignmentData.fromJson(Map<String, dynamic> json) {
    return SyncTaskAssignmentData(
      id: json['id'] as String? ?? '',
      taskId: json['taskId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      assignedBy: json['assignedBy'] as String? ?? '',
      assignedAt: json['assignedAt'] as String? ?? '',
    );
  }

  TaskAssignmentsCompanion toCompanion() {
    return TaskAssignmentsCompanion(
      id: Value(id),
      taskId: Value(taskId),
      userId: Value(userId),
      assignedBy: Value(assignedBy),
      assignedAt: Value(
        assignedAt.isNotEmpty ? DateTime.parse(assignedAt) : DateTime.now(),
      ),
    );
  }
}

class SyncTaskNoteData {
  final String id;
  final String companyId;
  final String taskId;
  final String userId;
  final String content;
  final String visibility;
  final String createdAt;

  const SyncTaskNoteData({
    required this.id,
    required this.companyId,
    required this.taskId,
    required this.userId,
    required this.content,
    required this.visibility,
    required this.createdAt,
  });

  factory SyncTaskNoteData.fromJson(Map<String, dynamic> json) {
    return SyncTaskNoteData(
      id: json['id'] as String? ?? '',
      companyId: json['companyId'] as String? ?? '',
      taskId: json['taskId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      content: json['content'] as String? ?? '',
      visibility: json['visibility'] as String? ?? 'team',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }

  TaskNotesCompanion toCompanion() {
    return TaskNotesCompanion(
      id: Value(id),
      companyId: Value(companyId),
      taskId: Value(taskId),
      userId: Value(userId),
      content: Value(content),
      visibility: Value(visibility),
      createdAt: Value(
        createdAt.isNotEmpty ? DateTime.parse(createdAt) : DateTime.now(),
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
