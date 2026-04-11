import 'dart:convert';

import 'package:eden_platform_flutter/eden_platform.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Data classes for analytics responses.

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
      sentimentMap[(b['sentiment'] as num?)?.toInt() ?? 0] =
          (b['count'] as num?)?.toInt() ?? 0;
    }

    final turfList = json['turfSummaries'] as List<dynamic>? ?? [];
    final turfs = turfList
        .map((t) => TurfSummary.fromJson(t as Map<String, dynamic>))
        .toList();

    return DashboardMetrics(
      doorsKnocked: (json['doorsKnocked'] as num?)?.toInt() ?? 0,
      callsMade: (json['callsMade'] as num?)?.toInt() ?? 0,
      textsSent: (json['textsSent'] as num?)?.toInt() ?? 0,
      contactRate: (json['contactRate'] as num?)?.toDouble() ?? 0.0,
      totalVoters: (json['totalVoters'] as num?)?.toInt() ?? 0,
      contactedVoters: (json['contactedVoters'] as num?)?.toInt() ?? 0,
      sentimentDistribution: sentimentMap,
      totalTasks: (json['totalTasks'] as num?)?.toInt() ?? 0,
      completedTasks: (json['completedTasks'] as num?)?.toInt() ?? 0,
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
      doorKnocks: (json['doorKnocks'] as num?)?.toInt() ?? 0,
      calls: (json['calls'] as num?)?.toInt() ?? 0,
      texts: (json['texts'] as num?)?.toInt() ?? 0,
      totalContacts: (json['totalContacts'] as num?)?.toInt() ?? 0,
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
      doorsKnocked: (json['doorsKnocked'] as num?)?.toInt() ?? 0,
      callsMade: (json['callsMade'] as num?)?.toInt() ?? 0,
      textsSent: (json['textsSent'] as num?)?.toInt() ?? 0,
      totalContacts: (json['totalContacts'] as num?)?.toInt() ?? 0,
      contactRate: (json['contactRate'] as num?)?.toDouble() ?? 0.0,
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
      voterCount: (json['voterCount'] as num?)?.toInt() ?? 0,
      contactedCount: (json['contactedCount'] as num?)?.toInt() ?? 0,
    );
  }
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
