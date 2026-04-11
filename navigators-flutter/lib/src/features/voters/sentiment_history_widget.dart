import 'package:flutter/material.dart';

import '../../services/timeline_service.dart';

/// Compact sentiment trend visualization showing colored dots for recent
/// door knock sentiment values (1-5 scale).
///
/// Displays up to [maxDots] most recent data points as small circles.
/// Color mapping: 1=red, 2=orange, 3=yellow, 4=lightGreen, 5=green.
class SentimentHistoryWidget extends StatelessWidget {
  final List<SentimentPoint> points;
  final int maxDots;

  const SentimentHistoryWidget({
    super.key,
    required this.points,
    this.maxDots = 10,
  });

  static Color _colorForSentiment(int value) {
    switch (value) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.yellow.shade700;
      case 4:
        return Colors.lightGreen;
      case 5:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Text(
        'No sentiment recorded',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
            ),
      );
    }

    // Show the most recent N points (points are sorted oldest-first).
    final displayPoints = points.length > maxDots
        ? points.sublist(points.length - maxDots)
        : points;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Sentiment: ',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        ...displayPoints.map((p) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Tooltip(
                message: '${p.value}/5',
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: _colorForSentiment(p.value),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${p.value}',
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            )),
      ],
    );
  }
}
