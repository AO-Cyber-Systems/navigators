import 'package:eden_ui_flutter/eden_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/voter_service.dart';
import 'voter_detail_screen.dart';

/// Admin-only paginated suppression list with search, remove, and row tap to
/// open voter detail. Access is controlled by the nav entry visibility (app.dart)
/// and server-side RBAC; this screen does not re-check the role.
class SuppressionListScreen extends ConsumerStatefulWidget {
  const SuppressionListScreen({super.key});

  @override
  ConsumerState<SuppressionListScreen> createState() =>
      _SuppressionListScreenState();
}

class _SuppressionListScreenState extends ConsumerState<SuppressionListScreen> {
  static const int _pageSize = 50;

  List<SuppressedVoter> _voters = [];
  int _page = 0;
  int _totalCount = 0;
  bool _loading = false;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(voterServiceProvider)
          .listSuppressedVoters(pageSize: _pageSize, page: _page);
      if (!mounted) return;
      setState(() {
        _voters = result.voters;
        _totalCount = result.totalCount;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _remove(SuppressedVoter v) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from suppression list?'),
        content: Text(
            '${v.fullName} will be removed from the suppression list and eligible for outreach again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ref
          .read(voterServiceProvider)
          .removeFromSuppressionList(v.voterId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removed from suppression list')),
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove: $e')),
      );
    }
  }

  List<SuppressedVoter> get _filteredVoters {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return _voters;
    return _voters.where((v) {
      return v.fullName.toLowerCase().contains(q) ||
          v.resCity.toLowerCase().contains(q);
    }).toList();
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '-';
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  int get _totalPages {
    if (_totalCount <= 0) return 1;
    return ((_totalCount + _pageSize - 1) ~/ _pageSize).clamp(1, 1 << 30);
  }

  bool get _hasPrev => _page > 0;
  bool get _hasNext => (_page + 1) * _pageSize < _totalCount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suppression List'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loading ? null : _refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by name or city...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          Expanded(child: _buildBody()),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _voters.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            EdenAlert(
              title: 'Failed to load suppression list',
              message: _error!,
              variant: EdenAlertVariant.danger,
            ),
            const SizedBox(height: 16),
            EdenButton(
              label: 'Retry',
              icon: Icons.refresh,
              onPressed: _refresh,
            ),
          ],
        ),
      );
    }
    final filtered = _filteredVoters;
    if (filtered.isEmpty) {
      return Center(
        child: EdenEmptyState(
          title: _searchQuery.isEmpty
              ? 'No suppressed voters'
              : 'No matches',
          description: _searchQuery.isEmpty
              ? 'No voters are currently on the suppression list.'
              : 'No suppressed voters match "$_searchQuery".',
          icon: Icons.block_outlined,
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        itemCount: filtered.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final v = filtered[i];
          final addedByShort =
              v.addedBy.isEmpty ? '-' : v.addedBy.substring(0, v.addedBy.length < 8 ? v.addedBy.length : 8);
          return ListTile(
            title: Text(v.fullName.isEmpty ? '(unnamed)' : v.fullName),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (v.residenceAddress.isNotEmpty) Text(v.residenceAddress),
                Text(
                    'Reason: ${v.reason.isEmpty ? '-' : v.reason}'),
                Tooltip(
                  message: v.addedBy.isEmpty ? '' : v.addedBy,
                  child: Text(
                      'Added: ${_formatDate(v.addedAt)} by $addedByShort'),
                ),
              ],
            ),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'remove') _remove(v);
              },
              itemBuilder: (_) => const [
                PopupMenuItem<String>(
                  value: 'remove',
                  child: ListTile(
                    leading: Icon(Icons.person_remove_outlined),
                    title: Text('Remove from suppression list'),
                    dense: true,
                  ),
                ),
              ],
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => VoterDetailScreen(voterId: v.voterId),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFooter() {
    if (_totalCount == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Page ${_page + 1} of $_totalPages ($_totalCount total)'),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _hasPrev && !_loading
                    ? () {
                        setState(() => _page--);
                        _refresh();
                      }
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _hasNext && !_loading
                    ? () {
                        setState(() => _page++);
                        _refresh();
                      }
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
