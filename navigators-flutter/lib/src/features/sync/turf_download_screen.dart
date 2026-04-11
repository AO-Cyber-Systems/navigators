import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/database.dart';
import '../../database/daos/voter_dao.dart';
import '../../sync/pull_sync.dart';
import '../../sync/sync_status.dart';

/// Download status for a single turf.
class _TurfDownloadState {
  final String turfId;
  final String turfName;
  final int expectedVoterCount;
  final int downloadedVoters;
  final int downloadedContactLogs;
  final bool isDownloading;
  final bool isComplete;
  final String? error;

  const _TurfDownloadState({
    required this.turfId,
    required this.turfName,
    required this.expectedVoterCount,
    this.downloadedVoters = 0,
    this.downloadedContactLogs = 0,
    this.isDownloading = false,
    this.isComplete = false,
    this.error,
  });

  double get progress {
    if (expectedVoterCount <= 0) return 0.0;
    return (downloadedVoters / expectedVoterCount).clamp(0.0, 1.0);
  }
}

/// Screen for initial turf data download.
/// Shows assigned turfs with voter counts, download progress, and completion status.
/// Non-blocking: navigator can navigate away and download continues in background.
class TurfDownloadScreen extends ConsumerStatefulWidget {
  const TurfDownloadScreen({super.key});

  @override
  ConsumerState<TurfDownloadScreen> createState() =>
      _TurfDownloadScreenState();
}

class _TurfDownloadScreenState extends ConsumerState<TurfDownloadScreen> {
  List<_TurfDownloadState> _turfs = [];
  bool _isLoadingManifest = true;
  String? _manifestError;
  bool _isDownloadingAll = false;

  @override
  void initState() {
    super.initState();
    _loadManifest();
  }

  Future<void> _loadManifest() async {
    setState(() {
      _isLoadingManifest = true;
      _manifestError = null;
    });

    try {
      final syncClient = ref.read(syncClientProvider);
      final manifest = await syncClient.getSyncManifest();

      // Check local voter counts to determine which are already downloaded
      final db = ref.read(databaseProvider);
      final voterDao = VoterDao(db);

      final turfStates = <_TurfDownloadState>[];
      for (final turf in manifest.turfAssignments) {
        final localCount = await voterDao.countVotersInTurf(turf.turfId);
        turfStates.add(_TurfDownloadState(
          turfId: turf.turfId,
          turfName: turf.turfName,
          expectedVoterCount: turf.voterCount,
          downloadedVoters: localCount,
          isComplete: localCount > 0 && localCount >= turf.voterCount,
        ));
      }

      if (mounted) {
        setState(() {
          _turfs = turfStates;
          _isLoadingManifest = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingManifest = false;
          _manifestError = e.toString();
        });
      }
    }
  }

  Future<void> _downloadAll() async {
    if (_isDownloadingAll) return;
    setState(() => _isDownloadingAll = true);

    final syncClient = ref.read(syncClientProvider);
    final db = ref.read(databaseProvider);

    for (var i = 0; i < _turfs.length; i++) {
      final turf = _turfs[i];
      if (turf.isComplete) continue;

      setState(() {
        _turfs[i] = _TurfDownloadState(
          turfId: turf.turfId,
          turfName: turf.turfName,
          expectedVoterCount: turf.expectedVoterCount,
          isDownloading: true,
        );
      });

      try {
        // Pull voters for this turf
        final pulledVoters =
            await syncClient.pullAllVoters(db, [turf.turfId]);
        final pulledLogs =
            await syncClient.pullAllContactLogs(db, [turf.turfId]);

        if (mounted) {
          setState(() {
            _turfs[i] = _TurfDownloadState(
              turfId: turf.turfId,
              turfName: turf.turfName,
              expectedVoterCount: turf.expectedVoterCount,
              downloadedVoters: pulledVoters,
              downloadedContactLogs: pulledLogs,
              isComplete: true,
            );
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _turfs[i] = _TurfDownloadState(
              turfId: turf.turfId,
              turfName: turf.turfName,
              expectedVoterCount: turf.expectedVoterCount,
              error: e.toString(),
            );
          });
        }
      }
    }

    // Refresh last sync time after download
    ref.invalidate(lastSyncTimeProvider);

    if (mounted) {
      setState(() => _isDownloadingAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Download Turf Data')),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoadingManifest) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_manifestError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text('Failed to load turf assignments',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(_manifestError!,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _loadManifest,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_turfs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text('No turfs assigned'),
            SizedBox(height: 4),
            Text('Ask your admin to assign turfs to you.'),
          ],
        ),
      );
    }

    final allComplete = _turfs.every((t) => t.isComplete);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_turfs.length} assigned turfs',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              FilledButton.icon(
                onPressed: _isDownloadingAll || allComplete
                    ? null
                    : _downloadAll,
                icon: const Icon(Icons.download),
                label: Text(
                    allComplete ? 'All Downloaded' : 'Download All'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _turfs.length,
            itemBuilder: (context, index) =>
                _TurfDownloadCard(turf: _turfs[index]),
          ),
        ),
      ],
    );
  }
}

class _TurfDownloadCard extends StatelessWidget {
  final _TurfDownloadState turf;

  const _TurfDownloadCard({required this.turf});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  turf.isComplete
                      ? Icons.check_circle
                      : turf.isDownloading
                          ? Icons.downloading
                          : turf.error != null
                              ? Icons.error
                              : Icons.cloud_download,
                  color: turf.isComplete
                      ? Colors.green
                      : turf.error != null
                          ? Colors.red
                          : Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        turf.turfName,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        '${turf.expectedVoterCount} voters',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (turf.isComplete)
                  Text(
                    '${turf.downloadedVoters} downloaded',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.green,
                        ),
                  ),
              ],
            ),
            if (turf.isDownloading) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: turf.progress),
              const SizedBox(height: 4),
              Text(
                'Downloading: ${turf.downloadedVoters}/${turf.expectedVoterCount} voters',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (turf.error != null) ...[
              const SizedBox(height: 8),
              Text(
                turf.error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.red,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
