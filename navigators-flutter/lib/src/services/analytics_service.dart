import 'dart:convert';
import 'dart:typed_data';

import 'package:eden_platform_flutter/eden_platform.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Data classes for analytics responses.

/// Parse a JSON value that may be a num or a string-encoded number.
int _parseInt(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

double _parseDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}

class DashboardMetrics {
  final int doorsKnocked;
  final int callsMade;
  final int textsSent;
  final double contactRate;
  final int totalVoters;
  final int contactedVoters;
  final Map<int, int> sentimentDistribution;
  final int totalTasks;
  final int completedTasks;
  final List<TurfSummary> turfSummaries;

  const DashboardMetrics({
    required this.doorsKnocked,
    required this.callsMade,
    required this.textsSent,
    required this.contactRate,
    required this.totalVoters,
    required this.contactedVoters,
    required this.sentimentDistribution,
    required this.totalTasks,
    required this.completedTasks,
    required this.turfSummaries,
  });

  factory DashboardMetrics.fromJson(Map<String, dynamic> json) {
    final sentimentList = json['sentimentDistribution'] as List<dynamic>? ?? [];
    final sentimentMap = <int, int>{};
    for (final bucket in sentimentList) {
      final b = bucket as Map<String, dynamic>;
      sentimentMap[_parseInt(b['sentiment'])] = _parseInt(b['count']);
    }

    final turfList = json['turfSummaries'] as List<dynamic>? ?? [];
    final turfs = turfList
        .map((t) => TurfSummary.fromJson(t as Map<String, dynamic>))
        .toList();

    return DashboardMetrics(
      doorsKnocked: _parseInt(json['doorsKnocked']),
      callsMade: _parseInt(json['callsMade']),
      textsSent: _parseInt(json['textsSent']),
      contactRate: _parseDouble(json['contactRate']),
      totalVoters: _parseInt(json['totalVoters']),
      contactedVoters: _parseInt(json['contactedVoters']),
      sentimentDistribution: sentimentMap,
      totalTasks: _parseInt(json['totalTasks']),
      completedTasks: _parseInt(json['completedTasks']),
      turfSummaries: turfs,
    );
  }
}

class TrendPoint {
  final DateTime date;
  final int doorKnocks;
  final int calls;
  final int texts;
  final int totalContacts;

  const TrendPoint({
    required this.date,
    required this.doorKnocks,
    required this.calls,
    required this.texts,
    required this.totalContacts,
  });

  factory TrendPoint.fromJson(Map<String, dynamic> json) {
    return TrendPoint(
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      doorKnocks: _parseInt(json['doorKnocks']),
      calls: _parseInt(json['calls']),
      texts: _parseInt(json['texts']),
      totalContacts: _parseInt(json['totalContacts']),
    );
  }
}

class NavigatorPerformance {
  final String userId;
  final String displayName;
  final int doorsKnocked;
  final int callsMade;
  final int textsSent;
  final int totalContacts;
  final double contactRate;

  const NavigatorPerformance({
    required this.userId,
    required this.displayName,
    required this.doorsKnocked,
    required this.callsMade,
    required this.textsSent,
    required this.totalContacts,
    required this.contactRate,
  });

  factory NavigatorPerformance.fromJson(Map<String, dynamic> json) {
    return NavigatorPerformance(
      userId: json['userId'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'Unknown',
      doorsKnocked: _parseInt(json['doorsKnocked']),
      callsMade: _parseInt(json['callsMade']),
      textsSent: _parseInt(json['textsSent']),
      totalContacts: _parseInt(json['totalContacts']),
      contactRate: _parseDouble(json['contactRate']),
    );
  }
}

class TurfSummary {
  final String turfId;
  final String turfName;
  final int voterCount;
  final int contactedCount;

  const TurfSummary({
    required this.turfId,
    required this.turfName,
    required this.voterCount,
    required this.contactedCount,
  });

