import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/map_service.dart';

/// Dashboard screen showing all turfs with stats, completion progress, and sorting.
class TurfDashboardScreen extends ConsumerStatefulWidget {
  const TurfDashboardScreen({super.key});

  @override
  ConsumerState<TurfDashboardScreen> createState() =>
      _TurfDashboardScreenState();
}

enum _SortBy { name, completion, voterCount }

class _TurfDashboardScreenState extends ConsumerState<TurfDashboardScreen> {
  final Map<String, TurfStats> _statsMap = {};
  bool _loadingStats = false;
  _SortBy _sortBy = _SortBy.name;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(turfListProvider.notifier).loadTurfs();
      _loadAllStats();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllStats() async {
    final turfState = ref.read(turfListProvider);
    if (turfState.turfs.isEmpty) {
      // Wait for turfs to load, then retry
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      final refreshedState = ref.read(turfListProvider);
      if (refreshedState.turfs.isEmpty) return;
    }

    setState(() => _loadingStats = true);
    final service = ref.read(mapServiceProvider);
    final turfs = ref.read(turfListProvider).turfs;

    for (final turf in turfs) {
      try {
        final stats = await service.getTurfStats(turf.turfId);
        if (mounted) {
          setState(() {
            _statsMap[turf.turfId] = stats;
          });
        }
      } catch (_) {
        // Skip turfs where stats fail
      }
    }

    if (mounted) {
      setState(() => _loadingStats = false);
    }
  }

  List<TurfInfo> _filteredAndSorted(List<TurfInfo> turfs) {
    var filtered = turfs;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = turfs.where((t) => t.name.toLowerCase().contains(q)).toList();
    }

    filtered.sort((a, b) {
      switch (_sortBy) {
        case _SortBy.name:
          return a.name.compareTo(b.name);
        case _SortBy.completion:
          final aComp = _statsMap[a.turfId]?.completionPercentage ?? 0;
          final bComp = _statsMap[b.turfId]?.completionPercentage ?? 0;
          return bComp.compareTo(aComp);
        case _SortBy.voterCount:
          return b.voterCount.compareTo(a.voterCount);
      }
    });

    return filtered;
  }

  String _formatArea(double sqMeters) {
    final acres = sqMeters / 4046.86;
    if (acres < 100) {
      return '${acres.toStringAsFixed(0)} acres';
    }
    final sqMiles = sqMeters / 2589988.11;
    return '${sqMiles.toStringAsFixed(1)} sq mi';
  }

  @override
  Widget build(BuildContext context) {
    final turfState = ref.watch(turfListProvider);
    final turfs = _filteredAndSorted(turfState.turfs);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Turf Dashboard'),
        actions: [
          PopupMenuButton<_SortBy>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort by',
            onSelected: (sort) => setState(() => _sortBy = sort),
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                value: _SortBy.name,
                checked: _sortBy == _SortBy.name,
                child: const Text('Name'),
              ),
              CheckedPopupMenuItem(
                value: _SortBy.completion,
                checked: _sortBy == _SortBy.completion,
                child: const Text('Completion %'),
              ),
              CheckedPopupMenuItem(
                value: _SortBy.voterCount,
                checked: _sortBy == _SortBy.voterCount,
                child: const Text('Voter count'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(turfListProvider.notifier).refresh();
              _loadAllStats();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search turfs...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          // Loading
          if (turfState.isLoading || _loadingStats)
            const LinearProgressIndicator(),
          // Turf list
          Expanded(
            child: turfs.isEmpty
                ? Center(
                    child: turfState.isLoading
                        ? const CircularProgressIndicator()
                        : const Text('No turfs found'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: turfs.length,
                    itemBuilder: (context, index) {
                      final turf = turfs[index];
                      final stats = _statsMap[turf.turfId];
                      return _TurfDashboardCard(
                        turf: turf,
                        stats: stats,
                        formatArea: _formatArea,
                        onTap: () {
                          // Navigate back to map screen focused on this turf
                          Navigator.of(context).pop(turf.turfId);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _TurfDashboardCard extends StatelessWidget {
  final TurfInfo turf;
  final TurfStats? stats;
  final String Function(double) formatArea;
  final VoidCallback onTap;

  const _TurfDashboardCard({
    required this.turf,
    required this.stats,
    required this.formatArea,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final completion = stats?.completionPercentage ?? 0.0;
    final contacted = stats?.contactedVoters ?? 0;
    final total = stats?.totalVoters ?? turf.voterCount;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      turf.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  Text(
                    '${completion.toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: completion / 100,
                  minHeight: 8,
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 8),
              // Stats row
              Row(
                children: [
                  _MiniStat(
                    icon: Icons.people,
                    label: '$total voters',
                  ),
                  const SizedBox(width: 16),
                  _MiniStat(
                    icon: Icons.check_circle_outline,
                    label: '$contacted contacted',
                  ),
                  const SizedBox(width: 16),
                  _MiniStat(
                    icon: Icons.square_foot,
                    label: formatArea(turf.areaSqMeters),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniStat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Theme.of(context).colorScheme.outline),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
