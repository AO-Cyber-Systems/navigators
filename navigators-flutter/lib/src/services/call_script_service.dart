import 'dart:convert';

import 'package:eden_platform_flutter/eden_platform.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// CallScriptService provides API client for admin call script CRUD
/// via ConnectRPC JSON protocol.
///
/// Mutations require admin role (RoleLevel >= 80) server-side. Non-admin
/// callers will receive PermissionDenied.
///
/// Reads in the app normally come from the local Drift cache populated by
/// SyncService.PullCallScripts; this client exists for admin mutation flows
/// and, optionally, a live management view.
class CallScriptService {
  final String _baseUrl;
  final String? Function() _getAccessToken;

  CallScriptService({
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
    final url =
        Uri.parse('$_baseUrl/navigators.v1.CallScriptService/$method');
    final response =
        await http.post(url, headers: _headers, body: jsonEncode(body));
    if (response.statusCode != 200) {
      throw Exception(
          '$method failed: ${response.statusCode} ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Create a new call script.
  Future<Map<String, dynamic>> createCallScript({
    required String title,
    required String content,
  }) {
    return _post('CreateCallScript', {
      'title': title,
      'content': content,
    });
  }

  /// Update a call script's title/content/active state.
  Future<Map<String, dynamic>> updateCallScript({
    required String id,
    required String title,
    required String content,
    required bool isActive,
  }) {
    return _post('UpdateCallScript', {
      'id': id,
      'title': title,
      'content': content,
      'isActive': isActive,
    });
  }

  /// Soft-delete (deactivate) a call script.
  Future<void> deactivateCallScript(String id) async {
    await _post('DeactivateCallScript', {'id': id});
  }

  /// List all call scripts for the admin management view.
  /// When [includeInactive] is false, returns only active scripts.
  Future<List<Map<String, dynamic>>> listCallScripts({
    bool includeInactive = false,
  }) async {
    final result = await _post(
        'ListCallScripts', {'includeInactive': includeInactive});
    return (result['scripts'] as List<dynamic>? ?? [])
        .map((s) => s as Map<String, dynamic>)
        .toList();
  }
}

/// Riverpod provider for CallScriptService.
final callScriptServiceProvider = Provider<CallScriptService>((ref) {
  final auth = ref.watch(authProvider);
  const envUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  final baseUrl = envUrl.isNotEmpty ? envUrl : 'http://localhost:8080';
  return CallScriptService(
    baseUrl: baseUrl,
    getAccessToken: () => auth.accessToken,
  );
});
