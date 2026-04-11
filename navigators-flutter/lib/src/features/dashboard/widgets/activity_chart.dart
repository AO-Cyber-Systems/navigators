import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/analytics_service.dart';

/// Line chart displaying contact activity trends (door knocks, calls, texts) over time.
class ActivityChart extends StatelessWidget {
  final List<TrendPoint> data;

  const ActivityChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('No activity data yet')),
      );
    }

    return SizedBox(
      height: 200,
      child: Padding(
        padding: const EdgeInsets.only(right: 16, top: 8),
        child: LineChart(
          LineChartData(
            gridData: const FlGridData(show: true, drawVerticalLine: false),
            titlesData: FlTitlesData(
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: _bottomInterval,
                  getTitlesWidget: _bottomTitle,
                ),
              ),
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              _line(_doorKnockSpots, Colors.blue, 'Doors'),
              _line(_callSpots, Colors.orange, 'Calls'),
              _line(_textSpots, Colors.green, 'Texts'),
            ],
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    final labels = ['Doors', 'Calls', 'Texts'];
                    final label =
                        spot.barIndex < labels.length ? labels[spot.barIndex] : '';
                    return LineTooltipItem(
                      '$label: ${spot.y.toInt()}',
                      TextStyle(
                        color: spot.bar.color ?? Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    );
                  }).toList();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<FlSpot> get _doorKnockSpots => data
      .map((p) => FlSpot(
          p.date.millisecondsSinceEpoch.toDouble(), p.doorKnocks.toDouble()))
      .toList();

  List<FlSpot> get _callSpots => data
      .map((p) => FlSpot(
          p.date.millisecondsSinceEpoch.toDouble(), p.calls.toDouble()))
      .toList();

  List<FlSpot> get _textSpots => data
      .map((p) => FlSpot(
          p.date.millisecondsSinceEpoch.toDouble(), p.texts.toDouble()))
      .toList();

  double get _bottomInterval {
    if (data.length <= 1) return 1;
    final range = data.last.date.millisecondsSinceEpoch -
        data.first.date.millisecondsSinceEpoch;
    // Show ~5-7 labels along the axis
    return (range / 6).roundToDouble().clamp(1, double.infinity);
  }

  LineChartBarData _line(List<FlSpot> spots, Color color, String label) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 2,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.1),
      ),
    );
  }

  Widget _bottomTitle(double value, TitleMeta meta) {
    final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
    return SideTitleWidget(
      meta: meta,
      child: Text(
        DateFormat('M/d').format(date),
        style: const TextStyle(fontSize: 10),
      ),
    );
  }
}
