import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sync/push_sync.dart';
import '../../sync/sync_engine.dart';
import '../../sync/sync_status.dart';
import '../../database/database.dart';
import 'turf_download_screen.dart';

/// Full-screen sync details: connection status, pending ops, last sync time,
/// manual sync button, dead-letter operations, and turf download link.
class SyncProgressScreen extends ConsumerStatefulWidget {
  const SyncProgressScreen({super.key});

  @override
  ConsumerState<SyncProgressScreen> createState() =>
      _SyncProgressScreenState();
}

class _SyncProgressScreenState extends ConsumerState<SyncProgressScreen> {
  List<SyncOperation>? _deadLetterOps;
  bool _isLoadingDeadLetters = false;

  @override
  void initState() {
    super.initState();
    _loadDeadLetterOps();
  }

  Future<void> _loadDeadLetterOps() async {
    setState(() => _isLoadingDeadLetters = true);
    try {
      final pushSync = ref.read(pushSyncProvider);
      final ops = await pushSync.getDeadLetterOperations();
      if (mounted) {
        setState(() {
          _deadLetterOps = ops;
          _isLoadingDeadLetters = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingDeadLetters = false);
      }
    }
  }

  Future<void> _triggerManualSync() async {
    final engine = ref.read(syncEngineProvider);
    ref.read(isSyncingProvider.notifier).state = true;
    try {
      final result = await engine.runSyncCycle();
      if (result.hasErrors) {
        ref.read(lastSyncErrorProvider.notifier).state =
            result.errors.join('; ');
      } else {
        ref.read(lastSyncErrorProvider.notifier).state = null;
      }
      // Refresh last sync time
      ref.invalidate(lastSyncTimeProvider);
    } catch (e) {
      ref.read(lastSyncErrorProvider.notifier).state = e.toString();
    } finally {
      ref.read(isSyncingProvider.notifier).state = false;
      _loadDeadLetterOps();
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncStatus = ref.watch(syncStatusProvider);

    return Semantics(
      identifier: 'sync-progress-screen',
      explicitChildNodes: true,
      child: Scaffold(
        appBar: AppBar(title: const Text('Sync Status')),
        body: syncStatus.when(
          data: (status) => _buildContent(context, status),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, SyncStatus status) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Connection status card
        _StatusCard(
          icon: status.isOnline ? Icons.wifi : Icons.wifi_off,
          iconColor: status.isOnline ? Colors.green : Colors.red,
          title: status.isOnline ? 'Online' : 'Offline',
          subtitle: status.isOnline
              ? 'Connected to server'
              : 'Changes will sync when reconnected',
        ),
        const SizedBox(height: 12),

        // Sync state card
        _StatusCard(
          icon: status.isSyncing
              ? Icons.sync
              : status.isFullySynced
                  ? Icons.cloud_done
                  : Icons.cloud_upload,
          iconColor: status.isSyncing
              ? Theme.of(context).colorScheme.primary
              : status.isFullySynced
                  ? Colors.green
                  : Colors.orange,
          title: status.isSyncing
              ? 'Syncing...'
              : status.isFullySynced
                  ? 'Fully Synced'
                  : '${status.pendingOperations} Pending Operations',
          subtitle: _formatLastSync(status.lastSyncAt),
        ),
        const SizedBox(height: 12),

        // Error card (if any)
        if (status.lastError != null) ...[
          _StatusCard(
            icon: Icons.error_outline,
            iconColor: Colors.red,
            title: 'Last Sync Error',
            subtitle: status.lastError!,
          ),
          const SizedBox(height: 12),
        ],

        // Action buttons
        Row(
          children: [
            Expanded(
              child: Semantics(
                identifier: 'sync-now-btn',
                button: true,
                child: FilledButton.icon(
                  onPressed: status.isSyncing ? null : _triggerManualSync,
                  icon: const Icon(Icons.sync),
                  label: const Text('Sync Now'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                identifier: 'sync-download-turfs-btn',
                button: true,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const TurfDownloadScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('Download Turfs'),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Dead-letter operations
        Text(
          'Failed Operations',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (_isLoadingDeadLetters)
          const Center(child: CircularProgressIndicator())
        else if (_deadLetterOps == null || _deadLetterOps!.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No failed operations'),
            ),
          )
        else
          ...(_deadLetterOps!.map((op) => _DeadLetterCard(
                operation: op,
                onRetry: () async {
                  final syncDao = ref.read(databaseProvider).syncDao;
                  await syncDao.resetToPending([op.id]);
                  _loadDeadLetterOps();
                },
                onDismiss: () async {
                  final syncDao = ref.read(databaseProvider).syncDao;
                  await syncDao.markSynced([op.id]);
                  _loadDeadLetterOps();
                },
              ))),
      ],
    );
  }

  String _formatLastSync(DateTime? lastSyncAt) {
    if (lastSyncAt == null) return 'Never synced';
    final diff = DateTime.now().difference(lastSyncAt);
    if (diff.inMinutes < 1) return 'Last synced just now';
    if (diff.inMinutes < 60) return 'Last synced ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Last synced ${diff.inHours}h ago';
    return 'Last synced ${diff.inDays}d ago';
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _StatusCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: iconColor, size: 32),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
}

class _DeadLetterCard extends StatelessWidget {
  final SyncOperation operation;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  const _DeadLetterCard({
    required this.operation,
    required this.onRetry,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.error, color: Colors.red),
        title: Text('${operation.operationType} ${operation.entityType}'),
        subtitle: Text(
          'Entity: ${operation.entityId}\n'
          'Retries: ${operation.retryCount}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              identifier: 'sync-dead-letter-retry-${operation.id}',
              button: true,
              child: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: onRetry,
                tooltip: 'Retry',
              ),
            ),
            Semantics(
              identifier: 'sync-dead-letter-dismiss-${operation.id}',
              button: true,
              child: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: onDismiss,
                tooltip: 'Dismiss',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
