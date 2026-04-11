import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';

/// A single entry in the unified voter contact timeline.
class TimelineEntry {
  final String id;

  /// One of: 'door_knock', 'note', 'survey', 'phone', 'text'
  final String type;
  final DateTime timestamp;

  /// User ID of the actor (display name resolution deferred to server).
  final String actorName;

  /// Human-readable one-line summary of the interaction.
  final String summary;
  final IconData icon;
  final Color iconColor;

  /// Extra data such as sentiment, door_status, visibility, etc.
  final Map<String, dynamic>? details;

  const TimelineEntry({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.actorName,
    required this.summary,
    required this.icon,
    required this.iconColor,
    this.details,
  });
}

/// A single sentiment data point for sparkline/dot visualization.
class SentimentPoint {
  final DateTime timestamp;
  final int value; // 1-5

  const SentimentPoint({required this.timestamp, required this.value});
}

// ---------------------------------------------------------------------------
// Mapping helpers
// ---------------------------------------------------------------------------

TimelineEntry _contactLogToTimeline(ContactLog log) {
  final IconData icon;
  final Color color;
  final String typeSummary;

  switch (log.contactType) {
    case 'door_knock':
      icon = Icons.door_front_door;
      switch (log.doorStatus) {
        case 'answered':
          color = Colors.green;
          typeSummary = 'Door Knock - Answered';
        case 'not_home':
          color = Colors.grey;
          typeSummary = 'Door Knock - Not Home';
        case 'refused':
          color = Colors.red;
          typeSummary = 'Door Knock - Refused';
        case 'moved':
          color = Colors.orange;
          typeSummary = 'Door Knock - Moved';
        default:
          color = Colors.grey;
          typeSummary = 'Door Knock';
      }
    case 'phone':
      icon = Icons.phone;
      color = Colors.blue;
      typeSummary = 'Phone Call';
    case 'text':
      icon = Icons.sms;
      color = Colors.teal;
      typeSummary = 'Text Message';
    default:
      icon = Icons.contact_page;
      color = Colors.blueGrey;
      typeSummary = 'Contact';
  }

  final parts = <String>[typeSummary];
  if (log.sentiment != null) {
    parts.add('Sentiment: ${log.sentiment}/5');
  }
  if (log.notes.isNotEmpty) {
    final preview =
        log.notes.length > 60 ? '${log.notes.substring(0, 60)}...' : log.notes;
    parts.add(preview);
  }

  return TimelineEntry(
    id: log.id,
    type: log.contactType,
    timestamp: log.createdAt,
    actorName: log.userId,
    summary: parts.join('. '),
    icon: icon,
    iconColor: color,
    details: {
      'door_status': log.doorStatus,
      if (log.sentiment != null) 'sentiment': log.sentiment,
      'outcome': log.outcome,
    },
  );
}

TimelineEntry _voterNoteToTimeline(VoterNote note) {
  final preview = note.content.length > 80
      ? '${note.content.substring(0, 80)}...'
      : note.content;

  return TimelineEntry(
    id: note.id,
    type: 'note',
    timestamp: note.createdAt,
    actorName: note.userId,
    summary: preview,
    icon: Icons.note,
    iconColor: Colors.amber,
    details: {
      'visibility': note.visibility,
    },
  );
}

TimelineEntry _surveyResponseToTimeline(SurveyResponse response) {
  return TimelineEntry(
    id: response.id,
    type: 'survey',
    timestamp: response.createdAt,
    actorName: response.userId,
    summary: 'Completed survey (form ${response.formId})',
    icon: Icons.assignment,
    iconColor: Colors.purple,
    details: {
      'form_id': response.formId,
      'form_version': response.formVersion,
    },
  );
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Merges contact_logs + voter_notes + survey_responses for a voter into a
/// single chronological timeline, newest first.
///
/// Uses [StreamZip] to combine the three Drift watch streams and re-sorts
/// on every emission.
final voterTimelineProvider =
    StreamProvider.family<List<TimelineEntry>, String>((ref, voterId) {
  final db = ref.read(databaseProvider);

  final contactStream = db.contactLogDao.watchContactLogsForVoter(voterId);
  final noteStream = db.voterNoteDao.watchNotesForVoter(voterId);
  final surveyStream = db.surveyDao.watchResponsesForVoter(voterId);

  // Hold latest snapshot from each stream and re-merge on any change.
  List<ContactLog> latestContacts = [];
  List<VoterNote> latestNotes = [];
  List<SurveyResponse> latestSurveys = [];

  final controller = StreamController<List<TimelineEntry>>();

  void emit() {
    final entries = <TimelineEntry>[
      ...latestContacts.map(_contactLogToTimeline),
      ...latestNotes.map(_voterNoteToTimeline),
      ...latestSurveys.map(_surveyResponseToTimeline),
    ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    controller.add(entries);
  }

  final sub1 = contactStream.listen((data) {
    latestContacts = data;
    emit();
  });
  final sub2 = noteStream.listen((data) {
    latestNotes = data;
    emit();
  });
  final sub3 = surveyStream.listen((data) {
    latestSurveys = data;
    emit();
  });

  ref.onDispose(() {
    sub1.cancel();
    sub2.cancel();
    sub3.cancel();
    controller.close();
  });

  return controller.stream;
});

/// Door knock attempt count for a voter.
final doorKnockCountProvider =
    FutureProvider.family<int, String>((ref, voterId) {
  return ref.read(databaseProvider).contactLogDao.getDoorKnockCountForVoter(voterId);
});

/// Sentiment history for a voter: list of (timestamp, value) from door knock
/// contact logs where sentiment is not null, ordered oldest-first for display.
final sentimentHistoryProvider =
    StreamProvider.family<List<SentimentPoint>, String>((ref, voterId) {
  final db = ref.read(databaseProvider);
  return db.contactLogDao.watchDoorKnockHistoryForVoter(voterId).map((logs) {
    return logs
        .where((log) => log.sentiment != null)
        .map((log) => SentimentPoint(
              timestamp: log.createdAt,
              value: log.sentiment!,
            ))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  });
});
