import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/analytics_service.dart';
import 'widgets/activity_chart.dart';
import 'widgets/metric_card.dart';
import 'widgets/sentiment_pie_chart.dart';

/// Personal dashboard for Navigator role showing their own stats, trends, and turfs.
class NavigatorDashboardScreen extends ConsumerStatefulWidget {
  const NavigatorDashboardScreen({super.key});

  @override
  ConsumerState<NavigatorDashboardScreen> createState() =>
      _NavigatorDashboardScreenState();
}

class _NavigatorDashboardScreenState
    extends ConsumerState<NavigatorDashboardScreen> {
  DashboardMetrics? _metrics;
  List<TrendPoint> _trend = [];
  bool _loading = true;
  String? _error;

  String get _thirtyDaysAgo => AnalyticsService.toRfc3339(
      DateTime.now().toUtc().subtract(const Duration(days: 30)));
  String get _now => AnalyticsService.toRfc3339(DateTime.now().toUtc());

  @override
  void initState() {
    super.initState();
    // Schedule load after first frame to ensure ref is available
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
      ]);
      if (!mounted) return;
      setState(() {
        _metrics = results[0] as DashboardMetrics;
        _trend = results[1] as List<TrendPoint>;
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

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Metric cards row
            _buildMetricCards(metrics),
            const SizedBox(height: 16),

            // Activity trend chart
            _buildSectionCard(
              title: 'Activity Trend (Last 30 Days)',
              child: ActivityChart(data: _trend),
            ),
            const SizedBox(height: 16),

            // Sentiment distribution
            _buildSectionCard(
              title: 'Sentiment Distribution',
              child: SentimentPieChart(
                  distribution: metrics.sentimentDistribution),
            ),
            const SizedBox(height: 16),

            // Task summary
            _buildTaskSummary(metrics),
            const SizedBox(height: 16),

            // Turf list
            _buildTurfList(metrics.turfSummaries),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCards(DashboardMetrics metrics) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
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
      ],
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

  Widget _buildTaskSummary(DashboardMetrics metrics) {
    final progress = metrics.totalTasks > 0
        ? metrics.completedTasks / metrics.totalTasks
        : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('My Tasks',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '${metrics.completedTasks} / ${metrics.totalTasks}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(width: 8),
                const Text('completed'),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTurfList(List<TurfSummary> turfs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('My Turfs',
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
