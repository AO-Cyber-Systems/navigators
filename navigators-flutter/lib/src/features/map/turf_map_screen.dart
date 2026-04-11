import 'package:eden_platform_flutter/eden_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../services/map_service.dart';
import 'turf_draw_screen.dart';
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
      });
      return;
    }

    setState(() {
      _selectedTurfId = turfId;
      _loadingVoters = true;
    });

    try {
      final service = ref.read(mapServiceProvider);
      final result = await service.getVotersInTurf(turfId);
      if (mounted) {
        setState(() {
          _voters = result.voters;
          _loadingVoters = false;
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
        content: TextField(
          controller: userIdController,
          decoration: const InputDecoration(
            labelText: 'User ID',
            hintText: 'Enter navigator user ID',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, userIdController.text.trim()),
            child: const Text('Assign'),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Turf Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(turfListProvider.notifier).refresh(),
            tooltip: 'Refresh turfs',
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
              child: _TurfDetailPanel(
                turf: turfState.turfs.firstWhere(
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
                ),
                voterCount: _voters.length,
                isAdmin: isAdmin,
                onAssign: () {
                  final turf = turfState.turfs.firstWhere(
                    (t) => t.turfId == _selectedTurfId,
                  );
                  _showAssignDialog(turf);
                },
                onClose: () => setState(() {
                  _selectedTurfId = null;
                  _voters = [];
                }),
              ),
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
          ? FloatingActionButton.extended(
              onPressed: _navigateToDrawScreen,
              icon: const Icon(Icons.draw),
              label: const Text('Draw New Turf'),
            )
          : null,
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
  final bool isAdmin;
  final VoidCallback onAssign;
  final VoidCallback onClose;

  const _TurfDetailPanel({
    required this.turf,
    required this.voterCount,
    required this.isAdmin,
    required this.onAssign,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final areaAcres = turf.areaSqMeters / 4046.86;

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
          const SizedBox(height: 12),
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
            ],
          ),
          if (isAdmin) ...[
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: onAssign,
              icon: const Icon(Icons.person_add),
              label: const Text('Assign Navigator'),
            ),
          ],
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
