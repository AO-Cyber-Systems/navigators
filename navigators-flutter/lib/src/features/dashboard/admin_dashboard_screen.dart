import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../services/analytics_service.dart';
import '../../services/map_service.dart';
import '../map/widgets/heat_map_painter.dart';
import 'widgets/activity_chart.dart';
import 'widgets/export_dialog.dart';
import 'widgets/leaderboard_widget.dart';
import 'widgets/metric_card.dart';
import 'widgets/sentiment_pie_chart.dart';

/// Admin org-wide dashboard with metrics, trends, sentiment, heat map,
/// leaderboard, turf coverage, and export FAB.
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  DashboardMetrics? _metrics;
  List<TrendPoint> _trend = [];
  List<NavigatorPerformance> _performance = [];
  List<DensityGridCell> _densityCells = [];
  HeatMapMode _heatMapMode = HeatMapMode.density;
  bool _loading = true;
  String? _error;

  // Heat map loading state (separate from main loading)
  bool _mapLoading = false;
  String? _mapError;

  final MapController _mapController = MapController();

  // Maine center
  static const _maineCenter = LatLng(45.2538, -69.4455);
  static const _maineZoom = 7.0;

  String get _thirtyDaysAgo => AnalyticsService.toRfc3339(
      DateTime.now().toUtc().subtract(const Duration(days: 30)));
  String get _now => AnalyticsService.toRfc3339(DateTime.now().toUtc());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final analytics = ref.read(analyticsServiceProvider);
      final mapSvc = ref.read(mapServiceProvider);
      final results = await Future.wait([
        analytics.getDashboardMetrics(),
        analytics.getTrendData(since: _thirtyDaysAgo, until: _now),
        analytics.getPerformanceReport(since: _thirtyDaysAgo, until: _now),
        _fetchDensityCells(mapSvc),
      ]);
      if (!mounted) return;
      setState(() {
        _metrics = results[0] as DashboardMetrics;
        _trend = results[1] as List<TrendPoint>;
        _performance = results[2] as List<NavigatorPerformance>;
        // density cells set in _fetchDensityCells
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

  Future<List<DensityGridCell>> _fetchDensityCells(MapService mapSvc) async {
    try {
      final cells = await mapSvc.getVoterDensityGrid(
        minLat: 43.0,
        minLng: -71.1,
        maxLat: 47.5,
        maxLng: -66.9,
        gridSize: 0.05,
      );
      if (mounted) {
        setState(() {
          _densityCells = cells;
          _mapError = null;
        });
      }
      return cells;
    } catch (e) {
      if (mounted) {
        setState(() => _mapError = e.toString());
      }
      return [];
    }
  }

  Future<void> _retryMapLoad() async {
    setState(() {
      _mapLoading = true;
      _mapError = null;
    });
    try {
      final mapSvc = ref.read(mapServiceProvider);
      await _fetchDensityCells(mapSvc);
    } finally {
      if (mounted) {
        setState(() => _mapLoading = false);
      }
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

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section 1: Key Metrics
              _buildMetricCards(metrics),
              const SizedBox(height: 16),

              // Section 2: Activity Trends
              _buildSectionCard(
                title: 'Activity Trends (Last 30 Days)',
                child: ActivityChart(data: _trend),
              ),
              const SizedBox(height: 16),

              // Section 3: Sentiment Distribution
              _buildSectionCard(
                title: 'Sentiment Distribution',
                child: Column(
                  children: [
                    SentimentPieChart(
                        distribution: metrics.sentimentDistribution),
                    const SizedBox(height: 8),
                    _buildSentimentCounts(metrics.sentimentDistribution),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Section 4: Geographic Analytics
              _buildHeatMapSection(),
              const SizedBox(height: 16),

              // Section 5: Top Navigators
              _buildSectionCard(
                title: 'Top Navigators',
                child: LeaderboardWidget(navigators: _performance),
              ),
              const SizedBox(height: 16),

              // Section 6: Turf Coverage
              _buildTurfCoverage(metrics.turfSummaries),
              const SizedBox(height: 80), // FAB clearance
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => const ExportDialog(),
          );
        },
        tooltip: 'Export Data',
        child: const Icon(Icons.download),
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

  Widget _buildSentimentCounts(Map<int, int> distribution) {
    const labels = {
      1: 'Very Neg',
      2: 'Negative',
      3: 'Neutral',
      4: 'Positive',
      5: 'Very Pos',
    };

    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: [
        for (var i = 1; i <= 5; i++)
          Text(
            '${labels[i]}: ${distribution[i] ?? 0}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }

  Widget _buildHeatMapSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Contact Density',
                    style: Theme.of(context).textTheme.titleMedium),
                ToggleButtons(
                  isSelected: [
                    _heatMapMode == HeatMapMode.density,
                    _heatMapMode == HeatMapMode.support,
                  ],
                  onPressed: (index) {
                    setState(() {
                      _heatMapMode = index == 0
                          ? HeatMapMode.density
                          : HeatMapMode.support;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  constraints:
                      const BoxConstraints(minWidth: 70, minHeight: 32),
                  textStyle: Theme.of(context).textTheme.bodySmall,
                  children: const [
                    Text('Density'),
                    Text('Support'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_mapError != null && _densityCells.isEmpty)
              SizedBox(
                height: 300,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Unable to load map data'),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _mapLoading ? null : _retryMapLoad,
                        icon: _mapLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else
              SizedBox(
                height: 300,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: FlutterMap(
                    mapController: _mapController,
                    options: const MapOptions(
                      initialCenter: _maineCenter,
                      initialZoom: _maineZoom,
                      interactionOptions: InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.mainegop.navigators',
                      ),
                      Builder(
                        builder: (context) {
                          final camera = MapCamera.of(context);
                          return CustomPaint(
                            size: Size(camera.size.width, camera.size.height),
                            painter: HeatMapPainter(
                              cells: _densityCells,
                              camera: camera,
                              mode: _heatMapMode,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
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
