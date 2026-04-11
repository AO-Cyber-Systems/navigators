import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';

import '../../../services/map_service.dart';

/// Returns the color for a voter pin based on party affiliation.
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

/// Builds a MarkerClusterLayerWidget displaying voter pins on the map.
///
/// Voters are colored by party and clustered at low zoom levels.
/// [onVoterTap] is called when a voter marker is tapped.
MarkerClusterLayerWidget buildVoterClusterLayer(
  List<VoterPin> voters, {
  Function(VoterPin)? onVoterTap,
}) {
  // Build a lookup map so we can find the VoterPin from a marker tap.
  final markerToVoter = <int, VoterPin>{};

  final markers = <Marker>[];
  for (var i = 0; i < voters.length; i++) {
    final voter = voters[i];
    if (voter.latitude == 0.0 && voter.longitude == 0.0) continue;

    markerToVoter[i] = voter;
    final color = _partyColor(voter.party);

    markers.add(Marker(
      point: voter.location,
      width: 36,
      height: 36,
      child: GestureDetector(
        onTap: () => onVoterTap?.call(voter),
        child: Icon(
          Icons.location_pin,
          color: color,
          size: 36,
        ),
      ),
    ));
  }

  return MarkerClusterLayerWidget(
    options: MarkerClusterLayerOptions(
      maxClusterRadius: 80,
      markers: markers,
      builder: (context, markers) {
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade700,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          alignment: Alignment.center,
          child: Text(
            '${markers.length}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    ),
  );
}
