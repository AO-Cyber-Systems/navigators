import 'package:eden_platform_flutter/eden_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../services/map_service.dart';
import '../../services/tile_cache_service.dart';
import 'heat_map_overlay.dart';
import 'offline_download_screen.dart';
import 'turf_dashboard_screen.dart';
import 'turf_draw_screen.dart';
import 'walk_list_screen.dart';
import 'widgets/heat_map_painter.dart';
import 'widgets/turf_polygon_layer.dart';
import 'widgets/voter_cluster_layer.dart';

/// Main map screen showing turf polygons, voter pins, and turf management controls.
class TurfMapScreen extends ConsumerStatefulWidget {
  const TurfMapScreen({super.key});

  @override
  ConsumerState<TurfMapScreen> createState() => _TurfMapScreenState();
}

class _TurfMapScreenState extends ConsumerState<TurfMapScreen> {
  final MapController _mapController = MapController();

  // Augusta, Maine
  static const _initialCenter = LatLng(44.3106, -69.7795);
  static const _initialZoom = 8.0;

  String? _selectedTurfId;
  List<VoterPin> _voters = [];
  bool _loadingVoters = false;

  // Heat map state: null = off, otherwise the current mode
  HeatMapMode? _heatMapMode;

  // Turf stats for selected turf
  TurfStats? _selectedTurfStats;

  // Whether the selected turf has cached tiles
  bool _hasCachedTiles = false;

  @override
  void initState() {
    super.initState();
    // Load turfs on first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(turfListProvider.notifier).loadTurfs();
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _selectTurf(String turfId) async {
    if (_selectedTurfId == turfId) {
      // Deselect
      setState(() {
        _selectedTurfId = null;
        _voters = [];
        _selectedTurfStats = null;
        _hasCachedTiles = false;
      });
      return;
    }

    setState(() {
      _selectedTurfId = turfId;
      _loadingVoters = true;
      _selectedTurfStats = null;
      _hasCachedTiles = false;
    });

    try {
      final service = ref.read(mapServiceProvider);
      final cacheService = ref.read(tileCacheServiceProvider);

      // Load voters, stats, and cache check in parallel
      final results = await Future.wait([
        service.getVotersInTurf(turfId),
        service.getTurfStats(turfId).catchError((_) => const TurfStats(
              turfId: '',
              totalVoters: 0,
              contactedVoters: 0,
              completionPercentage: 0,
            )),
        cacheService.hasCache(turfId),
      ]);

      if (mounted) {
        final voterResult =
            results[0] as ({List<VoterPin> voters, int totalCount});
        setState(() {
          _voters = voterResult.voters;
          _loadingVoters = false;
          _selectedTurfStats = results[1] as TurfStats;
          _hasCachedTiles = results[2] as bool;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingVoters = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load voters: $e')),
        );
      }
    }
  }

  void _onVoterTap(VoterPin voter) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _VoterSummarySheet(voter: voter),
    );
  }

  void _toggleHeatMap() {
    setState(() {
      if (_heatMapMode == null) {
        _heatMapMode = HeatMapMode.density;
      } else if (_heatMapMode == HeatMapMode.density) {
        _heatMapMode = HeatMapMode.support;
      } else {
        _heatMapMode = null;
      }
    });
  }

