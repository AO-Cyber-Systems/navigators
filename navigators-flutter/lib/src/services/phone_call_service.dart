import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eden_platform_flutter/eden_platform.dart';

import '../database/database.dart';

/// Result returned from a phone call session, used to update UI.
class PhoneCallResult {
  final String voterId;
  final String callStatus;

  const PhoneCallResult({
    required this.voterId,
    required this.callStatus,
  });
}

/// Parameters for a full phone call session save.
class PhoneCallSession {
  final String voterId;
  final String turfId;

  /// One of: answered, voicemail, no_answer, refused, busy.
  final String callStatus;
  final int? sentiment;
  final String notes;

  /// Note visibility: 'private', 'team', or 'org'.
  final String noteVisibility;

  const PhoneCallSession({
    required this.voterId,
    required this.turfId,
    required this.callStatus,
    this.sentiment,
    this.notes = '',
    this.noteVisibility = 'team',
  });
}

/// Business logic orchestrating phone call recording and notes.
///
/// Mirrors [DoorKnockService] -- each insert uses the outbox pattern for
/// offline-first sync. Contact log and voter note are independent outbox
/// entries so each can sync independently.
class PhoneCallService {
  final Ref _ref;

  PhoneCallService(this._ref);

  NavigatorsDatabase get _db => _ref.read(databaseProvider);

  String get _userId {
    final auth = _ref.read(authProvider);
    return auth.userId ?? '';
  }

  /// Get the currently active call script from local DB, if any.
  Future<CallScript?> getActiveCallScript() async {
    final scripts = await _db.callScriptDao.getActiveCallScripts();
    return scripts.isNotEmpty ? scripts.first : null;
  }

  /// Save the complete phone call session: contact log + optional note.
  ///
  /// Each insert is its own outbox transaction -- independently syncable.
  Future<PhoneCallResult> savePhoneCallSession(
      PhoneCallSession session) async {
    final contactLogId = _generateUuid();
    final now = DateTime.now();
    final syncDao = _db.syncDao;

    // 1. Insert contact log with phone disposition and sentiment
    await _db.contactLogDao.insertContactLogWithOutbox(
      ContactLogsCompanion(
        id: Value(contactLogId),
        voterId: Value(session.voterId),
        turfId: Value(session.turfId),
        userId: Value(_userId),
        contactType: const Value('phone'),
        outcome: Value(_callStatusToOutcome(session.callStatus)),
        notes: Value(session.notes),
        doorStatus: Value(session.callStatus),
        sentiment: Value(session.sentiment),
        createdAt: Value(now),
      ),
      syncDao,
    );

    // 2. If note content is non-empty, insert via VoterNoteDao
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

    return PhoneCallResult(
      voterId: session.voterId,
      callStatus: session.callStatus,
    );
  }

  /// Map call status to an outcome string for the contact log.
  String _callStatusToOutcome(String callStatus) {
    switch (callStatus) {
      case 'answered':
        return 'contact_made';
      case 'voicemail':
        return 'voicemail';
      case 'no_answer':
        return 'not_home';
      case 'refused':
        return 'refused';
      case 'busy':
        return 'busy';
      default:
        return callStatus;
    }
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

/// Riverpod provider for PhoneCallService.
final phoneCallServiceProvider = Provider<PhoneCallService>((ref) {
  return PhoneCallService(ref);
});
