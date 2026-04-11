import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Pie chart displaying sentiment distribution (1-5 scale).
class SentimentPieChart extends StatelessWidget {
  /// Sentiment value (1-5) mapped to count.
  final Map<int, int> distribution;

  const SentimentPieChart({super.key, required this.distribution});

  static const Map<int, Color> _sentimentColors = {
    1: Colors.red,
    2: Colors.orange,
    3: Colors.amber,
    4: Colors.lightGreen,
    5: Colors.green,
  };

  static const Map<int, String> _sentimentLabels = {
    1: 'Very Neg',
    2: 'Negative',
    3: 'Neutral',
    4: 'Positive',
    5: 'Very Pos',
  };

  @override
  Widget build(BuildContext context) {
    final total =
        distribution.values.fold<int>(0, (sum, count) => sum + count);

    if (total == 0) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('No sentiment data yet')),
      );
    }

    final sections = <PieChartSectionData>[];
    for (var i = 1; i <= 5; i++) {
      final count = distribution[i] ?? 0;
      if (count == 0) continue;
      final pct = (count / total * 100).round();
      sections.add(
        PieChartSectionData(
          value: count.toDouble(),
          title: '$pct%',
          color: _sentimentColors[i] ?? Colors.grey,
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    return SizedBox(
      height: 200,
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 30,
                sectionsSpace: 2,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 1; i <= 5; i++)
                if ((distribution[i] ?? 0) > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _sentimentColors[i],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _sentimentLabels[i] ?? '',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}
