import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sync/sync_status.dart';
import 'sync_progress_screen.dart';

/// Compact app bar widget showing sync status with icon + badge.
///
/// Icon states:
/// - Green check: fully synced, online
/// - Orange sync icon with badge count: has pending operations
/// - Red cloud-off: offline
/// - Spinning sync icon: currently syncing
///
/// Tap opens SyncProgressScreen for full details.
class SyncStatusWidget extends ConsumerWidget {
  const SyncStatusWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatus = ref.watch(syncStatusProvider);

    return syncStatus.when(
      data: (status) => _buildIcon(context, status),
      loading: () => const SizedBox.shrink(),
      error: (_, _) => IconButton(
        icon: const Icon(Icons.sync_problem, color: Colors.red),
        onPressed: () => _openProgressScreen(context),
        tooltip: 'Sync error',
      ),
    );
  }

  Widget _buildIcon(BuildContext context, SyncStatus status) {
    Widget icon;
    String tooltip;

    if (status.isSyncing) {
      // Spinning sync icon
      icon = const _SpinningSyncIcon();
      tooltip = 'Syncing...';
    } else if (!status.isOnline) {
      // Red cloud-off icon
      icon = const Icon(Icons.cloud_off, color: Colors.red);
      tooltip = 'Offline';
    } else if (status.hasPending) {
      // Orange sync icon with badge count
      icon = Badge(
        label: Text(
          '${status.pendingOperations}',
          style: const TextStyle(fontSize: 10),
        ),
        child: const Icon(Icons.sync, color: Colors.orange),
      );
      tooltip = '${status.pendingOperations} pending';
    } else if (status.lastError != null) {
      icon = const Icon(Icons.sync_problem, color: Colors.orange);
      tooltip = 'Sync error';
    } else {
      // Green check: fully synced, online
      icon = const Icon(Icons.cloud_done, color: Colors.green);
      tooltip = _formatLastSync(status.lastSyncAt);
    }

    return IconButton(
      icon: icon,
      onPressed: () => _openProgressScreen(context),
      tooltip: tooltip,
    );
  }

  String _formatLastSync(DateTime? lastSyncAt) {
    if (lastSyncAt == null) return 'Never synced';
    final diff = DateTime.now().difference(lastSyncAt);
    if (diff.inMinutes < 1) return 'Just synced';
    if (diff.inMinutes < 60) return 'Synced ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Synced ${diff.inHours}h ago';
    return 'Synced ${diff.inDays}d ago';
  }

  void _openProgressScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SyncProgressScreen()),
    );
  }
}

/// Animated spinning sync icon for the "syncing" state.
class _SpinningSyncIcon extends StatefulWidget {
  const _SpinningSyncIcon();

  @override
  State<_SpinningSyncIcon> createState() => _SpinningSyncIconState();
}

class _SpinningSyncIconState extends State<_SpinningSyncIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Icon(
        Icons.sync,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