  Future<void> _navigateToDashboard() async {
    final selectedId = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const TurfDashboardScreen()),
    );
    if (selectedId != null && mounted) {
      _selectTurf(selectedId);
    }
  }

  void _navigateToWalkList(TurfInfo turf) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WalkListScreen(
          turfId: turf.turfId,
          turfName: turf.name,
        ),
      ),
    );
  }

  void _navigateToOfflineDownload(TurfInfo turf) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OfflineDownloadScreen(
          turfId: turf.turfId,
          turfName: turf.name,
        ),
      ),
    );
  }

  Future<void> _navigateToDrawScreen() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const TurfDrawScreen()),
    );
    if (created == true) {
      ref.read(turfListProvider.notifier).refresh();
    }
  }

  Future<void> _showAssignDialog(TurfInfo turf) async {
    final userIdController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Assign Navigator to ${turf.name}'),
        content: Semantics(
          identifier: 'turf-assign-user-id',
          textField: true,
          child: TextField(
            controller: userIdController,
            decoration: const InputDecoration(
              labelText: 'User ID',
              hintText: 'Enter navigator user ID',
            ),
          ),
        ),
        actions: [
          Semantics(
            identifier: 'turf-assign-cancel',
            button: true,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ),
          Semantics(
            identifier: 'turf-assign-confirm',
            button: true,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, userIdController.text.trim()),
              child: const Text('Assign'),
            ),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      try {
        await ref.read(mapServiceProvider).assignUserToTurf(turf.turfId, result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Navigator assigned to ${turf.name}')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Assignment failed: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final turfState = ref.watch(turfListProvider);
    final auth = ref.watch(authProvider);
    final isAdmin = auth.role?.toLowerCase() == 'admin';

    return Semantics(
      identifier: 'turf-map-screen',
      explicitChildNodes: true,
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Turf Map'),
        actions: [
          Semantics(
            identifier: 'turf-map-heatmap-toggle-btn',
            button: true,
            child: IconButton(
              icon: Icon(
                _heatMapMode == null
                    ? Icons.thermostat_outlined
                    : _heatMapMode == HeatMapMode.density
                        ? Icons.thermostat
                        : Icons.favorite,
              ),
              onPressed: _toggleHeatMap,
              tooltip: _heatMapMode == null
                  ? 'Enable heat map'
                  : _heatMapMode == HeatMapMode.density
                      ? 'Switch to support mode'
                      : 'Disable heat map',
            ),
          ),
          Semantics(
            identifier: 'turf-map-dashboard-btn',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.dashboard_outlined),
              onPressed: _navigateToDashboard,
              tooltip: 'Turf Dashboard',
            ),
          ),
          Semantics(
            identifier: 'turf-map-refresh-btn',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.read(turfListProvider.notifier).refresh(),
              tooltip: 'Refresh turfs',
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: _initialZoom,
              onTap: (tapPosition, point) {
                // Check if tap is inside a turf polygon
                for (final turf in turfState.turfs) {
                  final points = turf.boundaryPoints;
                  if (points.length >= 3 && _isPointInPolygon(point, points)) {
                    _selectTurf(turf.turfId);
                    return;
                  }
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.mainegop.navigators',
                tileProvider: _hasCachedTiles && _selectedTurfId != null
                    ? ref
                        .read(tileCacheServiceProvider)
                        .getTileProvider(_selectedTurfId!)
                    : null,
              ),
              buildTurfPolygonLayer(
                turfState.turfs,
                selectedTurfId: _selectedTurfId,
                onTurfTap: _selectTurf,
              ),
              if (_voters.isNotEmpty)
                buildVoterClusterLayer(
                  _voters,
                  onVoterTap: _onVoterTap,
                ),
              if (_heatMapMode != null)
                HeatMapOverlay(
                  mapController: _mapController,
                  mode: _heatMapMode!,
                ),
            ],
          ),
          // Loading indicator
          if (turfState.isLoading || _loadingVoters)
            const Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: Center(child: LinearProgressIndicator()),
            ),
          // Turf detail panel
          if (_selectedTurfId != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Builder(builder: (context) {
                final turf = turfState.turfs.firstWhere(
                  (t) => t.turfId == _selectedTurfId,
                  orElse: () => const TurfInfo(
                    turfId: '',
                    name: '',
                    description: '',
                    isActive: false,
                    boundaryGeojson: '',
                    centerLat: 0,
                    centerLng: 0,
                    areaSqMeters: 0,
                    voterCount: 0,
                    createdAt: '',
                    updatedAt: '',
                  ),
                );
                return _TurfDetailPanel(
                  turf: turf,
                  voterCount: _voters.length,
                  stats: _selectedTurfStats,
                  isAdmin: isAdmin,
                  onAssign: () => _showAssignDialog(turf),
                  onWalkList: () => _navigateToWalkList(turf),
                  onDownloadTiles: () => _navigateToOfflineDownload(turf),
                  onClose: () => setState(() {
                    _selectedTurfId = null;
                    _voters = [];
                    _selectedTurfStats = null;
                    _hasCachedTiles = false;
                  }),
                );
              }),
            ),
          // Error banner
          if (turfState.error != null)
            Positioned(
              top: 8,
              left: 16,
              right: 16,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    turfState.error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: isAdmin
          ? Semantics(
              identifier: 'turf-map-draw-fab',
              button: true,
              child: FloatingActionButton.extended(
                onPressed: _navigateToDrawScreen,
                icon: const Icon(Icons.draw),
                label: const Text('Draw New Turf'),
              ),
            )
          : null,
      ),
    );
  }

  /// Simple point-in-polygon test using ray casting algorithm.
  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    var inside = false;
    var j = polygon.length - 1;
    for (var i = 0; i < polygon.length; i++) {
      final xi = polygon[i].latitude;
      final yi = polygon[i].longitude;
      final xj = polygon[j].latitude;
      final yj = polygon[j].longitude;

      if (((yi > point.longitude) != (yj > point.longitude)) &&
          (point.latitude < (xj - xi) * (point.longitude - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }
}

/// Bottom panel showing selected turf details.
class _TurfDetailPanel extends StatelessWidget {
  final TurfInfo turf;
  final int voterCount;
  final TurfStats? stats;
  final bool isAdmin;
  final VoidCallback onAssign;
  final VoidCallback onWalkList;
  final VoidCallback onDownloadTiles;
  final VoidCallback onClose;

  const _TurfDetailPanel({
    required this.turf,
    required this.voterCount,
    required this.stats,
    required this.isAdmin,
    required this.onAssign,
    required this.onWalkList,
    required this.onDownloadTiles,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final areaAcres = turf.areaSqMeters / 4046.86;
    final completion = stats?.completionPercentage ?? 0.0;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, -2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  turf.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: onClose,
              ),
            ],
          ),
          if (turf.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(turf.description, style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: 8),
          // Completion progress
          if (stats != null) ...[
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: completion / 100,
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${completion.toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              _StatChip(
                icon: Icons.people,
                label: '$voterCount voters',
              ),
              const SizedBox(width: 12),
              _StatChip(
                icon: Icons.square_foot,
                label: '${areaAcres.toStringAsFixed(0)} acres',
              ),
              if (stats != null) ...[
                const SizedBox(width: 12),
                _StatChip(
                  icon: Icons.check_circle_outline,
                  label: '${stats!.contactedVoters} contacted',
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          // Action buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Semantics(
                identifier: 'turf-map-walk-list-btn',
                button: true,
                child: FilledButton.tonalIcon(
                  onPressed: onWalkList,
                  icon: const Icon(Icons.list_alt, size: 18),
                  label: const Text('Walk List'),
                ),
              ),
              Semantics(
                identifier: 'turf-map-offline-tiles-btn',
                button: true,
                child: FilledButton.tonalIcon(
                  onPressed: onDownloadTiles,
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Offline Tiles'),
                ),
              ),
              if (isAdmin)
                Semantics(
                  identifier: 'turf-map-assign-btn',
                  button: true,
                  child: FilledButton.tonalIcon(
                    onPressed: onAssign,
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('Assign'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// Bottom sheet showing voter summary when a pin is tapped.
class _VoterSummarySheet extends StatelessWidget {
  final VoterPin voter;

  const _VoterSummarySheet({required this.voter});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            voter.fullName,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          _InfoRow(icon: Icons.how_to_vote, label: 'Party', value: voter.party),
          _InfoRow(icon: Icons.check_circle, label: 'Status', value: voter.status),
          _InfoRow(
            icon: Icons.location_on,
            label: 'Location',
            value: '${voter.latitude.toStringAsFixed(4)}, ${voter.longitude.toStringAsFixed(4)}',
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(value),
        ],
      ),
    );
  }
}
