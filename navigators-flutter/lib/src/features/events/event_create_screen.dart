import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../services/event_service.dart';

/// Event creation screen for Admin and Super Navigator roles.
///
/// Form fields: title, description, event type, start/end date+time,
/// location name, max attendees.
class EventCreateScreen extends ConsumerStatefulWidget {
  const EventCreateScreen({super.key});

  @override
  ConsumerState<EventCreateScreen> createState() => _EventCreateScreenState();
}

class _EventCreateScreenState extends ConsumerState<EventCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _maxAttendeesController = TextEditingController();

  String _eventType = 'meeting';
  DateTime? _startsAt;
  DateTime? _endsAt;
  bool _isSubmitting = false;

  static const _eventTypes = {
    'canvass': 'Canvass',
    'phone_bank': 'Phone Bank',
    'meeting': 'Meeting',
    'other': 'Other',
  };

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _maxAttendeesController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_startsAt ?? now)
          : (_endsAt ?? _startsAt ?? now),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        isStart ? (_startsAt ?? now) : (_endsAt ?? now),
      ),
    );
    if (time == null || !mounted) return;

    final dateTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() {
      if (isStart) {
        _startsAt = dateTime;
        // Auto-set end to 2 hours after start if not set
        if (_endsAt == null || _endsAt!.isBefore(dateTime)) {
          _endsAt = dateTime.add(const Duration(hours: 2));
        }
      } else {
        _endsAt = dateTime;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Event'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title *',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().length < 3) {
                  return 'Title must be at least 3 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Event Type
            DropdownButtonFormField<String>(
              initialValue: _eventType,
              decoration: const InputDecoration(
                labelText: 'Event Type',
                border: OutlineInputBorder(),
              ),
              items: _eventTypes.entries
                  .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _eventType = v!),
            ),
            const SizedBox(height: 16),

            // Start Date/Time
            TextFormField(
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Starts At *',
                border: const OutlineInputBorder(),
                suffixIcon: const Icon(Icons.calendar_today),
                hintText: 'Select date and time',
              ),
              controller: TextEditingController(
                text: _startsAt != null
                    ? '${DateFormat.yMMMd().format(_startsAt!)} ${DateFormat.jm().format(_startsAt!)}'
                    : '',
              ),
              onTap: () => _pickDateTime(isStart: true),
              validator: (_) {
                if (_startsAt == null) return 'Start date is required';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // End Date/Time
            TextFormField(
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Ends At *',
                border: const OutlineInputBorder(),
                suffixIcon: const Icon(Icons.calendar_today),
                hintText: 'Select date and time',
              ),
              controller: TextEditingController(
                text: _endsAt != null
                    ? '${DateFormat.yMMMd().format(_endsAt!)} ${DateFormat.jm().format(_endsAt!)}'
                    : '',
              ),
              onTap: () => _pickDateTime(isStart: false),
              validator: (_) {
                if (_endsAt == null) return 'End date is required';
                if (_startsAt != null && _endsAt!.isBefore(_startsAt!)) {
                  return 'End must be after start';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Location
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Max Attendees
            TextFormField(
              controller: _maxAttendeesController,
              decoration: const InputDecoration(
                labelText: 'Max Attendees (optional)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final n = int.tryParse(value);
                  if (n == null || n < 1) {
                    return 'Must be a positive number';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Submit
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Create Event'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final eventService = ref.read(eventServiceProvider);
      final maxStr = _maxAttendeesController.text.trim();

      await eventService.createEvent(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        eventType: _eventType,
        startsAt: _startsAt!.toUtc().toIso8601String(),
        endsAt: _endsAt!.toUtc().toIso8601String(),
        locationName: _locationController.text.trim().isNotEmpty
            ? _locationController.text.trim()
            : null,
        maxAttendees: maxStr.isNotEmpty ? int.tryParse(maxStr) : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event created successfully')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create event: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
