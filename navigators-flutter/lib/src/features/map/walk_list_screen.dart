import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../database/database.dart';
import '../../services/door_knock_service.dart';
import '../../services/map_service.dart';
import '../door_knocking/door_knock_screen.dart';
import 'widgets/walk_list_map_view.dart';

/// Route-optimized walk list with door status tracking and auto-advance.
/// Offline-first: reads local Drift DB, falls back to server.
class WalkListScreen extends ConsumerStatefulWidget {
  final String turfId;
  final String turfName;

  const WalkListScreen({
    super.key,
    required this.turfId,
    required this.turfName,
  });

  @override
  ConsumerState<WalkListScreen> createState() => _WalkListScreenState();
}

class _WalkListScreenState extends ConsumerState<WalkListScreen> {
  List<WalkListVoter> _voters = [];
  bool _isLoading = true;
  String? _error;
  bool _showMap = false;
  bool _usingLocalData = false;

  /// Door status for each voter (voterId -> doorStatus).
  Map<String, String> _doorStatuses = {};

  /// Index of the next unvisited voter.
  int _currentIndex = 0;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadWalkList();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadWalkList() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final localVoters = await _tryLoadFromLocalDb();
    if (localVoters != null && localVoters.isNotEmpty) {
      if (mounted) {
        setState(() {
          _voters = localVoters;
          _isLoading = false;
          _usingLocalData = true;
        });
      }
    } else {
      try {
        final service = ref.read(mapServiceProvider);
        final voters = await service.generateWalkList(widget.turfId);
        if (mounted) {
          setState(() {
            _voters = voters;
            _isLoading = false;
            _usingLocalData = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = e.toString();
          });
        }
        return;
      }
    }

    await _loadDoorStatuses();
  }

  Future<void> _loadDoorStatuses() async {
    try {
      final service = ref.read(doorKnockServiceProvider);
      final statuses = await service.getDoorStatusesForTurf(widget.turfId);
      if (mounted) {
        setState(() {
          _doorStatuses = statuses;
          _currentIndex = _findNextUnvisitedIndex(0);
        });
      }
    } catch (_) {
      // Silently fail -- statuses are non-critical
    }
  }

  Future<List<WalkListVoter>?> _tryLoadFromLocalDb() async {
    try {
      final db = ref.read(databaseProvider);
      final localVoters = await db.voterDao.getVotersInTurf(widget.turfId);
      if (localVoters.isEmpty) return null;

      localVoters.sort((a, b) => a.walkSequence.compareTo(b.walkSequence));

      return localVoters
          .map((v) => WalkListVoter(
                voterId: v.id,
                firstName: v.firstName,
                lastName: v.lastName,
                latitude: v.latitude,
                longitude: v.longitude,
                resStreetAddress: v.resStreetAddress,
                party: v.party,
                sequence: v.walkSequence,
              ))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _openDoorKnock(WalkListVoter voter) async {
    final result = await Navigator.push<DoorKnockResult>(
      context,
      MaterialPageRoute(
        builder: (context) => DoorKnockScreen(
          voterId: voter.voterId,
          voterName: voter.fullName,
          turfId: widget.turfId,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _doorStatuses[result.voterId] = result.doorStatus;
        _currentIndex = _findNextUnvisitedIndex(_currentIndex);
      });
      _scrollToCurrentVoter();
    }
  }

  int _findNextUnvisitedIndex(int start) {
    for (var i = start; i < _voters.length; i++) {
      if (!_doorStatuses.containsKey(_voters[i].voterId)) return i;
    }
    for (var i = 0; i < start; i++) {
      if (!_doorStatuses.containsKey(_voters[i].voterId)) return i;
    }
    return _voters.length;
  }

  void _scrollToCurrentVoter() {
    if (_currentIndex < _voters.length && _scrollController.hasClients) {
      final offset = (_currentIndex * 73.0).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _navigateToVoter(WalkListVoter voter) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${voter.latitude},${voter.longitude}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  bool get _allVisited =>
      _voters.isNotEmpty && _currentIndex >= _voters.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Walk List: ${widget.turfName}'),
        actions: [
          if (_usingLocalData)
            const Tooltip(
              message: 'Using offline data',
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.offline_pin, size: 20, color: Colors.orange),
              ),
            ),
          IconButton(
            icon: Icon(_showMap ? Icons.list : Icons.map),
            onPressed: () => setState(() => _showMap = !_showMap),
            tooltip: _showMap ? 'Show list' : 'Show map',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadWalkList,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _voters.isNotEmpty && !_allVisited && !_showMap
          ? FloatingActionButton.extended(
              onPressed: () => _openDoorKnock(_voters[_currentIndex]),
              icon: const Icon(Icons.door_front_door),
              label: const Text('Knock Next'),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text('Failed to load walk list',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(_error!, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            OutlinedButton(
                onPressed: _loadWalkList, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_voters.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text('No voters in this turf'),
          ],
        ),
      );
    }
    return _showMap
        ? WalkListMapView(voters: _voters, doorStatuses: _doorStatuses)
        : _buildListView();
  }

  Widget _buildListView() {
    final visitedCount = _doorStatuses.length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.route,
                  size: 16, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 4),
              Text(
                '$visitedCount/${_voters.length} visited',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            controller: _scrollController,
            itemCount: _voters.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final voter = _voters[index];
              final status = _doorStatuses[voter.voterId];
              final isCurrent = index == _currentIndex && !_allVisited;

              return Material(
                color: isCurrent
                    ? Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: 0.3)
                    : null,
                child: ListTile(
                  onTap: () => _openDoorKnock(voter),
                  onLongPress: () => _navigateToVoter(voter),
                  leading: _DoorStatusIndicator(
                    sequence: voter.sequence,
                    status: status,
                  ),
                  title: Text(voter.fullName),
                  subtitle: Text(voter.resStreetAddress),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Chip(
                        label: Text(
                          voter.party,
                          style: TextStyle(
                            color: _partyColor(voter.party),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.directions, size: 20),
                        onPressed: () => _navigateToVoter(voter),
                        tooltip: 'Navigate',
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Color _partyColor(String party) => switch (party.toUpperCase()) {
        'R' || 'REP' || 'REPUBLICAN' => Colors.red,
        'D' || 'DEM' || 'DEMOCRAT' || 'DEMOCRATIC' => Colors.blue,
        'G' || 'GRN' || 'GREEN' => Colors.green,
        'L' || 'LIB' || 'LIBERTARIAN' => Colors.orange,
        _ => Colors.grey,
      };
}

/// Door status indicator shown as CircleAvatar in the walk list.
class _DoorStatusIndicator extends StatelessWidget {
  final int sequence;
  final String? status;

  const _DoorStatusIndicator({
    required this.sequence,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    if (status == null) {
      return CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Text(
          '$sequence',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      );
    }

    final (icon, color) = switch (status) {
      'answered' => (Icons.check, Colors.green),
      'refused' => (Icons.close, Colors.red),
      'not_home' => (Icons.question_mark, Colors.grey),
      'moved' => (Icons.arrow_forward, Colors.orange),
      _ => (Icons.circle, Colors.grey),
    };

    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.15),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
