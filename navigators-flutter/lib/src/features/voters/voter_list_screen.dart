import 'package:eden_ui_flutter/eden_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/voter_service.dart';
import 'voter_detail_screen.dart';
import 'voter_filter_panel.dart';
import 'voter_search_bar.dart';

/// Main voter list screen with search, filters, and paginated list.
/// On desktop, shows a master-detail layout with voter detail inline.
class VoterListScreen extends ConsumerStatefulWidget {
  const VoterListScreen({super.key});

  @override
  ConsumerState<VoterListScreen> createState() => _VoterListScreenState();
}

class _VoterListScreenState extends ConsumerState<VoterListScreen> {
  final _scrollController = ScrollController();
  bool _isSearchMode = false;
  String? _selectedVoterId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(() {
      ref.read(voterListProvider.notifier).loadVoters();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_isSearchMode) {
        ref.read(voterSearchProvider.notifier).loadMore();
      } else {
        ref.read(voterListProvider.notifier).loadMore();
      }
    }
  }

  void _onSearchChanged() {
    final searchState = ref.read(voterSearchProvider);
    setState(() {
      _isSearchMode = searchState.query.isNotEmpty;
    });
  }

  void _onVoterTap(VoterSummary voter) {
    final isDesktop = EdenResponsive.isDesktop(context);
    if (isDesktop) {
      setState(() => _selectedVoterId = voter.id);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VoterDetailScreen(voterId: voter.id),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = EdenResponsive.isDesktop(context);

    if (isDesktop) {
      return _buildDesktopLayout();
    }
    return _buildMobileLayout();
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left panel: voter list
        SizedBox(
          width: 420,
          child: _buildVoterListPanel(),
        ),
        const VerticalDivider(width: 1),
        // Right panel: voter detail or empty state
        Expanded(
          child: _selectedVoterId != null
              ? VoterDetailScreen(
                  key: ValueKey(_selectedVoterId),
                  voterId: _selectedVoterId!,
                )
              : const Center(
                  child: EdenEmptyState(
                    title: 'Select a voter',
                    description: 'Choose a voter from the list to view their profile.',
                    icon: Icons.person_search,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Semantics(
      identifier: 'voter-list-screen',
      explicitChildNodes: true,
      child: Scaffold(
        appBar: AppBar(title: const Text('Voters')),
        body: _buildVoterListPanel(),
      ),
    );
  }

  Widget _buildVoterListPanel() {
    final searchState = ref.watch(voterSearchProvider);
    final listState = ref.watch(voterListProvider);

    final voters = _isSearchMode ? searchState.results : listState.voters;
    final isLoading = _isSearchMode ? searchState.isLoading : listState.isLoading;
    final error = _isSearchMode ? searchState.error : listState.error;
    final totalCount =
        _isSearchMode ? searchState.totalCount : listState.totalCount;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: VoterSearchBar(onSearchChanged: _onSearchChanged),
        ),
        if (!_isSearchMode) const VoterFilterPanel(),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: EdenAlert(
              title: 'Error loading voters',
              message: error,
              variant: EdenAlertVariant.danger,
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Text(
                '$totalCount voters',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              if (_isSearchMode) {
                await ref.read(voterSearchProvider.notifier).search(searchState.query);
              } else {
                await ref.read(voterListProvider.notifier).refresh();
              }
            },
            child: voters.isEmpty && !isLoading
                ? const Center(
                    child: EdenEmptyState(
                      title: 'No voters found',
                      description: 'Try adjusting your search or filters.',
                      icon: Icons.people_outline,
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: voters.length + (isLoading ? 3 : 0),
                    itemBuilder: (context, index) {
                      if (index >= voters.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: EdenSkeleton(height: 72),
                        );
                      }
                      final voter = voters[index];
                      final isSelected = voter.id == _selectedVoterId;
                      return Semantics(
                        identifier: 'voter-list-row-${voter.id}',
                        button: true,
                        child: _VoterCard(
                          voter: voter,
                          isSelected: isSelected,
                          onTap: () => _onVoterTap(voter),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _VoterCard extends StatelessWidget {
  final VoterSummary voter;
  final VoidCallback onTap;
  final bool isSelected;

  const _VoterCard({
    required this.voter,
    required this.onTap,
    this.isSelected = false,
  });

  Color _partyColor(String party) {
    switch (party.toUpperCase()) {
      case 'D':
        return Colors.blue;
      case 'R':
        return Colors.red;
      case 'G':
        return Colors.green;
      case 'L':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  EdenBadgeVariant _statusVariant(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return EdenBadgeVariant.success;
      case 'inactive':
        return EdenBadgeVariant.neutral;
      default:
        return EdenBadgeVariant.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      selected: isSelected,
      selectedTileColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
      leading: CircleAvatar(
        backgroundColor: _partyColor(voter.party),
        child: Text(
          voter.party.isNotEmpty ? voter.party[0] : '?',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(voter.fullName),
      subtitle: Text(
        [voter.municipality, voter.resCity, voter.resZip]
            .where((s) => s.isNotEmpty)
            .join(', '),
      ),
      trailing: EdenBadge(
        label: voter.status,
        variant: _statusVariant(voter.status),
        size: EdenBadgeSize.sm,
      ),
    );
  }
}
