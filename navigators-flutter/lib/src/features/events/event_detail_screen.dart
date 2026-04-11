import 'package:eden_platform_flutter/eden_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../database/database.dart';
import '../../services/event_service.dart';

/// Event detail screen showing full event info with RSVP and check-in actions.
///
/// Features:
/// - Event header with type chip and status
/// - Date/time range, location with map link
/// - Description text
/// - RSVP buttons (Going / Maybe / Decline)
/// - Check-in button (in_progress events, going RSVP only)
/// - Attendance list with check-in indicators
class EventDetailScreen extends ConsumerStatefulWidget {
  final String eventId;

  const EventDetailScreen({super.key, required this.eventId});

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  Event? _event;
  String? _myRsvpStatus;
  List<dynamic> _attendees = [];
  bool _isLoading = true;
  bool _isRsvping = false;
  bool _isCheckingIn = false;

  @override
  void initState() {
    super.initState();
    _loadEvent();
  }

  Future<void> _loadEvent() async {
    try {
      final db = ref.read(databaseProvider);
      final auth = ref.read(authProvider);
      final event = await db.eventDao.getEvent(widget.eventId);

      EventRsvp? myRsvp;
      if (event != null && auth.userId != null) {
        myRsvp = await db.eventDao.getMyRSVP(widget.eventId, auth.userId!);
      }

      // Fetch attendance from API
      List<dynamic> attendees = [];
      try {
        final eventService = ref.read(eventServiceProvider);
        final attendance =
            await eventService.getEventAttendance(widget.eventId);
        attendees = attendance['attendees'] as List<dynamic>? ?? [];
      } catch (_) {
        // Attendance is online-only; degrade gracefully
      }

      if (mounted) {
        setState(() {
          _event = event;
          _myRsvpStatus = myRsvp?.status;
          _attendees = attendees;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleRsvp(String status) async {
    setState(() => _isRsvping = true);
    try {
      final eventService = ref.read(eventServiceProvider);
      await eventService.rsvpEvent(widget.eventId, status);
      setState(() => _myRsvpStatus = status);
      _loadEvent(); // Refresh attendance
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('RSVP failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRsvping = false);
    }
  }

  Future<void> _handleCheckIn() async {
    setState(() => _isCheckingIn = true);
    try {
      final eventService = ref.read(eventServiceProvider);
      await eventService.checkInEvent(widget.eventId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Checked in successfully!')),
        );
      }
      _loadEvent(); // Refresh attendance
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Check-in failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingIn = false);
    }
  }

  void _openMapLocation() {
    if (_event?.locationLat != null && _event?.locationLng != null) {
      final url = Uri.parse(
          'https://maps.google.com/?q=${_event!.locationLat},${_event!.locationLng}');
      launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_event?.title ?? 'Event Details'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _event == null
              ? const Center(child: Text('Event not found'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Type and status chips
                    Row(
                      children: [
                        Chip(
                          avatar: Icon(
                            _eventTypeIcon(_event!.eventType),
                            size: 16,
                          ),
                          label: Text(_eventTypeLabel(_event!.eventType)),
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(
                              _event!.status[0].toUpperCase() +
                                  _event!.status.substring(1).replaceAll('_', ' ')),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Date/time
                    _InfoRow(
                      icon: Icons.schedule,
                      label:
                          '${DateFormat.yMMMd().format(_event!.startsAt)} '
                          '${DateFormat.jm().format(_event!.startsAt)} - '
                          '${DateFormat.jm().format(_event!.endsAt)}',
                    ),

                    // Location
                    if (_event!.locationName != null &&
                        _event!.locationName!.isNotEmpty)
                      _InfoRow(
                        icon: Icons.location_on_outlined,
                        label: _event!.locationName!,
                        onTap: _event!.locationLat != null
                            ? _openMapLocation
                            : null,
                      ),

                    const SizedBox(height: 16),

                    // Description
                    if (_event!.description.isNotEmpty) ...[
                      Text(
                        _event!.description,
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 24),
                    ],

                    // RSVP section
                    Text(
                      'RSVP',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _RsvpButton(
                            label: 'Going',
                            icon: Icons.check_circle_outline,
                            isSelected: _myRsvpStatus == 'going',
                            isLoading: _isRsvping,
                            onPressed: () => _handleRsvp('going'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _RsvpButton(
                            label: 'Maybe',
                            icon: Icons.help_outline,
                            isSelected: _myRsvpStatus == 'maybe',
                            isLoading: _isRsvping,
                            onPressed: () => _handleRsvp('maybe'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _RsvpButton(
                            label: 'Decline',
                            icon: Icons.cancel_outlined,
                            isSelected: _myRsvpStatus == 'declined',
                            isLoading: _isRsvping,
                            onPressed: () => _handleRsvp('declined'),
                          ),
                        ),
                      ],
                    ),

                    // Check-in button
                    if (_event!.status == 'in_progress' &&
                        _myRsvpStatus == 'going') ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: _isCheckingIn ? null : _handleCheckIn,
                          icon: _isCheckingIn
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.login),
                          label: const Text('Check In'),
                        ),
                      ),
                    ],

                    // Attendance list
                    if (_attendees.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Attendance (${_attendees.length})',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ..._attendees.map((a) {
                        final attendee = a as Map<String, dynamic>;
                        final name =
                            attendee['displayName'] as String? ?? 'Unknown';
                        final rsvpStatus =
                            attendee['rsvpStatus'] as String? ?? '';
                        final checkedIn =
                            attendee['checkedIn'] as bool? ?? false;

                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                            ),
                          ),
                          title: Text(name),
                          subtitle: Text(rsvpStatus),
                          trailing: checkedIn
                              ? Icon(
                                  Icons.check_circle,
                                  color: theme.colorScheme.primary,
                                )
                              : null,
                          dense: true,
                        );
                      }),
                    ],
                  ],
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

  String _eventTypeLabel(String type) {
    switch (type) {
      case 'canvass':
        return 'Canvass';
      case 'phone_bank':
        return 'Phone Bank';
      case 'meeting':
        return 'Meeting';
      default:
        return 'Event';
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _InfoRow({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final child = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: onTap != null
                    ? theme.colorScheme.primary
                    : null,
                decoration:
                    onTap != null ? TextDecoration.underline : null,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: child);
    }
    return child;
  }
}

class _RsvpButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final bool isLoading;
  final VoidCallback onPressed;

  const _RsvpButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return isSelected
        ? FilledButton.icon(
            onPressed: isLoading ? null : onPressed,
            icon: Icon(icon, size: 16),
            label: Text(label),
          )
        : OutlinedButton.icon(
            onPressed: isLoading ? null : onPressed,
            icon: Icon(icon, size: 16),
            label: Text(label),
          );
  }
}
