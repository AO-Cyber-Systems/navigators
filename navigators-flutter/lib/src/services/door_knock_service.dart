import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eden_platform_flutter/eden_platform.dart';

import '../database/database.dart';

/// Result returned from a door knock session, used to update walk list.
class DoorKnockResult {
  final String voterId;
  final String doorStatus;

  const DoorKnockResult({
    required this.voterId,
    required this.doorStatus,
  });
}

/// Parameters for a full door knock session save.
class DoorKnockSession {
  final String voterId;
  final String turfId;
  final String doorStatus;
  final int? sentiment;
  final String notes;

  /// Survey responses keyed by field ID (null if no survey completed).
  final Map<String, dynamic>? surveyResponses;

  /// Survey form ID (null if no survey completed).
  final String? surveyFormId;

  /// Survey form version (null if no survey completed).
  final int? surveyFormVersion;

  /// Note visibility: 'private', 'team', or 'org'.
  final String noteVisibility;

  const DoorKnockSession({
    required this.voterId,
    required this.turfId,
    required this.doorStatus,
    this.sentiment,
    this.notes = '',
    this.surveyResponses,
    this.surveyFormId,
    this.surveyFormVersion,
    this.noteVisibility = 'team',
  });
}

/// Business logic orchestrating door knock recording, survey responses, and notes.
///
/// Each insert uses the outbox pattern for offline-first sync.
/// Contact log, survey response, and voter note are independent outbox entries
/// (NOT wrapped in a single transaction) so each can sync independently.
class DoorKnockService {
  final Ref _ref;

  DoorKnockService(this._ref);

  NavigatorsDatabase get _db => _ref.read(databaseProvider);

  String get _userId {
    final auth = _ref.read(authProvider);
    return auth.userId ?? '';
  }

  /// Get the currently active survey form from local DB, if any.
  Future<SurveyForm?> getActiveSurveyForm() async {
    final forms = await _db.surveyDao.getActiveSurveyForms();
    return forms.isNotEmpty ? forms.first : null;
  }

  /// Get latest door statuses for all voters in a turf.
  /// Returns a map of voterId -> doorStatus.
  Future<Map<String, String>> getDoorStatusesForTurf(String turfId) async {
    final logs = await (_db.select(_db.contactLogs)
          ..where((t) =>
              t.turfId.equals(turfId) & t.contactType.equals('door_knock'))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();

    final statuses = <String, String>{};
    for (final log in logs) {
      // Only keep the latest status per voter
      statuses.putIfAbsent(log.voterId, () => log.doorStatus);
    }
    return statuses;
  }

  /// Save the complete door knock session: contact log + optional survey + optional note.
  ///
  /// Each insert is its own outbox transaction -- independently syncable.
  Future<DoorKnockResult> saveDoorKnockSession(DoorKnockSession session) async {
    final contactLogId = _generateUuid();
    final now = DateTime.now();
    final syncDao = _db.syncDao;

    // 1. Insert contact log with door_status and sentiment
    await _db.contactLogDao.insertContactLogWithOutbox(
      ContactLogsCompanion(
        id: Value(contactLogId),
        voterId: Value(session.voterId),
        turfId: Value(session.turfId),
        userId: Value(_userId),
        contactType: const Value('door_knock'),
        outcome: Value(_doorStatusToOutcome(session.doorStatus)),
        notes: Value(session.notes),
        doorStatus: Value(session.doorStatus),
        sentiment: Value(session.sentiment),
        createdAt: Value(now),
      ),
      syncDao,
    );

    // 2. If survey responses exist, insert via SurveyDao
    if (session.surveyResponses != null &&
        session.surveyResponses!.isNotEmpty &&
        session.surveyFormId != null) {
      final responseId = _generateUuid();
      await _db.surveyDao.insertResponseWithOutbox(
        SurveyResponsesCompanion(
          id: Value(responseId),
          formId: Value(session.surveyFormId!),
          formVersion: Value(session.surveyFormVersion ?? 1),
          voterId: Value(session.voterId),
          userId: Value(_userId),
          turfId: Value(session.turfId),
          contactLogId: Value(contactLogId),
          responsesJson: Value(_encodeResponses(session.surveyResponses!)),
          createdAt: Value(now),
        ),
        syncDao,
      );
    }

    // 3. If note content is non-empty, insert via VoterNoteDao
    if (session.notes.isNotEmpty) {
      final noteId = _generateUuid();
      await _db.voterNoteDao.insertNoteWithOutbox(
        VoterNotesCompanion(
          id: Value(noteId),
          voterId: Value(session.voterId),
          userId: Value(_userId),
          turfId: Value(session.turfId),
          content: Value(session.notes),
          visibility: Value(session.noteVisibility),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
        syncDao,
      );
    }

    return DoorKnockResult(
      voterId: session.voterId,
      doorStatus: session.doorStatus,
    );
  }

  /// Map door_status to an outcome string for the contact log.
  String _doorStatusToOutcome(String doorStatus) {
    switch (doorStatus) {
      case 'answered':
        return 'contact_made';
      case 'not_home':
        return 'not_home';
      case 'refused':
        return 'refused';
      case 'moved':
        return 'moved';
      default:
        return doorStatus;
    }
  }

  /// Encode survey responses map to JSON string.
  String _encodeResponses(Map<String, dynamic> responses) {
    return jsonEncode(responses);
  }
}

/// Generate a UUID v4 string without external dependency.
String _generateUuid() {
  final rng = Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  // Set version 4 (bits 12-15 of time_hi_and_version)
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  // Set variant (bits 6-7 of clock_seq_hi)
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// Riverpod provider for DoorKnockService.
final doorKnockServiceProvider = Provider<DoorKnockService>((ref) {
  return DoorKnockService(ref);
});
