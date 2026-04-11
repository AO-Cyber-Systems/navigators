import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/events.dart';
import '../tables/event_rsvps.dart';

part 'event_dao.g.dart';

@DriftAccessor(tables: [Events, EventRsvps])
class EventDao extends DatabaseAccessor<NavigatorsDatabase>
    with _$EventDaoMixin {
  EventDao(super.db);

  /// Watch upcoming events (scheduled or in_progress), ordered by start time.
  Stream<List<Event>> watchUpcomingEvents() {
    return (select(events)
          ..where((e) => e.status.isIn(['scheduled', 'in_progress']))
          ..orderBy([(e) => OrderingTerm.asc(e.startsAt)]))
        .watch();
  }

  /// Watch all events, ordered by start time descending.
  Stream<List<Event>> watchAllEvents() {
    return (select(events)
          ..orderBy([(e) => OrderingTerm.desc(e.startsAt)]))
        .watch();
  }

  /// Watch events filtered by status.
  Stream<List<Event>> watchEventsByStatus(String status) {
    return (select(events)
          ..where((e) => e.status.equals(status))
          ..orderBy([(e) => OrderingTerm.desc(e.startsAt)]))
        .watch();
  }

  /// Get a single event by ID.
  Future<Event?> getEvent(String id) {
    return (select(events)..where((e) => e.id.equals(id))).getSingleOrNull();
  }

  /// Upsert a single event (insert or update on conflict).
  Future<void> upsertEvent(EventsCompanion companion) async {
    await into(events).insertOnConflictUpdate(companion);
  }

  /// Bulk upsert events from server pull sync.
  Future<void> upsertEvents(List<EventsCompanion> items) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(events, items);
    });
  }

  /// Upsert a single RSVP.
  Future<void> upsertRSVP(EventRsvpsCompanion companion) async {
    await into(eventRsvps).insertOnConflictUpdate(companion);
  }

  /// Bulk upsert RSVPs from server pull sync.
  Future<void> upsertRSVPs(List<EventRsvpsCompanion> items) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(eventRsvps, items);
    });
  }

  /// Get all RSVPs for an event.
  Future<List<EventRsvp>> getRSVPsForEvent(String eventId) {
    return (select(eventRsvps)..where((r) => r.eventId.equals(eventId))).get();
  }

  /// Get current user's RSVP for an event.
  Future<EventRsvp?> getMyRSVP(String eventId, String userId) {
    return (select(eventRsvps)
          ..where(
              (r) => r.eventId.equals(eventId) & r.userId.equals(userId)))
        .getSingleOrNull();
  }

  /// Delete all events (for sync reset).
  Future<void> deleteAllEvents() async {
    await delete(events).go();
    await delete(eventRsvps).go();
  }
}
