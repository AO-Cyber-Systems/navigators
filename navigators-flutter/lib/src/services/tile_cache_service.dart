// FMTC (flutter_map_tile_caching) is licensed under GPL-3.0.
// A commercial license from the FMTC author is required for production release.
// For MVP/pilot use, GPL-3 is acceptable.

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

/// Manages per-turf offline tile stores using FMTC.
class TileCacheService {
  static const String _osmUrlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const int _minZoom = 12;
  static const int _maxZoom = 18;
  static const int _rateLimit = 200;
  static const int _parallelThreads = 5;

  /// Get or create an FMTC store for a specific turf.
  FMTCStore getStore(String turfId) {
    return FMTCStore('turf-$turfId');
  }

  /// Create the store if it does not already exist.
  Future<void> ensureStore(String turfId) async {
    final store = getStore(turfId);
    await store.manage.create();
  }

  /// Build a downloadable region from boundary points.
  DownloadableRegion _buildRegion(List<LatLng> boundaryPoints) {
    final region = CustomPolygonRegion(boundaryPoints);
    return region.toDownloadable(
      minZoom: _minZoom,
      maxZoom: _maxZoom,
      options: TileLayer(
        urlTemplate: _osmUrlTemplate,
        userAgentPackageName: 'com.mainegop.navigators',
      ),
    );
  }

  /// Estimate the number of tiles to download for a turf polygon.
  Future<int> estimateTileCount(
    String turfId,
    List<LatLng> boundaryPoints,
  ) async {
    await ensureStore(turfId);
    final store = getStore(turfId);
    final downloadable = _buildRegion(boundaryPoints);
    return store.download.countTiles(downloadable);
  }

  /// Start downloading tiles for a turf polygon.
  /// Returns a stream of download progress events.
  Stream<DownloadProgress> downloadTiles(
    String turfId,
    List<LatLng> boundaryPoints,
  ) {
    final store = getStore(turfId);
    final downloadable = _buildRegion(boundaryPoints);
    final result = store.download.startForeground(
      region: downloadable,
      parallelThreads: _parallelThreads,
      rateLimit: _rateLimit,
    );
    return result.downloadProgress;
  }

  /// Delete a turf's cached tiles.
  Future<void> deleteStore(String turfId) async {
    final store = getStore(turfId);
    await store.manage.delete();
  }

  /// Check if a store exists and has tiles.
  Future<bool> hasCache(String turfId) async {
    try {
      final store = getStore(turfId);
      final stats = await store.stats.all;
      return stats.length > 0;
    } catch (_) {
      return false;
    }
  }

  /// Get an FMTC tile provider for a specific turf store.
  /// Uses cache-first strategy so tiles are served offline.
  FMTCTileProvider getTileProvider(String turfId) {
    return FMTCTileProvider(
      stores: {'turf-$turfId': BrowseStoreStrategy.readUpdateCreate},
      loadingStrategy: BrowseLoadingStrategy.cacheFirst,
    );
  }
}

/// Riverpod provider for TileCacheService.
final tileCacheServiceProvider = Provider<TileCacheService>((ref) {
  return TileCacheService();
});
