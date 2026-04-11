import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../services/map_service.dart';

/// Mode for heat map rendering.
enum HeatMapMode {
  /// Color by voter density (green -> yellow -> red).
  density,

  /// Color by support ratio (red = low support -> green = high support).
  support,
}

/// CustomPainter that renders density grid cells as radial gradient circles
/// projected onto screen coordinates via MapCamera.
class HeatMapPainter extends CustomPainter {
  final List<DensityGridCell> cells;
  final MapCamera camera;
  final HeatMapMode mode;

  HeatMapPainter({
    required this.cells,
    required this.camera,
    required this.mode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (cells.isEmpty) return;

    // Find max value for normalization
    final maxVal = mode == HeatMapMode.density
        ? cells.fold<int>(0, (max, c) => c.voterCount > max ? c.voterCount : max)
        : 1; // support ratio is already 0-1

    if (maxVal == 0) return;

    for (final cell in cells) {
      final offset = camera.getOffsetFromOrigin(LatLng(cell.gridLat, cell.gridLng));

      // Skip cells outside visible area (with margin)
      if (offset.dx < -50 ||
          offset.dy < -50 ||
          offset.dx > size.width + 50 ||
          offset.dy > size.height + 50) {
        continue;
      }

      // Radius scales with zoom level
      final radius = _radiusForZoom(camera.zoom);

      // Color based on mode
      final color = mode == HeatMapMode.density
          ? _densityColor(cell.voterCount / maxVal)
          : _supportColor(cell.supportRatio);

      final gradient = ui.Gradient.radial(
        offset,
        radius,
        [
          color.withValues(alpha: 0.6),
          color.withValues(alpha: 0.0),
        ],
        [0.0, 1.0],
      );

      final paint = Paint()..shader = gradient;
      canvas.drawCircle(offset, radius, paint);
    }
  }

  double _radiusForZoom(double zoom) {
    // Larger radius at lower zoom, smaller at higher zoom
    if (zoom >= 16) return 20;
    if (zoom >= 14) return 30;
    if (zoom >= 12) return 40;
    if (zoom >= 10) return 50;
    return 60;
  }

  /// Interpolate green -> yellow -> red based on density ratio (0-1).
  Color _densityColor(double ratio) {
    if (ratio < 0.5) {
      // Green to yellow
      final t = ratio * 2;
      return Color.lerp(Colors.green, Colors.yellow, t) ?? Colors.green;
    } else {
      // Yellow to red
      final t = (ratio - 0.5) * 2;
      return Color.lerp(Colors.yellow, Colors.red, t) ?? Colors.red;
    }
  }

  /// Interpolate red -> green based on support ratio (0-1).
  Color _supportColor(double ratio) {
    return Color.lerp(Colors.red, Colors.green, ratio) ?? Colors.grey;
  }

  @override
  bool shouldRepaint(HeatMapPainter oldDelegate) {
    return oldDelegate.cells != cells ||
        oldDelegate.camera != camera ||
        oldDelegate.mode != mode;
  }
}