  factory TurfSummary.fromJson(Map<String, dynamic> json) {
    return TurfSummary(
      turfId: json['turfId'] as String? ?? '',
      turfName: json['turfName'] as String? ?? '',
      voterCount: _parseInt(json['voterCount']),
      contactedCount: _parseInt(json['contactedCount']),
    );
  }
}

/// Result of an export operation containing file bytes and metadata.
class ExportResult {
  final Uint8List bytes;
  final String filename;
  final String contentType;

  ExportResult({
    required this.bytes,
    required this.filename,
    required this.contentType,
  });
}

/// AnalyticsService provides API client for analytics endpoints via ConnectRPC JSON protocol.
class AnalyticsService {
  final String _baseUrl;
  final String? Function() _getAccessToken;

  AnalyticsService({
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
        Uri.parse('$_baseUrl/navigators.v1.AnalyticsService/$method');
    final response =
        await http.post(url, headers: _headers, body: jsonEncode(body));
    if (response.statusCode != 200) {
      throw Exception(
          '$method failed: ${response.statusCode} ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Format a DateTime as RFC3339 string.
  static String toRfc3339(DateTime dt) => dt.toUtc().toIso8601String();

  /// Default date range: last 30 days.
  static Map<String, String> _defaultDateRange({String? since, String? until}) {
    final now = DateTime.now().toUtc();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    return {
      'since': since ?? toRfc3339(thirtyDaysAgo),
      'until': until ?? toRfc3339(now),
    };
  }

  /// Fetch aggregate dashboard metrics (contact stats, tasks, turfs).
  Future<DashboardMetrics> getDashboardMetrics(
      {String? since, String? until}) async {
    final range = _defaultDateRange(since: since, until: until);
    final json = await _post('GetDashboardMetrics', range);
    return DashboardMetrics.fromJson(json);
  }

  /// Fetch time-series trend data for contact activity charts.
  Future<List<TrendPoint>> getTrendData({
    required String since,
    required String until,
    String interval = 'day',
  }) async {
    final json = await _post('GetTrendData', {
      'since': since,
      'until': until,
      'interval': interval,
    });
    final points = json['points'] as List<dynamic>? ?? [];
    return points
        .map((p) => TrendPoint.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  /// Fetch per-navigator performance report for team/admin dashboards.
  Future<List<NavigatorPerformance>> getPerformanceReport({
    required String since,
    required String until,
  }) async {
    final json = await _post('GetPerformanceReport', {
      'since': since,
      'until': until,
    });
    final navigators = json['navigators'] as List<dynamic>? ?? [];
    return navigators
        .map((n) =>
            NavigatorPerformance.fromJson(n as Map<String, dynamic>))
        .toList();
  }

  /// Export filtered data as CSV or Excel bytes.
  ///
  /// [exportType] is one of: 'contacts', 'voters', 'tasks'.
  /// [format] is one of: 'csv', 'xlsx'.
  /// Returns [ExportResult] with file bytes, filename, and content type.
  Future<ExportResult> exportData({
    required String exportType,
    required String format,
    required String since,
    required String until,
  }) async {
    final result = await _post('ExportData', {
      'exportType': exportType,
      'format': format,
      'since': since,
      'until': until,
    });
    // Proto JSON encodes bytes as base64 string
    final bytes = base64Decode(result['data'] as String);
    final filename = result['filename'] as String;
    final contentType = result['contentType'] as String;
    return ExportResult(
      bytes: Uint8List.fromList(bytes),
      filename: filename,
      contentType: contentType,
    );
  }
}

/// Riverpod provider for AnalyticsService.
final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  final auth = ref.watch(authProvider);
  const envUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  final baseUrl = envUrl.isNotEmpty ? envUrl : 'http://localhost:8080';
  return AnalyticsService(
    baseUrl: baseUrl,
    getAccessToken: () => auth.accessToken,
  );
});
