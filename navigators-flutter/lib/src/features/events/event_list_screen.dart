import 'package:eden_platform_flutter/eden_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../database/database.dart';
import 'event_create_screen.dart';
import 'event_detail_screen.dart';

/// Event list screen showing upcoming and past events.
///
/// Features:
/// - Filter chips: All, Upcoming, In Progress, Completed
/// - Event cards with type icon, date/time, location, RSVP count
/// - FAB for event creation (Admin/Super Navigator only)
/// - Empty state message when no events
/// - Offline-first: reads from local Drift database via EventDao
class EventListScreen extends ConsumerStatefulWidget {
  const EventListScreen({super.key});

  @override
  ConsumerState<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends ConsumerState<EventListScreen> {
  String _selectedFilter = 'upcoming';

  static const _filters = ['all', 'upcoming', 'in_progress', 'completed'];
  static const _filterLabels = {
    'all': 'All',
    'upcoming': 'Upcoming',
    'in_progress': 'In Progress',
    'completed': 'Completed',
  };

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final canCreate = _canCreateEvents(auth.role);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
      ),
      body: Column(
        children: [
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: _filters.map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(_filterLabels[filter]!),
                    selected: isSelected,
                    onSelected: (_) =>
                        setState(() => _selectedFilter = filter),
                  ),
                );
              }).toList(),
            ),
          ),
          // Event list
          Expanded(
            child: _buildEventList(),
          ),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const EventCreateScreen(),
                  ),
                );
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildEventList() {
    NavigatorsDatabase db;
    try {
      db = ref.read(databaseProvider);
    } catch (_) {
      return const Center(child: Text('Database not initialized'));
    }

    final stream = switch (_selectedFilter) {
      'upcoming' => db.eventDao.watchUpcomingEvents(),
      'all' => db.eventDao.watchAllEvents(),
      _ => db.eventDao.watchEventsByStatus(_selectedFilter),
    };

    return StreamBuilder<List<Event>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final events = snapshot.data ?? [];
        if (events.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  'No events scheduled',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: events.length,
          itemBuilder: (context, index) => _EventCard(
            event: events[index],
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      EventDetailScreen(eventId: events[index].id),
                ),
              );
            },
          ),
        );
      },
    );
  }

  bool _canCreateEvents(String? role) {
    if (role == null) return false;
    final lower = role.toLowerCase();
    return lower == 'admin' || lower == 'manager' || lower == 'super_navigator';
  }
}

/// Individual event card widget.
class _EventCard extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;

  const _EventCard({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row with type icon
              Row(
                children: [
                  Icon(
                    _eventTypeIcon(event.eventType),
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      event.title,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _StatusChip(status: event.status),
                ],
              ),
              const SizedBox(height: 8),
              // Date/time and location
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${DateFormat.MMMd().format(event.startsAt)} '
                    '${DateFormat.jm().format(event.startsAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  if (event.rsvpCount > 0) ...[
                    Icon(
                      Icons.people_outline,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${event.rsvpCount} RSVPs',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
              if (event.locationName != null &&
                  event.locationName!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        event.locationName!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _eventTypeIcon(String type) {
    switch (type) {
      case 'canvass':
        return Icons.directions_walk;
      case 'phone_bank':
        return Icons.phone;
      case 'meeting':
        return Icons.groups;
      default:
        return Icons.event;
    }
  }
}

/// Status chip for event status.
class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'scheduled' => (Colors.blue, 'Scheduled'),
      'in_progress' => (Colors.green, 'In Progress'),
      'completed' => (Colors.grey, 'Completed'),
      'cancelled' => (Colors.red, 'Cancelled'),
      _ => (Colors.grey, status),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
