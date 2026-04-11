import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/map_service.dart';
import 'widgets/heat_map_painter.dart';

/// A FlutterMap child widget that renders a heat map overlay using CustomPainter.
///
/// Fetches density grid data from the server based on the current viewport
/// and renders colored gradient circles via [HeatMapPainter].
class HeatMapOverlay extends ConsumerStatefulWidget {
  final MapController mapController;
  final HeatMapMode mode;

  const HeatMapOverlay({
    super.key,
    required this.mapController,
    required this.mode,
  });

  @override
  ConsumerState<HeatMapOverlay> createState() => _HeatMapOverlayState();
}

class _HeatMapOverlayState extends ConsumerState<HeatMapOverlay> {
  List<DensityGridCell> _cells = [];
  Timer? _debounceTimer;
  StreamSubscription<MapEvent>? _mapEventSub;

  @override
  void initState() {
    super.initState();
    _mapEventSub = widget.mapController.mapEventStream.listen((_) {
      _debouncedFetch();
    });
    // Initial fetch after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchDensityGrid());
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _mapEventSub?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(HeatMapOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) {
      _fetchDensityGrid();
    }
  }

  void _debouncedFetch() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _fetchDensityGrid();
    });
  }

  double _gridSizeForZoom(double zoom) {
    if (zoom >= 14) return 0.001;
    if (zoom >= 10) return 0.005;
    return 0.01;
  }

  Future<void> _fetchDensityGrid() async {
    if (!mounted) return;

    final camera = widget.mapController.camera;
    final bounds = camera.visibleBounds;
    final gridSize = _gridSizeForZoom(camera.zoom);

    try {
      final service = ref.read(mapServiceProvider);
      final cells = await service.getVoterDensityGrid(
        minLat: bounds.south,
        minLng: bounds.west,
        maxLat: bounds.north,
        maxLng: bounds.east,
        gridSize: gridSize,
      );
      if (mounted) {
        setState(() => _cells = cells);
      }
    } catch (_) {
      // Silently fail -- heat map is non-critical
    }
  }

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    return CustomPaint(
      size: Size(camera.size.width, camera.size.height),
      painter: HeatMapPainter(
        cells: _cells,
        camera: camera,
        mode: widget.mode,
      ),
    );
  }
}
