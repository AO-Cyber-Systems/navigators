import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../services/map_service.dart';

/// Color palette for turf polygons. Cycles through for distinct colors.
const _turfColors = <Color>[
  Colors.blue,
  Colors.green,
  Colors.orange,
  Colors.purple,
  Colors.teal,
  Colors.red,
  Colors.indigo,
  Colors.amber,
];

/// Builds a PolygonLayer displaying turf boundaries on the map.
///
/// Selected turf has higher opacity. Each turf gets a distinct color
/// from the palette, cycling through for large numbers of turfs.
PolygonLayer buildTurfPolygonLayer(
  List<TurfInfo> turfs, {
  String? selectedTurfId,
  Function(String)? onTurfTap,
}) {
  final polygons = <Polygon>[];

  for (var i = 0; i < turfs.length; i++) {
    final turf = turfs[i];
    final points = turf.boundaryPoints;
    if (points.length < 3) continue;

    final isSelected = turf.turfId == selectedTurfId;
    final color = _turfColors[i % _turfColors.length];

    polygons.add(Polygon(
      points: points,
      color: color.withValues(alpha: isSelected ? 0.35 : 0.15),
      borderColor: isSelected ? color : color.withValues(alpha: 0.7),
      borderStrokeWidth: isSelected ? 3.0 : 2.0,
      label: turf.name,
      labelStyle: TextStyle(
        color: color.shade700,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      hitValue: turf.turfId,
    ));
  }

  return PolygonLayer(
    polygons: polygons,
    hitNotifier: null,
  );
}

/// Extension to access shade700 equivalent from Color.
extension _ColorShade on Color {
  Color get shade700 {
    // Darken the color by 30%
    final hsl = HSLColor.fromColor(this);
    return hsl.withLightness((hsl.lightness * 0.7).clamp(0.0, 1.0)).toColor();
  }
}
