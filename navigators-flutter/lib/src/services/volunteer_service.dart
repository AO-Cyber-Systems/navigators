import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:eden_platform_flutter/eden_platform.dart';

/// VolunteerService provides API client for onboarding, leaderboard, and training
/// via ConnectRPC JSON protocol.
///
/// Combines OnboardingService, LeaderboardService, and TrainingService RPCs.
class VolunteerService {
  final String _baseUrl;
  final String? Function() _getAccessToken;

  VolunteerService({
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
      String service, String method, Map<String, dynamic> body) async {
    final url = Uri.parse('$_baseUrl/navigators.v1.$service/$method');
    final response =
        await http.post(url, headers: _headers, body: jsonEncode(body));
    if (response.statusCode != 200) {
      throw Exception(
          '$method failed: ${response.statusCode} ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // --- Onboarding ---

  /// Get current user's onboarding status.
  Future<Map<String, dynamic>> getOnboardingStatus() async {
    return _post('OnboardingService', 'GetOnboardingStatus', {});
  }

  /// Acknowledge legal agreement with version string.
  Future<Map<String, dynamic>> acknowledgeLegal(String version) async {
    return _post('OnboardingService', 'AcknowledgeLegal', {
      'version': version,
    });
  }

  /// Complete onboarding (marks user as fully onboarded).
  Future<Map<String, dynamic>> completeOnboarding() async {
    return _post('OnboardingService', 'CompleteOnboarding', {});
  }

  /// Update leaderboard opt-in preference.
  Future<Map<String, dynamic>> updateLeaderboardOptIn(bool optIn) async {
    return _post('OnboardingService', 'UpdateLeaderboardOptIn', {
      'optIn': optIn,
    });
  }

  // --- Leaderboard ---

  /// Get leaderboard entries for a time window (this_week, this_month, all_time).
  Future<Map<String, dynamic>> getLeaderboard(String timeWindow) async {
    return _post('LeaderboardService', 'GetLeaderboard', {
      'timeWindow': timeWindow,
    });
  }

  // --- Training ---

  /// List all training materials.
  Future<List<Map<String, dynamic>>> listTrainingMaterials() async {
    final result =
        await _post('TrainingService', 'ListTrainingMaterials', {});
    return (result['materials'] as List<dynamic>? ?? [])
        .map((m) => m as Map<String, dynamic>)
        .toList();
  }

  /// Get a presigned download URL for a training material.
  Future<String> getTrainingDownloadUrl(String materialId) async {
    final result = await _post('TrainingService', 'GetTrainingDownloadUrl', {
      'materialId': materialId,
    });
    return result['url'] as String? ?? result['presignedUrl'] as String? ?? '';
  }

  /// Get a presigned PUT URL for direct upload of a training material to MinIO.
  /// Returns a map with keys: presignedUrl, storageKey, expiresInSeconds.
  Future<Map<String, dynamic>> getTrainingUploadUrl({
    required String filename,
    required String contentType,
  }) async {
    return _post('TrainingService', 'GetTrainingUploadUrl', {
      'filename': filename,
      'contentType': contentType,
    });
  }

  /// Create a training material metadata record pointing at an already-uploaded object.
  Future<Map<String, dynamic>> createTrainingMaterial({
    required String title,
    required String description,
    required String contentUrl,
    required int sortOrder,
  }) async {
    return _post('TrainingService', 'CreateTrainingMaterial', {
      'title': title,
      'description': description,
      'contentUrl': contentUrl,
      'sortOrder': sortOrder,
    });
  }

  /// Update an existing training material's metadata.
  Future<Map<String, dynamic>> updateTrainingMaterial({
    required String id,
    required String title,
    required String description,
    required int sortOrder,
    required bool isPublished,
  }) async {
    return _post('TrainingService', 'UpdateTrainingMaterial', {
      'id': id,
      'title': title,
      'description': description,
      'sortOrder': sortOrder,
      'isPublished': isPublished,
    });
  }

  /// Soft-delete a training material (server flips is_published=false).
  Future<void> deleteTrainingMaterial(String id) async {
    await _post('TrainingService', 'DeleteTrainingMaterial', {'id': id});
  }
}

/// Riverpod provider for VolunteerService.
final volunteerServiceProvider = Provider<VolunteerService>((ref) {
  final auth = ref.watch(authProvider);
  const envUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  final baseUrl = envUrl.isNotEmpty ? envUrl : 'http://localhost:8080';
  return VolunteerService(
    baseUrl: baseUrl,
    getAccessToken: () => auth.accessToken,
  );
});
