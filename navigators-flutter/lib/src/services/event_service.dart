import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:eden_platform_flutter/eden_platform.dart';

/// EventService provides API client for event management via ConnectRPC JSON protocol.
///
/// All operations are online-only (RSVP and check-in require real-time coordination).
class EventService {
  final String _baseUrl;
  final String? Function() _getAccessToken;

  EventService({
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
    final url = Uri.parse('$_baseUrl/navigators.v1.EventService/$method');
    final response =
        await http.post(url, headers: _headers, body: jsonEncode(body));
    if (response.statusCode != 200) {
      throw Exception(
          '$method failed: ${response.statusCode} ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Create a new event.
  Future<Map<String, dynamic>> createEvent({
    required String title,
    String description = '',
    required String eventType,
    required String startsAt,
    required String endsAt,
    String? locationName,
    double? locationLat,
    double? locationLng,
    String? linkedTurfId,
    int? maxAttendees,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      'description': description,
      'eventType': eventType,
      'startsAt': startsAt,
      'endsAt': endsAt,
    };
    if (locationName != null) body['locationName'] = locationName;
    if (locationLat != null) body['locationLat'] = locationLat;
    if (locationLng != null) body['locationLng'] = locationLng;
    if (linkedTurfId != null) body['linkedTurfId'] = linkedTurfId;
    if (maxAttendees != null) body['maxAttendees'] = maxAttendees;

    return _post('CreateEvent', body);
  }

  /// List all events.
  Future<List<Map<String, dynamic>>> listEvents() async {
    final result = await _post('ListEvents', {});
    return (result['events'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  /// Get a single event by ID.
  Future<Map<String, dynamic>> getEvent(String eventId) async {
    return _post('GetEvent', {'eventId': eventId});
  }

  /// RSVP to an event with status (going, maybe, declined).
  Future<Map<String, dynamic>> rsvpEvent(
      String eventId, String status) async {
    return _post('RSVPEvent', {
      'eventId': eventId,
      'status': status,
    });
  }

  /// Check in to an event.
  Future<Map<String, dynamic>> checkInEvent(String eventId) async {
    return _post('CheckInEvent', {'eventId': eventId});
  }

  /// Get event attendance (RSVPs and check-ins).
  Future<Map<String, dynamic>> getEventAttendance(String eventId) async {
    return _post('GetEventAttendance', {'eventId': eventId});
  }
}

/// Riverpod provider for EventService.
final eventServiceProvider = Provider<EventService>((ref) {
  final auth = ref.watch(authProvider);
  const envUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  final baseUrl = envUrl.isNotEmpty ? envUrl : 'http://localhost:8080';
  return EventService(
    baseUrl: baseUrl,
    getAccessToken: () => auth.accessToken,
  );
});
