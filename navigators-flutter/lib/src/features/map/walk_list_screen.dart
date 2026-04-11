import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../database/database.dart';
import '../../services/map_service.dart';

/// Displays a route-optimized walk list of voters in a turf.
/// Supports both list view and map view with connected route lines.
///
/// Offline-first: reads from local Drift DB when available,
/// falls back to server HTTP call when local data is empty.
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

  @override
  void initState() {
    super.initState();
    _loadWalkList();
  }

  Future<void> _loadWalkList() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Try local Drift DB first (offline-first)
    final localVoters = await _tryLoadFromLocalDb();
    if (localVoters != null && localVoters.isNotEmpty) {
      if (mounted) {
        setState(() {
          _voters = localVoters;
          _isLoading = false;
          _usingLocalData = true;
        });
      }
      return;
    }

    // Fall back to server HTTP call
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
    }
  }

  /// Try to load voters from local Drift DB, ordered by walk_sequence.
  /// Returns null if database is not available or has no data for this turf.
  Future<List<WalkListVoter>?> _tryLoadFromLocalDb() async {
    try {
      final db = ref.read(databaseProvider);
      final voterDao = db.voterDao;

      // watchVotersInTurf returns a stream; use getVotersInTurf for one-shot
      // VoterDao orders by walkSequence already in watchVotersInTurf
      final localVoters = await voterDao.getVotersInTurf(widget.turfId);

      if (localVoters.isEmpty) return null;

      // Sort by walk sequence (getVotersInTurf orders by lastName,
      // we need walkSequence order for the walk list)
      localVoters.sort((a, b) => a.walkSequence.compareTo(b.walkSequence));

      return localVoters.map((v) => WalkListVoter(
            voterId: v.id,
            firstName: v.firstName,
            lastName: v.lastName,
            latitude: v.latitude,
            longitude: v.longitude,
            resStreetAddress: v.resStreetAddress,
            party: v.party,
            sequence: v.walkSequence,
          )).toList();
    } catch (_) {
      // Database not initialized or query failed
      return null;
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

  Color _partyColor(String party) {
    switch (party.toUpperCase()) {
      case 'R':
      case 'REP':
      case 'REPUBLICAN':
        return Colors.red;
      case 'D':
      case 'DEM':
      case 'DEMOCRAT':
      case 'DEMOCRATIC':
        return Colors.blue;
      case 'G':
      case 'GRN':
      case 'GREEN':
        return Colors.green;
      case 'L':
      case 'LIB':
      case 'LIBERTARIAN':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

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
    return _showMap ? _buildMapView() : _buildListView();
  }

  Widget _buildListView() {
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
                '${_voters.length} voters in route order',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: _voters.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final voter = _voters[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    '${voter.sequence}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
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
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.directions, size: 20),
                      onPressed: () => _navigateToVoter(voter),
                      tooltip: 'Navigate',
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMapView() {
    // Fit map to all voter points
    final points = _voters
        .where((v) => v.latitude != 0.0 && v.longitude != 0.0)
        .map((v) => v.location)
        .toList();

    if (points.isEmpty) {
      return const Center(child: Text('No geocoded voters to display'));
    }

    final bounds = LatLngBounds.fromPoints(points);

    return FlutterMap(
      options: MapOptions(
        initialCameraFit: CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(48),
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.mainegop.navigators',
        ),
        // Route line connecting voters in walk order
        PolylineLayer(
          polylines: [
            Polyline(
              points: points,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
              strokeWidth: 3.0,
            ),
          ],
        ),
        // Voter markers with sequence numbers
        MarkerLayer(
          markers: _voters
              .where((v) => v.latitude != 0.0 && v.longitude != 0.0)
              .map((voter) => Marker(
                    point: voter.location,
                    width: 32,
                    height: 32,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _partyColor(voter.party),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${voter.sequence}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}
