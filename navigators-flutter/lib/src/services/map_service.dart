import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:eden_platform_flutter/eden_platform.dart';
import 'package:latlong2/latlong.dart';

// --- Parse helpers (ConnectRPC sends proto int fields as strings) ---

int _parseInt(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

double _parseDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}

// --- Models ---

class TurfInfo {
  final String turfId;
  final String name;
  final String description;
  final bool isActive;
  final String boundaryGeojson;
  final double centerLat;
  final double centerLng;
  final double areaSqMeters;
  final int voterCount;
  final String createdAt;
  final String updatedAt;

  const TurfInfo({
    required this.turfId,
    required this.name,
    required this.description,
    required this.isActive,
    required this.boundaryGeojson,
    required this.centerLat,
    required this.centerLng,
    required this.areaSqMeters,
    required this.voterCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TurfInfo.fromJson(Map<String, dynamic> json) {
    return TurfInfo(
      turfId: json['turfId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
      boundaryGeojson: json['boundaryGeojson'] as String? ?? '',
      centerLat: _parseDouble(json['centerLat']),
      centerLng: _parseDouble(json['centerLng']),
      areaSqMeters: _parseDouble(json['areaSqMeters']),
      voterCount: _parseInt(json['voterCount']),
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }

  /// Parse boundaryGeojson into a list of LatLng points.
  /// GeoJSON coordinates are [longitude, latitude]; LatLng is (latitude, longitude).
  List<LatLng> get boundaryPoints {
    if (boundaryGeojson.isEmpty) return [];
    try {
      final geo = jsonDecode(boundaryGeojson) as Map<String, dynamic>;
      final coords = geo['coordinates'] as List<dynamic>?;
      if (coords == null || coords.isEmpty) return [];
      // Polygon coordinates: first element is the outer ring
      final ring = coords[0] as List<dynamic>;
      return ring.map((point) {
        final p = point as List<dynamic>;
        final lng = _parseDouble(p[0]);
        final lat = _parseDouble(p[1]);
        return LatLng(lat, lng);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  LatLng? get center {
    if (centerLat == 0.0 && centerLng == 0.0) return null;
    return LatLng(centerLat, centerLng);
  }
}

class VoterPin {
  final String voterId;
  final String firstName;
  final String lastName;
  final double latitude;
  final double longitude;
  final String party;
  final String status;

  const VoterPin({
    required this.voterId,
    required this.firstName,
    required this.lastName,
    required this.latitude,
    required this.longitude,
    required this.party,
    required this.status,
  });

  factory VoterPin.fromJson(Map<String, dynamic> json) {
    return VoterPin(
      voterId: json['voterId'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
      party: json['party'] as String? ?? '',
      status: json['status'] as String? ?? '',
    );
  }

  String get fullName => '$firstName $lastName';

  LatLng get location => LatLng(latitude, longitude);
}

class WalkListVoter {
  final String voterId;
  final String firstName;
  final String lastName;
  final double latitude;
  final double longitude;
  final String resStreetAddress;
  final String party;
  final int sequence;

  const WalkListVoter({
    required this.voterId,
    required this.firstName,
    required this.lastName,
    required this.latitude,
    required this.longitude,
    required this.resStreetAddress,
    required this.party,
    required this.sequence,
  });

  factory WalkListVoter.fromJson(Map<String, dynamic> json) {
    return WalkListVoter(
      voterId: json['voterId'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
      resStreetAddress: json['resStreetAddress'] as String? ?? '',
      party: json['party'] as String? ?? '',
      sequence: _parseInt(json['sequence']),
    );
  }

  String get fullName => '$firstName $lastName';

  LatLng get location => LatLng(latitude, longitude);
}

class TurfStats {
  final String turfId;
  final int totalVoters;
  final int contactedVoters;
  final double completionPercentage;

  const TurfStats({
    required this.turfId,
    required this.totalVoters,
    required this.contactedVoters,
    required this.completionPercentage,
  });

  factory TurfStats.fromJson(Map<String, dynamic> json) {
    return TurfStats(
      turfId: json['turfId'] as String? ?? '',
      totalVoters: _parseInt(json['totalVoters']),
      contactedVoters: _parseInt(json['contactedVoters']),
      completionPercentage:
          _parseDouble(json['completionPercentage']),
    );
  }
}

class DensityGridCell {
  final double gridLat;
  final double gridLng;
  final int voterCount;
  final int contactedCount;
  final int supportCount;

  const DensityGridCell({
    required this.gridLat,
    required this.gridLng,
    required this.voterCount,
    required this.contactedCount,
    required this.supportCount,
  });

  factory DensityGridCell.fromJson(Map<String, dynamic> json) {
    return DensityGridCell(
      gridLat: _parseDouble(json['gridLat']),
      gridLng: _parseDouble(json['gridLng']),
      voterCount: _parseInt(json['voterCount']),
      contactedCount: _parseInt(json['contactedCount']),
      supportCount: _parseInt(json['supportCount']),
    );
  }

  LatLng get location => LatLng(gridLat, gridLng);

  /// Support ratio: 0.0 to 1.0 (supportCount / contactedCount).
  double get supportRatio =>
      contactedCount > 0 ? supportCount / contactedCount : 0.0;
}

// --- Service ---

class MapService {
  final String _baseUrl;
  final String? Function() _getAccessToken;

  MapService({required String baseUrl, required String? Function() getAccessToken})
      : _baseUrl = baseUrl,
        _getAccessToken = getAccessToken;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_getAccessToken() != null) 'Authorization': 'Bearer ${_getAccessToken()}',
      };

  Future<Map<String, dynamic>> _post(String method, Map<String, dynamic> body) async {
    final url = Uri.parse('$_baseUrl/navigators.v1.TurfService/$method');
    final response = await http.post(url, headers: _headers, body: jsonEncode(body));
    if (response.statusCode != 200) {
      throw Exception('$method failed: ${response.statusCode} ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<TurfInfo>> listTurfs() async {
    final result = await _post('ListTurfs', {});
    return (result['turfs'] as List<dynamic>? ?? [])
        .map((t) => TurfInfo.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  Future<TurfInfo> getTurf(String turfId) async {
    final result = await _post('GetTurf', {'turfId': turfId});
    final turf = result['turf'] as Map<String, dynamic>? ?? {};
    return TurfInfo.fromJson(turf);
  }

  Future<String> createTurf(String name, String description, String boundaryGeojson) async {
    final result = await _post('CreateTurf', {
      'name': name,
      'description': description,
      'boundaryGeojson': boundaryGeojson,
    });
    return result['turfId'] as String? ?? '';
  }

  Future<TurfInfo> updateTurfBoundary(String turfId, String boundaryGeojson) async {
    final result = await _post('UpdateTurfBoundary', {
      'turfId': turfId,
      'boundaryGeojson': boundaryGeojson,
    });
    final turf = result['turf'] as Map<String, dynamic>? ?? {};
    return TurfInfo.fromJson(turf);
  }

  Future<({List<VoterPin> voters, int totalCount})> getVotersInTurf(
    String turfId, {
    int pageSize = 200,
    int page = 0,
  }) async {
    final result = await _post('GetVotersInTurf', {
      'turfId': turfId,
      'pageSize': pageSize,
      'page': page,
    });
    final voters = (result['voters'] as List<dynamic>? ?? [])
        .map((v) => VoterPin.fromJson(v as Map<String, dynamic>))
        .toList();
    final totalCount = _parseInt(result['totalCount']);
    return (voters: voters, totalCount: totalCount);
  }

  Future<void> assignUserToTurf(String turfId, String userId) async {
    await _post('AssignUserToTurf', {'turfId': turfId, 'userId': userId});
  }

  Future<void> removeUserFromTurf(String turfId, String userId) async {
    await _post('RemoveUserFromTurf', {'turfId': turfId, 'userId': userId});
  }

  /// Generate a walk list with route-optimized voter ordering.
  Future<List<WalkListVoter>> generateWalkList(
    String turfId, {
    double? startLat,
    double? startLng,
  }) async {
    final body = <String, dynamic>{'turfId': turfId};
    if (startLat != null) body['startLat'] = startLat;
    if (startLng != null) body['startLng'] = startLng;
    final result = await _post('GenerateWalkList', body);
    return (result['voters'] as List<dynamic>? ?? [])
        .map((v) => WalkListVoter.fromJson(v as Map<String, dynamic>))
        .toList();
  }

  /// Get turf stats (voter count, contacted, completion %).
  Future<TurfStats> getTurfStats(String turfId) async {
    final result = await _post('GetTurfStats', {'turfId': turfId});
    final stats = result['stats'] as Map<String, dynamic>? ?? result;
    return TurfStats.fromJson(stats);
  }

  /// Get voter density grid for heat map within a bounding box.
  Future<List<DensityGridCell>> getVoterDensityGrid({
    required double minLat,
    required double minLng,
    required double maxLat,
    required double maxLng,
    required double gridSize,
  }) async {
    final result = await _post('GetVoterDensityGrid', {
      'minLat': minLat,
      'minLng': minLng,
      'maxLat': maxLat,
      'maxLng': maxLng,
      'gridSize': gridSize,
    });
    return (result['cells'] as List<dynamic>? ?? [])
        .map((c) => DensityGridCell.fromJson(c as Map<String, dynamic>))
        .toList();
  }
}

// --- Providers ---

final mapServiceProvider = Provider<MapService>((ref) {
  final auth = ref.watch(authProvider);
  const envUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  final baseUrl = envUrl.isNotEmpty ? envUrl : 'http://localhost:8080';
  return MapService(
    baseUrl: baseUrl,
    getAccessToken: () => auth.accessToken,
  );
});

// --- Turf list state ---

class TurfListState {
  final List<TurfInfo> turfs;
  final bool isLoading;
  final String? error;

  const TurfListState({
    this.turfs = const [],
    this.isLoading = false,
    this.error,
  });

  TurfListState copyWith({
    List<TurfInfo>? turfs,
    bool? isLoading,
    String? error,
  }) {
    return TurfListState(
      turfs: turfs ?? this.turfs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class TurfListNotifier extends StateNotifier<TurfListState> {
  final MapService _service;

  TurfListNotifier(this._service) : super(const TurfListState());

  Future<void> loadTurfs() async {
    state = state.copyWith(isLoading: true);
    try {
      final turfs = await _service.listTurfs();
      state = state.copyWith(turfs: turfs, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    await loadTurfs();
  }
}

final turfListProvider =
    StateNotifierProvider<TurfListNotifier, TurfListState>((ref) {
  return TurfListNotifier(ref.watch(mapServiceProvider));
});

// --- Voters in turf provider ---

final votersInTurfProvider =
    FutureProvider.family<({List<VoterPin> voters, int totalCount}), String>(
        (ref, turfId) async {
  final service = ref.watch(mapServiceProvider);
  return service.getVotersInTurf(turfId);
});
