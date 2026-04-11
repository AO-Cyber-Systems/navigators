import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/volunteer_service.dart';

/// Leaderboard screen showing ranked opted-in users by activity.
///
/// Features:
/// - Time window toggle: This Week / This Month / All Time
/// - Ranked list with medal icons for top 3
/// - Activity breakdown: Doors, Texts, Calls, total actions
/// - Opt-in toggle to show/hide user on leaderboard
/// - Online-only (no local Drift storage)
class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  String _timeWindow = 'this_week';
  List<dynamic> _entries = [];
  bool _isLoading = true;
  bool _optedIn = false;
  bool _togglingOptIn = false;
  String? _error;

  static const _windows = {
    'this_week': 'This Week',
    'this_month': 'This Month',
    'all_time': 'All Time',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = ref.read(volunteerServiceProvider);

      // Load leaderboard and opt-in status in parallel
      final results = await Future.wait([
        service.getLeaderboard(_timeWindow),
        service.getOnboardingStatus(),
      ]);

      final leaderboard = results[0];
      final status = results[1];

      if (mounted) {
        setState(() {
          _entries = leaderboard['entries'] as List<dynamic>? ?? [];
          _optedIn = status['leaderboardOptIn'] as bool? ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Unable to load leaderboard. Check your connection.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleOptIn(bool value) async {
    setState(() => _togglingOptIn = true);
    try {
      final service = ref.read(volunteerServiceProvider);
      await service.updateLeaderboardOptIn(value);
      setState(() => _optedIn = value);
      _loadData(); // Refresh leaderboard
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update opt-in: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _togglingOptIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
      ),
      body: Column(
        children: [
          // Opt-in banner
          if (!_optedIn && !_isLoading)
            MaterialBanner(
              content: const Text('Opt in to appear on the leaderboard'),
              leading: const Icon(Icons.info_outline),
              actions: [
                Switch(
                  value: _optedIn,
                  onChanged: _togglingOptIn ? null : _toggleOptIn,
                ),
              ],
            ),

          // Time window toggle
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<String>(
              segments: _windows.entries
                  .map((e) => ButtonSegment(
                        value: e.key,
                        label: Text(e.value),
                      ))
                  .toList(),
              selected: {_timeWindow},
              onSelectionChanged: (selection) {
                setState(() => _timeWindow = selection.first);
                _loadData();
              },
            ),
          ),

          // Opt-in toggle (when already opted in)
          if (_optedIn && !_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    'Show me on leaderboard',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const Spacer(),
                  Switch(
                    value: _optedIn,
                    onChanged: _togglingOptIn ? null : _toggleOptIn,
                  ),
                ],
              ),
            ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.cloud_off,
                              size: 64,
                              color: theme.colorScheme.outline,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _error!,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FilledButton.tonal(
                              onPressed: _loadData,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _entries.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.leaderboard_outlined,
                                  size: 64,
                                  color: theme.colorScheme.outline,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No leaderboard data yet',
                                  style: theme.textTheme.titleMedium
                                      ?.copyWith(
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _entries.length,
                            itemBuilder: (context, index) {
                              final entry =
                                  _entries[index] as Map<String, dynamic>;
                              return _LeaderboardTile(
                                rank: index + 1,
                                entry: entry,
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> entry;

  const _LeaderboardTile({required this.rank, required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = entry['displayName'] as String? ?? 'Unknown';
    final doors = (entry['doorsKnocked'] as num?)?.toInt() ?? 0;
    final texts = (entry['textsSent'] as num?)?.toInt() ?? 0;
    final calls = (entry['callsMade'] as num?)?.toInt() ?? 0;
    final total = (entry['totalActions'] as num?)?.toInt() ?? 0;

    return ListTile(
      leading: SizedBox(
        width: 40,
        child: Center(
          child: rank <= 3
              ? Icon(
                  Icons.emoji_events,
                  color: switch (rank) {
                    1 => const Color(0xFFFFD700), // Gold
                    2 => const Color(0xFFC0C0C0), // Silver
                    3 => const Color(0xFFCD7F32), // Bronze
                    _ => theme.colorScheme.outline,
                  },
                  size: 28,
                )
              : Text(
                  '$rank',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
        ),
      ),
      title: Text(
        name,
        style: theme.textTheme.titleSmall,
      ),
      subtitle: Text(
        'Doors: $doors | Texts: $texts | Calls: $calls',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '$total',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
