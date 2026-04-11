import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/map_service.dart';
import '../../services/tile_cache_service.dart';

/// Screen for downloading offline map tiles for a specific turf polygon.
class OfflineDownloadScreen extends ConsumerStatefulWidget {
  final String turfId;
  final String turfName;

  const OfflineDownloadScreen({
    super.key,
    required this.turfId,
    required this.turfName,
  });

  @override
  ConsumerState<OfflineDownloadScreen> createState() =>
      _OfflineDownloadScreenState();
}

enum _DownloadState { idle, estimating, ready, downloading, complete, error }

class _OfflineDownloadScreenState
    extends ConsumerState<OfflineDownloadScreen> {
  _DownloadState _state = _DownloadState.idle;
  int _estimatedTiles = 0;
  int _downloadedTiles = 0;
  int _totalTiles = 0;
  double _progress = 0.0;
  String? _errorMessage;
  bool _hasCachedTiles = false;
  StreamSubscription<DownloadProgress>? _downloadSub;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _downloadSub?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    setState(() => _state = _DownloadState.estimating);
    try {
      final mapService = ref.read(mapServiceProvider);
      final cacheService = ref.read(tileCacheServiceProvider);

      // Check if tiles already cached
      _hasCachedTiles = await cacheService.hasCache(widget.turfId);

      // Load turf boundary and estimate tile count
      final turf = await mapService.getTurf(widget.turfId);
      final points = turf.boundaryPoints;
      if (points.isEmpty) {
        setState(() {
          _state = _DownloadState.error;
          _errorMessage = 'Turf has no boundary polygon defined.';
        });
        return;
      }

      final count = await cacheService.estimateTileCount(
        widget.turfId,
        points,
      );
      if (mounted) {
        setState(() {
          _estimatedTiles = count;
          _state = _DownloadState.ready;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _DownloadState.error;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _startDownload() async {
    setState(() {
      _state = _DownloadState.downloading;
      _downloadedTiles = 0;
      _totalTiles = _estimatedTiles;
      _progress = 0.0;
    });

    try {
      final mapService = ref.read(mapServiceProvider);
      final cacheService = ref.read(tileCacheServiceProvider);

      final turf = await mapService.getTurf(widget.turfId);
      final points = turf.boundaryPoints;

      final stream = cacheService.downloadTiles(widget.turfId, points);
      _downloadSub = stream.listen(
        (progress) {
          if (mounted) {
            setState(() {
              _downloadedTiles = progress.attemptedTilesCount;
              _totalTiles = progress.maxTilesCount;
              _progress = _totalTiles > 0
                  ? _downloadedTiles / _totalTiles
                  : 0.0;
            });
          }
        },
        onDone: () {
          if (mounted) {
            setState(() {
              _state = _DownloadState.complete;
              _hasCachedTiles = true;
              _progress = 1.0;
            });
          }
        },
        onError: (e) {
          if (mounted) {
            setState(() {
              _state = _DownloadState.error;
              _errorMessage = e.toString();
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _DownloadState.error;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _cancelDownload() {
    _downloadSub?.cancel();
    _downloadSub = null;
    setState(() => _state = _DownloadState.ready);
  }

  Future<void> _deleteCachedTiles() async {
    try {
      final cacheService = ref.read(tileCacheServiceProvider);
      await cacheService.deleteStore(widget.turfId);
      if (mounted) {
        setState(() {
          _hasCachedTiles = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cached tiles deleted.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete cache: $e')),
        );
      }
    }
  }

  String _formatStorageEstimate(int tileCount) {
    // Average ~20KB per tile
    final bytes = tileCount * 20 * 1024;
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Offline Tiles: ${widget.turfName}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.turfName,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Download map tiles for offline use in the field. '
                      'Tiles are cached for zoom levels 12-18.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Estimation info
            if (_state == _DownloadState.estimating)
              const Center(child: CircularProgressIndicator()),

            if (_state == _DownloadState.ready ||
                _state == _DownloadState.downloading ||
                _state == _DownloadState.complete) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.grid_on),
                          const SizedBox(width: 8),
                          Text(
                            '$_estimatedTiles tiles',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Estimated storage: ${_formatStorageEstimate(_estimatedTiles)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Download progress
            if (_state == _DownloadState.downloading) ...[
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 8),
              Text(
                '$_downloadedTiles / $_totalTiles tiles (${(_progress * 100).toStringAsFixed(1)}%)',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _cancelDownload,
                icon: const Icon(Icons.cancel),
                label: const Text('Cancel Download'),
              ),
            ],

            // Complete state
            if (_state == _DownloadState.complete) ...[
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tiles cached for offline use.',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Error state
            if (_state == _DownloadState.error && _errorMessage != null) ...[
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_errorMessage!)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _initialize,
                child: const Text('Retry'),
              ),
            ],

            const Spacer(),

            // Action buttons
            if (_state == _DownloadState.ready) ...[
              FilledButton.icon(
                onPressed: _startDownload,
                icon: const Icon(Icons.download),
                label: const Text('Download Tiles'),
              ),
            ],

            if (_hasCachedTiles &&
                _state != _DownloadState.downloading) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _deleteCachedTiles,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete Cached Tiles'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
