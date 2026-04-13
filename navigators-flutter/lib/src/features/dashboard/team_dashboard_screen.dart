import 'package:eden_ui_flutter/eden_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/analytics_service.dart';
import 'widgets/activity_chart.dart';
import 'widgets/metric_card.dart';
import 'widgets/sentiment_pie_chart.dart';

/// Team dashboard for Super Navigator role showing team-wide metrics and per-navigator performance.
class TeamDashboardScreen extends ConsumerStatefulWidget {
  const TeamDashboardScreen({super.key});

  @override
  ConsumerState<TeamDashboardScreen> createState() =>
      _TeamDashboardScreenState();
}

class _TeamDashboardScreenState extends ConsumerState<TeamDashboardScreen> {
  DashboardMetrics? _metrics;
  List<TrendPoint> _trend = [];
  List<NavigatorPerformance> _performance = [];
  bool _loading = true;
  String? _error;

  String get _thirtyDaysAgo => AnalyticsService.toRfc3339(
      DateTime.now().toUtc().subtract(const Duration(days: 30)));
  String get _now => AnalyticsService.toRfc3339(DateTime.now().toUtc());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = ref.read(analyticsServiceProvider);
      final results = await Future.wait([
        svc.getDashboardMetrics(),
        svc.getTrendData(since: _thirtyDaysAgo, until: _now),
        svc.getPerformanceReport(since: _thirtyDaysAgo, until: _now),
      ]);
      if (!mounted) return;
      setState(() {
        _metrics = results[0] as DashboardMetrics;
        _trend = results[1] as List<TrendPoint>;
        _performance = results[2] as List<NavigatorPerformance>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Failed to load dashboard',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(_error!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final metrics = _metrics!;
    final isWide = EdenResponsive.isDesktop(context);

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMetricCards(metrics, isWide),
                const SizedBox(height: 16),

                if (isWide) ...[
                  // Desktop: chart + sentiment side by side
                  IntrinsicHeight(child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 1,
                        child: _buildSectionCard(
                          title: 'Team Activity Trend (Last 30 Days)',
                          child: ActivityChart(data: _trend),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 1,
                        child: _buildSectionCard(
                          title: 'Sentiment Distribution',
                          child: SentimentPieChart(
                              distribution: metrics.sentimentDistribution),
                        ),
                      ),
                    ],
                  )),
                  const SizedBox(height: 16),
                  // Desktop: performance + turf side by side
                  IntrinsicHeight(child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 1,
                        child: _buildPerformanceTable(),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 1,
                        child: _buildTurfCoverage(metrics.turfSummaries),
                      ),
                    ],
                  )),
                ] else ...[
                  _buildSectionCard(
                    title: 'Team Activity Trend (Last 30 Days)',
                    child: ActivityChart(data: _trend),
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    title: 'Sentiment Distribution',
                    child: SentimentPieChart(
                        distribution: metrics.sentimentDistribution),
                  ),
                  const SizedBox(height: 16),
                  _buildPerformanceTable(),
                  const SizedBox(height: 16),
                  _buildTurfCoverage(metrics.turfSummaries),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCards(DashboardMetrics metrics, bool isWide) {
    final cards = [
      MetricCard(
        label: 'Doors Knocked',
        value: '${metrics.doorsKnocked}',
        icon: Icons.door_front_door,
        color: Colors.blue,
      ),
      MetricCard(
        label: 'Calls Made',
        value: '${metrics.callsMade}',
        icon: Icons.phone,
        color: Colors.orange,
      ),
      MetricCard(
        label: 'Texts Sent',
        value: '${metrics.textsSent}',
        icon: Icons.sms,
        color: Colors.green,
      ),
      MetricCard(
        label: 'Contact Rate',
        value: '${(metrics.contactRate * 100).toStringAsFixed(1)}%',
        icon: Icons.trending_up,
        color: Colors.purple,
      ),
    ];

    if (isWide) {
      return Row(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: cards[i]),
          ],
        ],
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: cards,
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceTable() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Team Performance',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (_performance.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text('No performance data yet')),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 16,
                  columns: const [
                    DataColumn(label: Text('Navigator')),
                    DataColumn(label: Text('Doors'), numeric: true),
                    DataColumn(label: Text('Calls'), numeric: true),
                    DataColumn(label: Text('Texts'), numeric: true),
                    DataColumn(label: Text('Total'), numeric: true),
                    DataColumn(label: Text('Rate'), numeric: true),
                  ],
                  rows: _performance
                      .map((nav) => DataRow(cells: [
                            DataCell(Text(nav.displayName)),
                            DataCell(Text('${nav.doorsKnocked}')),
                            DataCell(Text('${nav.callsMade}')),
                            DataCell(Text('${nav.textsSent}')),
                            DataCell(Text('${nav.totalContacts}')),
                            DataCell(Text(
                                '${(nav.contactRate * 100).toStringAsFixed(1)}%')),
                          ]))
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTurfCoverage(List<TurfSummary> turfs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Turf Coverage',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (turfs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text('No turfs assigned')),
              )
            else
              ...turfs.map((turf) => _buildTurfItem(turf)),
          ],
        ),
      ),
    );
  }

  Widget _buildTurfItem(TurfSummary turf) {
    final progress =
        turf.voterCount > 0 ? turf.contactedCount / turf.voterCount : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(turf.turfName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        )),
              ),
              Text(
                '${turf.contactedCount}/${turf.voterCount}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }
}
