import 'package:eden_ui_flutter/eden_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/database.dart';

/// Watches all active call scripts from the local database.
final _callScriptsProvider = StreamProvider<List<CallScript>>((ref) {
  final db = ref.read(databaseProvider);
  return db.callScriptDao.watchActiveCallScripts();
});

/// Admin screen for viewing and managing call scripts.
///
/// Displays call scripts synced from the server. Scripts are created and
/// edited on the server side; this screen provides a read-only view of
/// active scripts with content preview. Admin can view full script content
/// by tapping a script card.
///
/// Only accessible to Admin role users.
class CallScriptManagerScreen extends ConsumerWidget {
  const CallScriptManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scriptsAsync = ref.watch(_callScriptsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Call Scripts'),
      ),
      body: scriptsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: EdenEmptyState(
            title: 'Error loading scripts',
            description: error.toString(),
            icon: Icons.error_outline,
          ),
        ),
        data: (scripts) {
          if (scripts.isEmpty) {
            return const Center(
              child: EdenEmptyState(
                title: 'No call scripts',
                description:
                    'Call scripts are created on the server and synced to devices. No active scripts found.',
                icon: Icons.description_outlined,
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: scripts.length,
            itemBuilder: (context, index) {
              final script = scripts[index];
              return _CallScriptCard(
                script: script,
                onTap: () => _showScriptDetail(context, script),
              );
            },
          );
        },
      ),
    );
  }

  void _showScriptDetail(BuildContext context, CallScript script) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          final theme = Theme.of(context);
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Title
                Row(
                  children: [
                    Icon(Icons.description,
                        color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        script.title,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    EdenBadge(
                      label: 'v${script.version}',
                      variant: EdenBadgeVariant.info,
                      size: EdenBadgeSize.sm,
                    ),
                  ],
                ),
                const Divider(height: 24),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Text(
                      script.content,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        height: 1.6,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CallScriptCard extends StatelessWidget {
  final CallScript script;
  final VoidCallback onTap;

  const _CallScriptCard({
    required this.script,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = script.content.length > 120
        ? '${script.content.substring(0, 120)}...'
        : script.content;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      script.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  EdenBadge(
                    label: script.isActive ? 'Active' : 'Inactive',
                    variant: script.isActive
                        ? EdenBadgeVariant.success
                        : EdenBadgeVariant.neutral,
                    size: EdenBadgeSize.sm,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                preview,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color:
                      theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  EdenBadge(
                    label: 'v${script.version}',
                    variant: EdenBadgeVariant.info,
                    size: EdenBadgeSize.sm,
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right,
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
