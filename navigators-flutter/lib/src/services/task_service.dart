import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:eden_platform_flutter/eden_platform.dart';

/// TaskService provides API client for task CRUD operations via ConnectRPC JSON protocol.
///
/// Follows the same pattern as VoterService and SyncClient: POST with JSON body
/// to the server's ConnectRPC endpoints.
class TaskService {
  final String _baseUrl;
  final String? Function() _getAccessToken;

  TaskService({
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
    final url = Uri.parse('$_baseUrl/navigators.v1.TaskService/$method');
    final response =
        await http.post(url, headers: _headers, body: jsonEncode(body));
    if (response.statusCode != 200) {
      throw Exception(
          '$method failed: ${response.statusCode} ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Create a new task with assignments.
  Future<Map<String, dynamic>> createTask({
    required String title,
    String description = '',
    required String taskType,
    String priority = 'medium',
    String? dueDate,
    String? linkedEntityType,
    String? linkedEntityId,
    List<String> assigneeIds = const [],
  }) async {
    final body = <String, dynamic>{
      'title': title,
      'description': description,
      'taskType': taskType,
      'priority': priority,
      'assigneeIds': assigneeIds,
    };
    if (dueDate != null) body['dueDate'] = dueDate;
    if (linkedEntityType != null) body['linkedEntityType'] = linkedEntityType;
    if (linkedEntityId != null) body['linkedEntityId'] = linkedEntityId;

    return _post('CreateTask', body);
  }

  /// Assign a task to a user.
  Future<void> assignTask(String taskId, String userId) async {
    await _post('AssignTask', {
      'taskId': taskId,
      'userId': userId,
    });
  }

  /// Create a note on a task.
  Future<void> createTaskNote(String taskId, String content,
      {String visibility = 'team'}) async {
    await _post('CreateTaskNote', {
      'taskId': taskId,
      'content': content,
      'visibility': visibility,
    });
  }

  /// List tasks for the current user.
  Future<List<Map<String, dynamic>>> listTasks() async {
    final result = await _post('ListTasks', {});
    return (result['tasks'] as List<dynamic>? ?? [])
        .map((t) => t as Map<String, dynamic>)
        .toList();
  }

  /// Get a single task by ID.
  Future<Map<String, dynamic>> getTask(String taskId) async {
    return _post('GetTask', {'taskId': taskId});
  }

  /// List company members (for task assignment picker).
  Future<List<Map<String, dynamic>>> listCompanyMembers() async {
    final result = await _post('ListCompanyMembers', {});
    return (result['members'] as List<dynamic>? ?? [])
        .map((m) => m as Map<String, dynamic>)
        .toList();
  }
}

/// Riverpod provider for TaskService.
final taskServiceProvider = Provider<TaskService>((ref) {
  final auth = ref.watch(authProvider);
  const envUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  final baseUrl = envUrl.isNotEmpty ? envUrl : 'http://localhost:8080';
  return TaskService(
    baseUrl: baseUrl,
    getAccessToken: () => auth.accessToken,
  );
});
