import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../services/map_service.dart';

/// Map view for walk list showing voter markers with door status colors
/// and a route polyline connecting voters in walk order.
class WalkListMapView extends StatelessWidget {
  final List<WalkListVoter> voters;
  final Map<String, String> doorStatuses;

  const WalkListMapView({
    super.key,
    required this.voters,
    required this.doorStatuses,
  });

  @override
  Widget build(BuildContext context) {
    final points = voters
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
        PolylineLayer(
          polylines: [
            Polyline(
              points: points,
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.6),
              strokeWidth: 3.0,
            ),
          ],
        ),
        MarkerLayer(
          markers: voters
              .where((v) => v.latitude != 0.0 && v.longitude != 0.0)
              .map((voter) {
            final status = doorStatuses[voter.voterId];
            final color = _markerColor(status, voter.party);
            return Marker(
              point: voter.location,
              width: 32,
              height: 32,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                alignment: Alignment.center,
                child: status != null
                    ? Icon(_statusIcon(status), size: 14, color: Colors.white)
                    : Text(
                        '${voter.sequence}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Color _markerColor(String? status, String party) {
    if (status == null) return _partyColor(party);
    switch (status) {
      case 'answered':
        return Colors.green;
      case 'refused':
        return Colors.red;
      case 'not_home':
        return Colors.grey;
      case 'moved':
        return Colors.orange;
      default:
        return _partyColor(party);
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'answered':
        return Icons.check;
      case 'refused':
        return Icons.close;
      case 'not_home':
        return Icons.question_mark;
      case 'moved':
        return Icons.arrow_forward;
      default:
        return Icons.circle;
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
}
