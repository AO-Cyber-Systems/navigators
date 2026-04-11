import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:eden_platform_flutter/eden_platform.dart';
import 'package:latlong2/latlong.dart';

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
      centerLat: (json['centerLat'] as num?)?.toDouble() ?? 0.0,
      centerLng: (json['centerLng'] as num?)?.toDouble() ?? 0.0,
      areaSqMeters: (json['areaSqMeters'] as num?)?.toDouble() ?? 0.0,
      voterCount: (json['voterCount'] as num?)?.toInt() ?? 0,
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
        final lng = (p[0] as num).toDouble();
        final lat = (p[1] as num).toDouble();
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
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      party: json['party'] as String? ?? '',
      status: json['status'] as String? ?? '',
    );
  }

  String get fullName => '$firstName $lastName';

  LatLng get location => LatLng(latitude, longitude);
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
    final totalCount = (result['totalCount'] as num?)?.toInt() ?? 0;
    return (voters: voters, totalCount: totalCount);
  }

  Future<void> assignUserToTurf(String turfId, String userId) async {
    await _post('AssignUserToTurf', {'turfId': turfId, 'userId': userId});
  }

  Future<void> removeUserFromTurf(String turfId, String userId) async {
    await _post('RemoveUserFromTurf', {'turfId': turfId, 'userId': userId});
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
