import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:eden_platform_flutter/eden_platform.dart';

import '../database/database.dart';
import '../database/daos/voter_dao.dart';

// --- Parse helpers (ConnectRPC sends proto int fields as strings) ---

int _parseInt(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

// --- Models ---

class VoterSummary {
  final String id;
  final String firstName;
  final String lastName;
  final String party;
  final String status;
  final String resCity;
  final String resZip;
  final String municipality;
  final int yearOfBirth;

  const VoterSummary({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.party,
    required this.status,
    required this.resCity,
    required this.resZip,
    required this.municipality,
    required this.yearOfBirth,
  });

  factory VoterSummary.fromJson(Map<String, dynamic> json) {
    return VoterSummary(
      id: json['id'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      party: json['party'] as String? ?? '',
      status: json['status'] as String? ?? '',
      resCity: json['resCity'] as String? ?? '',
      resZip: json['resZip'] as String? ?? '',
      municipality: json['municipality'] as String? ?? '',
      yearOfBirth: _parseInt(json['yearOfBirth']),
    );
  }

  String get fullName => '$firstName $lastName';
}

class Voter {
  final String id;
  final String firstName;
  final String middleName;
  final String lastName;
  final String suffix;
  final int yearOfBirth;
  final String resStreetAddress;
  final String resCity;
  final String resState;
  final String resZip;
  final String mailStreetAddress;
  final String mailCity;
  final String mailState;
  final String mailZip;
  final String party;
  final String status;
  final String registrationDate;
  final String county;
  final String municipality;
  final String ward;
  final String precinct;
  final String congressionalDistrict;
  final String stateSenateDistrict;
  final String stateHouseDistrict;
  final String geocodeStatus;
  final String sourceVoterId;
  final String source;
  final String votingHistory;
  final String phone;
  final String email;
  final String createdAt;
  final String updatedAt;
  final bool isSuppressed;
  final List<VoterTag> tags;

  const Voter({
    required this.id,
    required this.firstName,
    required this.middleName,
    required this.lastName,
    required this.suffix,
    required this.yearOfBirth,
    required this.resStreetAddress,
    required this.resCity,
    required this.resState,
    required this.resZip,
    required this.mailStreetAddress,
    required this.mailCity,
    required this.mailState,
    required this.mailZip,
    required this.party,
    required this.status,
    required this.registrationDate,
    required this.county,
    required this.municipality,
    required this.ward,
    required this.precinct,
    required this.congressionalDistrict,
    required this.stateSenateDistrict,
    required this.stateHouseDistrict,
    required this.geocodeStatus,
    required this.sourceVoterId,
    required this.source,
    required this.votingHistory,
    required this.phone,
    required this.email,
    required this.createdAt,
    required this.updatedAt,
    required this.isSuppressed,
    required this.tags,
  });

  factory Voter.fromJson(Map<String, dynamic> json) {
    final tagsJson = json['tags'] as List<dynamic>? ?? [];
    return Voter(
      id: json['id'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      middleName: json['middleName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      suffix: json['suffix'] as String? ?? '',
      yearOfBirth: _parseInt(json['yearOfBirth']),
      resStreetAddress: json['resStreetAddress'] as String? ?? '',
      resCity: json['resCity'] as String? ?? '',
      resState: json['resState'] as String? ?? '',
      resZip: json['resZip'] as String? ?? '',
      mailStreetAddress: json['mailStreetAddress'] as String? ?? '',
      mailCity: json['mailCity'] as String? ?? '',
      mailState: json['mailState'] as String? ?? '',
      mailZip: json['mailZip'] as String? ?? '',
      party: json['party'] as String? ?? '',
      status: json['status'] as String? ?? '',
      registrationDate: json['registrationDate'] as String? ?? '',
      county: json['county'] as String? ?? '',
      municipality: json['municipality'] as String? ?? '',
      ward: json['ward'] as String? ?? '',
      precinct: json['precinct'] as String? ?? '',
      congressionalDistrict: json['congressionalDistrict'] as String? ?? '',
      stateSenateDistrict: json['stateSenateDistrict'] as String? ?? '',
      stateHouseDistrict: json['stateHouseDistrict'] as String? ?? '',
      geocodeStatus: json['geocodeStatus'] as String? ?? '',
      sourceVoterId: json['sourceVoterId'] as String? ?? '',
      source: json['source'] as String? ?? '',
      votingHistory: json['votingHistory'] as String? ?? '[]',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
      isSuppressed: json['isSuppressed'] as bool? ?? false,
      tags: tagsJson
          .map((t) => VoterTag.fromJson(t as Map<String, dynamic>))
          .toList(),
    );
  }

  String get fullName {
    final parts = [firstName, middleName, lastName, suffix]
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.join(' ');
  }

  String get residenceAddress {
    final parts = [resStreetAddress, resCity, resState, resZip]
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.join(', ');
  }

  String get mailingAddress {
    final parts = [mailStreetAddress, mailCity, mailState, mailZip]
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.join(', ');
  }

  List<VotingRecord> get votingRecords {
    try {
      final list = jsonDecode(votingHistory) as List<dynamic>;
      return list
          .map((e) => VotingRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}

class VoterTag {
  final String id;
  final String name;
  final String color;
  final String createdBy;
  final String createdAt;

  const VoterTag({
    required this.id,
    required this.name,
    required this.color,
    required this.createdBy,
    required this.createdAt,
  });

  factory VoterTag.fromJson(Map<String, dynamic> json) {
    return VoterTag(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      color: json['color'] as String? ?? '',
      createdBy: json['createdBy'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class VotingRecord {
  final String election;
  final String date;
  final String method;

  const VotingRecord({
    required this.election,
    required this.date,
    required this.method,
  });

  factory VotingRecord.fromJson(Map<String, dynamic> json) {
    return VotingRecord(
      election: json['election'] as String? ?? '',
      date: json['date'] as String? ?? '',
      method: json['method'] as String? ?? '',
    );
  }
}

class SuppressedVoter {
  final String id;
  final String voterId;
  final String firstName;
  final String lastName;
  final String resStreetAddress;
  final String resCity;
  final String resState;
  final String resZip;
  final String reason;
  final String addedBy; // user UUID
  final DateTime? addedAt;

  const SuppressedVoter({
    required this.id,
    required this.voterId,
    required this.firstName,
    required this.lastName,
    required this.resStreetAddress,
    required this.resCity,
    required this.resState,
    required this.resZip,
    required this.reason,
    required this.addedBy,
    this.addedAt,
  });

  factory SuppressedVoter.fromJson(Map<String, dynamic> json) {
    return SuppressedVoter(
      id: json['id'] as String? ?? '',
      voterId: json['voterId'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      resStreetAddress: json['resStreetAddress'] as String? ?? '',
      resCity: json['resCity'] as String? ?? '',
      resState: json['resState'] as String? ?? '',
      resZip: json['resZip'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      addedBy: json['addedBy'] as String? ?? '',
      addedAt: DateTime.tryParse(json['addedAt'] as String? ?? ''),
    );
  }

  String get fullName => '$firstName $lastName'.trim();

  String get residenceAddress {
    final parts = [resStreetAddress, resCity, resState, resZip]
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.join(', ');
  }
}

class VoterFilters {
  final String? party;
  final String? status;
  final String? congressionalDistrict;
  final String? stateSenateDistrict;
  final String? stateHouseDistrict;
  final String? municipality;
  final String? county;
  final int? minVoteCount;

  const VoterFilters({
    this.party,
    this.status,
    this.congressionalDistrict,
    this.stateSenateDistrict,
    this.stateHouseDistrict,
    this.municipality,
    this.county,
    this.minVoteCount,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (party != null && party!.isNotEmpty) map['party'] = party;
    if (status != null && status!.isNotEmpty) map['status'] = status;
    if (congressionalDistrict != null && congressionalDistrict!.isNotEmpty) {
      map['congressionalDistrict'] = congressionalDistrict;
    }
    if (stateSenateDistrict != null && stateSenateDistrict!.isNotEmpty) {
      map['stateSenateDistrict'] = stateSenateDistrict;
    }
    if (stateHouseDistrict != null && stateHouseDistrict!.isNotEmpty) {
      map['stateHouseDistrict'] = stateHouseDistrict;
    }
    if (municipality != null && municipality!.isNotEmpty) {
      map['municipality'] = municipality;
    }
    if (county != null && county!.isNotEmpty) map['county'] = county;
    if (minVoteCount != null && minVoteCount! > 0) {
      map['minVoteCount'] = minVoteCount;
    }
    return map;
  }

  bool get hasActiveFilters =>
      (party != null && party!.isNotEmpty) ||
      (status != null && status!.isNotEmpty) ||
      (congressionalDistrict != null && congressionalDistrict!.isNotEmpty) ||
      (stateSenateDistrict != null && stateSenateDistrict!.isNotEmpty) ||
      (stateHouseDistrict != null && stateHouseDistrict!.isNotEmpty) ||
      (municipality != null && municipality!.isNotEmpty) ||
      (county != null && county!.isNotEmpty) ||
      (minVoteCount != null && minVoteCount! > 0);
}

// --- Service ---

class VoterService {
  final String _baseUrl;
  final String? Function() _getAccessToken;

  VoterService({required String baseUrl, required String? Function() getAccessToken})
      : _baseUrl = baseUrl,
        _getAccessToken = getAccessToken;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_getAccessToken() != null) 'Authorization': 'Bearer ${_getAccessToken()}',
      };

  Future<Map<String, dynamic>> _post(String method, Map<String, dynamic> body) async {
    final url = Uri.parse('$_baseUrl/navigators.v1.VoterService/$method');
    final response = await http.post(url, headers: _headers, body: jsonEncode(body));
    if (response.statusCode != 200) {
      throw Exception('$method failed: ${response.statusCode} ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<({List<VoterSummary> voters, int totalCount})> searchVoters(
    String query, {
    int pageSize = 50,
    int page = 0,
  }) async {
    final result = await _post('SearchVoters', {
      'query': query,
      'pageSize': pageSize,
      'page': page,
    });
    final voters = (result['voters'] as List<dynamic>? ?? [])
        .map((v) => VoterSummary.fromJson(v as Map<String, dynamic>))
        .toList();
    final totalCount = _parseInt(result['totalCount']);
    return (voters: voters, totalCount: totalCount);
  }

  Future<Voter> getVoter(String voterId) async {
    final result = await _post('GetVoter', {'voterId': voterId});
    final voterJson = result['voter'] as Map<String, dynamic>? ?? {};
    // Merge top-level fields into voter json for the enriched response
    voterJson['isSuppressed'] = result['isSuppressed'] ?? false;
    voterJson['tags'] = result['tags'] ?? [];
    return Voter.fromJson(voterJson);
  }

  Future<({List<VoterSummary> voters, int totalCount})> listVoters(
    VoterFilters filters, {
    int pageSize = 50,
    int page = 0,
  }) async {
    final body = <String, dynamic>{
      'pageSize': pageSize,
      'page': page,
    };
    final filtersJson = filters.toJson();
    if (filtersJson.isNotEmpty) {
      body['filters'] = filtersJson;
    }
    final result = await _post('ListVoters', body);
    final voters = (result['voters'] as List<dynamic>? ?? [])
        .map((v) => VoterSummary.fromJson(v as Map<String, dynamic>))
        .toList();
    final totalCount = _parseInt(result['totalCount']);
    return (voters: voters, totalCount: totalCount);
  }

  Future<List<VoterTag>> getVoterTags(String voterId) async {
    final result = await _post('GetVoterTags', {'voterId': voterId});
    return (result['tags'] as List<dynamic>? ?? [])
        .map((t) => VoterTag.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  Future<void> assignTagToVoter(String voterId, String tagId) async {
    await _post('AssignTagToVoter', {'voterId': voterId, 'tagId': tagId});
  }

  Future<void> removeTagFromVoter(String voterId, String tagId) async {
    await _post('RemoveTagFromVoter', {'voterId': voterId, 'tagId': tagId});
  }

  Future<void> addToSuppressionList(String voterId, String reason) async {
    await _post('AddToSuppressionList', {'voterId': voterId, 'reason': reason});
  }

  Future<void> removeFromSuppressionList(String voterId) async {
    await _post('RemoveFromSuppressionList', {'voterId': voterId});
  }

  Future<({List<SuppressedVoter> voters, int totalCount})> listSuppressedVoters({
    int pageSize = 50,
    int page = 0,
  }) async {
    final result = await _post('ListSuppressedVoters', {
      'pageSize': pageSize,
      'page': page,
    });
    final voters = (result['voters'] as List<dynamic>? ?? [])
        .map((v) => SuppressedVoter.fromJson(v as Map<String, dynamic>))
        .toList();
    final totalCount = _parseInt(result['totalCount']);
    return (voters: voters, totalCount: totalCount);
  }
}

// --- Offline-first extensions ---

/// Extension to convert a Drift Voter row to a VoterSummary for UI display.
extension VoterToSummary on dynamic {
  /// Converts a Drift-generated Voter data class to a VoterSummary.
  /// The Drift Voter class is from database.g.dart; we access fields directly.
  static VoterSummary fromDriftVoter({
    required String id,
    required String firstName,
    required String lastName,
    required String party,
    required String status,
    required String resCity,
    required String resZip,
    required String municipality,
    required int yearOfBirth,
  }) {
    return VoterSummary(
      id: id,
      firstName: firstName,
      lastName: lastName,
      party: party,
      status: status,
      resCity: resCity,
      resZip: resZip,
      municipality: municipality,
      yearOfBirth: yearOfBirth,
    );
  }
}

// --- Providers ---

final voterServiceProvider = Provider<VoterService>((ref) {
  final auth = ref.watch(authProvider);
  const envUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  final baseUrl = envUrl.isNotEmpty ? envUrl : 'http://localhost:8080';
  return VoterService(
    baseUrl: baseUrl,
    getAccessToken: () => auth.accessToken,
  );
});

// --- Search state ---

class VoterSearchState {
  final String query;
  final List<VoterSummary> results;
  final int totalCount;
  final bool isLoading;
  final String? error;
  final int page;

  const VoterSearchState({
    this.query = '',
    this.results = const [],
    this.totalCount = 0,
    this.isLoading = false,
    this.error,
    this.page = 0,
  });

  VoterSearchState copyWith({
    String? query,
    List<VoterSummary>? results,
    int? totalCount,
    bool? isLoading,
    String? error,
    int? page,
  }) {
    return VoterSearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      totalCount: totalCount ?? this.totalCount,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      page: page ?? this.page,
    );
  }

  bool get hasMore => results.length < totalCount;
}

class VoterSearchNotifier extends StateNotifier<VoterSearchState> {
  final VoterService _service;

  VoterSearchNotifier(this._service) : super(const VoterSearchState());

  Future<void> search(String query) async {
    state = state.copyWith(query: query, isLoading: true, page: 0);
    try {
      final result = await _service.searchVoters(query);
      state = state.copyWith(
        results: result.voters,
        totalCount: result.totalCount,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading) return;
    final nextPage = state.page + 1;
    state = state.copyWith(isLoading: true);
    try {
      final result = await _service.searchVoters(state.query, page: nextPage);
      state = state.copyWith(
        results: [...state.results, ...result.voters],
        totalCount: result.totalCount,
        isLoading: false,
        page: nextPage,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void clear() {
    state = const VoterSearchState();
  }
}

final voterSearchProvider =
    StateNotifierProvider<VoterSearchNotifier, VoterSearchState>((ref) {
  return VoterSearchNotifier(ref.watch(voterServiceProvider));
});

// --- Voter list state (filtered) ---

class VoterListState {
  final VoterFilters filters;
  final List<VoterSummary> voters;
  final int totalCount;
  final bool isLoading;
  final String? error;
  final int page;

  const VoterListState({
    this.filters = const VoterFilters(),
    this.voters = const [],
    this.totalCount = 0,
    this.isLoading = false,
    this.error,
    this.page = 0,
  });

  VoterListState copyWith({
    VoterFilters? filters,
    List<VoterSummary>? voters,
    int? totalCount,
    bool? isLoading,
    String? error,
    int? page,
  }) {
    return VoterListState(
      filters: filters ?? this.filters,
      voters: voters ?? this.voters,
      totalCount: totalCount ?? this.totalCount,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      page: page ?? this.page,
    );
  }

  bool get hasMore => voters.length < totalCount;
}

class VoterListNotifier extends StateNotifier<VoterListState> {
  final VoterService _service;
  final NavigatorsDatabase? _db;

  VoterListNotifier(this._service, this._db) : super(const VoterListState());

  /// Load voters with offline-first fallback.
  /// Tries local Drift DB first; if local data exists, returns it.
  /// Falls back to network call (existing behavior) when local is empty.
  Future<void> loadVoters({VoterFilters? filters}) async {
    final activeFilters = filters ?? state.filters;
    state = state.copyWith(filters: activeFilters, isLoading: true, page: 0);

    // Try local DB first
    if (_db != null) {
      try {
        final voterDao = VoterDao(_db);
        final localVoters = await voterDao.getAllVoters();

        if (localVoters.isNotEmpty) {
          var summaries = localVoters.map((v) =>
              VoterToSummary.fromDriftVoter(
                id: v.id,
                firstName: v.firstName,
                lastName: v.lastName,
                party: v.party,
                status: v.status,
                resCity: v.resCity,
                resZip: v.resZip,
                municipality: '',
                yearOfBirth: v.yearOfBirth ?? 0,
              )).toList();

          // Apply local filters
          if (activeFilters.party != null && activeFilters.party!.isNotEmpty) {
            summaries = summaries
                .where((v) => v.party.toLowerCase() == activeFilters.party!.toLowerCase())
                .toList();
          }
          if (activeFilters.status != null && activeFilters.status!.isNotEmpty) {
            summaries = summaries
                .where((v) => v.status.toLowerCase() == activeFilters.status!.toLowerCase())
                .toList();
          }

          state = state.copyWith(
            voters: summaries,
            totalCount: summaries.length,
            isLoading: false,
          );
          return;
        }
      } catch (_) {
        // Local DB read failed -- fall through to network
      }
    }

    // Fall back to network call (existing behavior)
    try {
      final result = await _service.listVoters(activeFilters);
      state = state.copyWith(
        voters: result.voters,
        totalCount: result.totalCount,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading) return;
    final nextPage = state.page + 1;
    state = state.copyWith(isLoading: true);
    try {
      final result = await _service.listVoters(state.filters, page: nextPage);
      state = state.copyWith(
        voters: [...state.voters, ...result.voters],
        totalCount: result.totalCount,
        isLoading: false,
        page: nextPage,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    await loadVoters();
  }
}

final voterListProvider =
    StateNotifierProvider<VoterListNotifier, VoterListState>((ref) {
  NavigatorsDatabase? db;
  try {
    db = ref.watch(databaseProvider);
  } catch (_) {
    // Database not yet initialized
  }
  return VoterListNotifier(ref.watch(voterServiceProvider), db);
});

// --- Voter detail provider ---

final voterDetailProvider =
    FutureProvider.family<Voter, String>((ref, voterId) async {
  final service = ref.watch(voterServiceProvider);
  return service.getVoter(voterId);
});
