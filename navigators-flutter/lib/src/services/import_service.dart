import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:eden_platform_flutter/eden_platform.dart';

// --- Models ---

class ImportJob {
  final String id;
  final String uploadedBy;
  final String fileName;
  final String sourceType;
  final String status;
  final int totalRows;
  final int parsedRows;
  final int mergedRows;
  final int skippedRows;
  final int errorRows;
  final int geocodedRows;
  final String errors;
  final String fieldMapping;
  final String createdAt;
  final String updatedAt;

  const ImportJob({
    required this.id,
    required this.uploadedBy,
    required this.fileName,
    required this.sourceType,
    required this.status,
    required this.totalRows,
    required this.parsedRows,
    required this.mergedRows,
    required this.skippedRows,
    required this.errorRows,
    required this.geocodedRows,
    required this.errors,
    required this.fieldMapping,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ImportJob.fromJson(Map<String, dynamic> json) {
    return ImportJob(
      id: json['id'] as String? ?? '',
      uploadedBy: json['uploadedBy'] as String? ?? '',
      fileName: json['fileName'] as String? ?? '',
      sourceType: json['sourceType'] as String? ?? '',
      status: json['status'] as String? ?? '',
      totalRows: (json['totalRows'] as num?)?.toInt() ?? 0,
      parsedRows: (json['parsedRows'] as num?)?.toInt() ?? 0,
      mergedRows: (json['mergedRows'] as num?)?.toInt() ?? 0,
      skippedRows: (json['skippedRows'] as num?)?.toInt() ?? 0,
      errorRows: (json['errorRows'] as num?)?.toInt() ?? 0,
      geocodedRows: (json['geocodedRows'] as num?)?.toInt() ?? 0,
      errors: json['errors'] as String? ?? '',
      fieldMapping: json['fieldMapping'] as String? ?? '{}',
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }

  bool get isActive =>
      status == 'pending' ||
      status == 'parsing' ||
      status == 'staging' ||
      status == 'merging' ||
      status == 'geocoding';

  bool get isComplete => status == 'complete';
  bool get isFailed => status == 'failed';

  double get progress {
    if (totalRows <= 0) return 0;
    return parsedRows / totalRows;
  }

  List<String> get errorList {
    if (errors.isEmpty) return [];
    try {
      final list = jsonDecode(errors) as List<dynamic>;
      return list.map((e) => e.toString()).toList();
    } catch (_) {
      return errors.isNotEmpty ? [errors] : [];
    }
  }
}

// --- Service ---

class ImportService {
  final String _baseUrl;
  final String? Function() _getAccessToken;

  ImportService({required String baseUrl, required String? Function() getAccessToken})
      : _baseUrl = baseUrl,
        _getAccessToken = getAccessToken;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_getAccessToken() != null) 'Authorization': 'Bearer ${_getAccessToken()}',
      };

  Future<Map<String, dynamic>> _post(String method, Map<String, dynamic> body) async {
    final url = Uri.parse('$_baseUrl/navigators.v1.VoterImportService/$method');
    final response = await http.post(url, headers: _headers, body: jsonEncode(body));
    if (response.statusCode != 200) {
      throw Exception('$method failed: ${response.statusCode} ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Starts an import job and returns the job ID and presigned upload URL.
  Future<({String jobId, String uploadUrl})> startImport({
    required String fileName,
    required String sourceType,
    Map<String, String>? fieldMapping,
  }) async {
    final result = await _post('StartImport', {
      'fileName': fileName,
      'sourceType': sourceType,
      'fieldMapping': fieldMapping != null ? jsonEncode(fieldMapping) : '{}',
    });
    return (
      jobId: result['jobId'] as String? ?? '',
      uploadUrl: result['uploadUrl'] as String? ?? '',
    );
  }

  /// Uploads a file directly to the presigned MinIO URL.
  Future<void> uploadFileToPresignedUrl(String url, Uint8List fileBytes) async {
    final response = await http.put(
      Uri.parse(url),
      headers: {'Content-Type': 'application/octet-stream'},
      body: fileBytes,
    );
    if (response.statusCode != 200) {
      throw Exception('File upload failed: ${response.statusCode}');
    }
  }

  /// Confirms the upload is complete, triggering server-side processing.
  Future<void> confirmUpload(String jobId) async {
    await _post('ConfirmUpload', {'jobId': jobId});
  }

  /// Gets the current status of an import job.
  Future<ImportJob> getImportStatus(String jobId) async {
    final result = await _post('GetImportStatus', {'jobId': jobId});
    return ImportJob.fromJson(result['job'] as Map<String, dynamic>? ?? {});
  }

  /// Lists all import jobs.
  Future<({List<ImportJob> jobs, int totalCount})> listImportJobs({
    int pageSize = 20,
    int page = 0,
  }) async {
    final result = await _post('ListImportJobs', {
      'pageSize': pageSize,
      'page': page,
    });
    final jobs = (result['jobs'] as List<dynamic>? ?? [])
        .map((j) => ImportJob.fromJson(j as Map<String, dynamic>))
        .toList();
    final totalCount = (result['totalCount'] as num?)?.toInt() ?? 0;
    return (jobs: jobs, totalCount: totalCount);
  }
}

// --- Providers ---

final importServiceProvider = Provider<ImportService>((ref) {
  final auth = ref.watch(authProvider);
  const envUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  final baseUrl = envUrl.isNotEmpty ? envUrl : 'http://localhost:8080';
  return ImportService(
    baseUrl: baseUrl,
    getAccessToken: () => auth.accessToken,
  );
});

// --- Import jobs state ---

class ImportJobsState {
  final List<ImportJob> jobs;
  final bool isLoading;
  final String? error;

  const ImportJobsState({
    this.jobs = const [],
    this.isLoading = false,
    this.error,
  });

  ImportJobsState copyWith({
    List<ImportJob>? jobs,
    bool? isLoading,
    String? error,
  }) {
    return ImportJobsState(
      jobs: jobs ?? this.jobs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ImportJobsNotifier extends StateNotifier<ImportJobsState> {
  final ImportService _service;
  Timer? _pollTimer;

  ImportJobsNotifier(this._service) : super(const ImportJobsState());

  Future<void> loadJobs() async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await _service.listImportJobs();
      state = state.copyWith(jobs: result.jobs, isLoading: false);
      _startPollingIfNeeded();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refreshJob(String jobId) async {
    try {
      final updated = await _service.getImportStatus(jobId);
      final jobs = state.jobs.map((j) => j.id == jobId ? updated : j).toList();
      state = state.copyWith(jobs: jobs);
      _startPollingIfNeeded();
    } catch (_) {
      // Silently ignore single job refresh failures
    }
  }

  void _startPollingIfNeeded() {
    _pollTimer?.cancel();
    final hasActive = state.jobs.any((j) => j.isActive);
    if (hasActive) {
      _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollActiveJobs());
    }
  }

  Future<void> _pollActiveJobs() async {
    int failCount = 0;
    for (final job in state.jobs.where((j) => j.isActive)) {
      try {
        await refreshJob(job.id);
      } catch (_) {
        failCount++;
      }
    }
    // Stop polling if 3 consecutive failures
    if (failCount >= 3) {
      _pollTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}

final importJobsProvider =
    StateNotifierProvider<ImportJobsNotifier, ImportJobsState>((ref) {
  return ImportJobsNotifier(ref.watch(importServiceProvider));
});
