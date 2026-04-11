import 'package:flutter/material.dart';

import '../../../services/analytics_service.dart';

/// Displays a ranked list of top navigators by total contacts.
class LeaderboardWidget extends StatelessWidget {
  final List<NavigatorPerformance> navigators;

  const LeaderboardWidget({super.key, required this.navigators});

  static const _maxDisplay = 10;

  static const _rankColors = <int, Color>{
    1: Color(0xFFFFD700), // Gold
    2: Color(0xFFC0C0C0), // Silver
    3: Color(0xFFCD7F32), // Bronze
  };

  @override
  Widget build(BuildContext context) {
    if (navigators.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: Text('No navigator activity yet')),
      );
    }

    // Sort by totalContacts descending and take top 10
    final sorted = List<NavigatorPerformance>.from(navigators)
      ..sort((a, b) => b.totalContacts.compareTo(a.totalContacts));
    final top = sorted.take(_maxDisplay).toList();

    return Column(
      children: [
        for (var i = 0; i < top.length; i++) _buildRow(context, i + 1, top[i]),
      ],
    );
  }

  Widget _buildRow(
      BuildContext context, int rank, NavigatorPerformance nav) {
    final theme = Theme.of(context);
    final color = _rankColors[rank];

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color ?? theme.colorScheme.surfaceContainerHighest,
        foregroundColor: color != null ? Colors.white : null,
        child: Text(
          '$rank',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(nav.displayName),
      subtitle: Text(
        '${nav.totalContacts} contacts | ${nav.doorsKnocked} doors | ${nav.callsMade} calls',
      ),
      trailing: Text(
        '${(nav.contactRate * 100).toStringAsFixed(0)}%',
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
