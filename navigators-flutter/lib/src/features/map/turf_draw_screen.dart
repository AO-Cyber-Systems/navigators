import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_dragmarker/flutter_map_dragmarker.dart';
import 'package:flutter_map_line_editor/flutter_map_line_editor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../services/map_service.dart';

/// Screen for drawing a turf polygon boundary on the map.
///
/// Admin taps points on the map to define a polygon, enters a turf name,
/// and saves the boundary as GeoJSON via the TurfService API.
class TurfDrawScreen extends ConsumerStatefulWidget {
  const TurfDrawScreen({super.key});

  @override
  ConsumerState<TurfDrawScreen> createState() => _TurfDrawScreenState();
}

class _TurfDrawScreenState extends ConsumerState<TurfDrawScreen> {
  final _nameController = TextEditingController();
  final _polygonPoints = <LatLng>[];
  late PolyEditor _polyEditor;
  bool _saving = false;

  // Augusta, Maine
  static const _initialCenter = LatLng(44.3106, -69.7795);

  @override
  void initState() {
    super.initState();
    _polyEditor = PolyEditor(
      addClosePathMarker: true,
      points: _polygonPoints,
      pointIcon: const Icon(Icons.crop_square, size: 23, color: Colors.red),
      intermediateIcon: const Icon(Icons.lens, size: 15, color: Colors.grey),
      callbackRefresh: (LatLng? _) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Convert polygon points to GeoJSON Polygon format.
  /// CRITICAL: GeoJSON coordinates are [longitude, latitude].
  /// LatLng stores (latitude, longitude). Must swap order.
  /// Close the ring by appending the first point at the end.
  String _toGeoJson(List<LatLng> points) {
    final coords = points.map((p) => [p.longitude, p.latitude]).toList();
    // Close the ring
    if (coords.isNotEmpty) {
      coords.add([points.first.longitude, points.first.latitude]);
    }
    return jsonEncode({
      'type': 'Polygon',
      'coordinates': [coords],
    });
  }

  Future<void> _saveTurf() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _polygonPoints.length < 3) return;

    setState(() => _saving = true);

    try {
      final geojson = _toGeoJson(_polygonPoints);
      await ref.read(mapServiceProvider).createTurf(name, '', geojson);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Turf "$name" created successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create turf: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _undoLastPoint() {
    if (_polygonPoints.isNotEmpty) {
      setState(() {
        _polygonPoints.removeLast();
      });
    }
  }

  void _clearPoints() {
    setState(() {
      _polygonPoints.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _nameController.text.trim().isNotEmpty && _polygonPoints.length >= 3;

    return Semantics(
      identifier: 'turf-draw-screen',
      explicitChildNodes: true,
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Draw Turf Boundary'),
        actions: [
          Semantics(
            identifier: 'turf-draw-undo-btn',
            button: true,
            child: TextButton.icon(
              onPressed: _polygonPoints.isNotEmpty ? _undoLastPoint : null,
              icon: const Icon(Icons.undo),
              label: const Text('Undo'),
            ),
          ),
          Semantics(
            identifier: 'turf-draw-clear-btn',
            button: true,
            child: TextButton.icon(
              onPressed: _polygonPoints.isNotEmpty ? _clearPoints : null,
              icon: const Icon(Icons.clear),
              label: const Text('Clear'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: _initialCenter,
                initialZoom: 10,
                onTap: (_, latLng) {
                  _polyEditor.add(_polygonPoints, latLng);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.mainegop.navigators',
                ),
                PolygonLayer<String>(
                  polygons: _polygonPoints.length >= 3
                      ? <Polygon<String>>[
                          Polygon<String>(
                            points: _polygonPoints,
                            color: Colors.blue.withValues(alpha: 0.15),
                            borderColor: Colors.blue,
                            borderStrokeWidth: 2.0,
                            hitValue: 'draw',
                          ),
                        ]
                      : <Polygon<String>>[],
                ),
                DragMarkers(markers: _polyEditor.edit()),
              ],
            ),
          ),
          // Bottom controls
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2)),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${_polygonPoints.length} point${_polygonPoints.length == 1 ? '' : 's'} placed. '
                    'Tap the map to add points.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Semantics(
                    identifier: 'turf-draw-name',
                    textField: true,
                    child: TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Turf Name',
                        hintText: 'Enter a name for this turf',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    identifier: 'turf-draw-save-btn',
                    button: true,
                    child: FilledButton.icon(
                      onPressed: canSave && !_saving ? _saveTurf : null,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: Text(_saving ? 'Saving...' : 'Save Turf'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
