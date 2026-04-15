import 'package:eden_platform_flutter/eden_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/database.dart';
import '../../services/volunteer_service.dart';
import '../../sync/sync_engine.dart';
import 'training_detail_screen.dart';
import 'training_upload_screen.dart';

/// Training materials list screen.
///
/// Reads from local Drift database (synced from server).
/// Displays published training materials sorted by sort_order.
/// Tap to open detail screen with markdown viewer.
///
/// Admins (RoleLevel >= 60: admin / super_navigator / manager) additionally
/// see a FAB to upload new materials and a popup menu on each row with
/// edit/delete actions. Navigators see the unchanged read-only list.
class TrainingListScreen extends ConsumerWidget {
  const TrainingListScreen({super.key});

  static bool canManage(String? role) {
    if (role == null) return false;
    final lower = role.toLowerCase();
    return lower == 'admin' || lower == 'manager' || lower == 'super_navigator';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final auth = ref.watch(authProvider);
    final isAdmin = canManage(auth.role);

    NavigatorsDatabase db;
    try {
      db = ref.read(databaseProvider);
    } catch (_) {
      return Scaffold(
        appBar: AppBar(title: const Text('Training')),
        body: const Center(child: Text('Database not initialized')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Training Materials'),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () async {
                final uploaded = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => const TrainingUploadScreen(),
                  ),
                );
                if (uploaded == true) {
                  // Best-effort sync so the new row appears in the list.
                  try {
                    await SyncEngine.instance?.runSyncCycle();
                  } catch (_) {}
                }
              },
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload'),
            )
          : null,
      body: StreamBuilder<List<TrainingMaterial>>(
        stream: db.trainingDao.watchPublishedMaterials(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final materials = snapshot.data ?? [];
          if (materials.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.school_outlined,
                    size: 64,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No training materials available',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: materials.length,
            itemBuilder: (context, index) {
              final material = materials[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        theme.colorScheme.primary.withValues(alpha: 0.1),
                    child: Icon(
                      Icons.article_outlined,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  title: Text(
                    material.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: material.description.isNotEmpty
                      ? Text(
                          material.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                  trailing: isAdmin
                      ? _AdminActionsMenu(material: material)
                      : const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TrainingDetailScreen(
                          materialId: material.id,
                          title: material.title,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Popup menu shown only to admins on each training row. Provides edit + delete.
class _AdminActionsMenu extends ConsumerWidget {
  final TrainingMaterial material;

  const _AdminActionsMenu({required this.material});

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => _EditTrainingDialog(material: material),
    );
    if (updated == true) {
      try {
        await SyncEngine.instance?.runSyncCycle();
      } catch (_) {}
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete training material?'),
        content: Text('"${material.title}" will be removed from navigators.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(volunteerServiceProvider).deleteTrainingMaterial(material.id);
      try {
        await SyncEngine.instance?.runSyncCycle();
      } catch (_) {}
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deleted')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      onSelected: (action) {
        switch (action) {
          case 'edit':
            _edit(context, ref);
            break;
          case 'delete':
            _delete(context, ref);
            break;
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'edit', child: Text('Edit')),
        PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );
  }
}

class _EditTrainingDialog extends ConsumerStatefulWidget {
  final TrainingMaterial material;
  const _EditTrainingDialog({required this.material});

  @override
  ConsumerState<_EditTrainingDialog> createState() =>
      _EditTrainingDialogState();
}

class _EditTrainingDialogState extends ConsumerState<_EditTrainingDialog> {
  late final TextEditingController _titleCtl;
  late final TextEditingController _descCtl;
  late final TextEditingController _sortOrderCtl;
  late bool _isPublished;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _titleCtl = TextEditingController(text: widget.material.title);
    _descCtl = TextEditingController(text: widget.material.description);
    _sortOrderCtl =
        TextEditingController(text: widget.material.sortOrder.toString());
    _isPublished = widget.material.isPublished;
  }

  @override
  void dispose() {
    _titleCtl.dispose();
    _descCtl.dispose();
    _sortOrderCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleCtl.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Title is required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(volunteerServiceProvider).updateTrainingMaterial(
            id: widget.material.id,
            title: title,
            description: _descCtl.text.trim(),
            sortOrder: int.tryParse(_sortOrderCtl.text.trim()) ?? 0,
            isPublished: _isPublished,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit training material'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleCtl,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descCtl,
              decoration: const InputDecoration(labelText: 'Description'),
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _sortOrderCtl,
              decoration: const InputDecoration(labelText: 'Sort order'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Published'),
              value: _isPublished,
              onChanged: (v) => setState(() => _isPublished = v),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : 'Save'),
        ),
      ],
    );
  }
}
