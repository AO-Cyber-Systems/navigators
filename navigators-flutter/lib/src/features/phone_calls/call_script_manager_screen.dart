import 'package:eden_platform_flutter/eden_platform.dart';
import 'package:eden_ui_flutter/eden_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/database.dart';
import 'call_script_editor_screen.dart';

/// Call script management + read-only view.
///
/// Admin role: sees list, FAB to create, tap-to-edit each script.
/// Non-admin role: sees read-only list, no FAB, detail bottom sheet on tap.
///
/// List data always comes from the local Drift cache (watchActiveCallScripts)
/// which is populated by SyncService.PullCallScripts. Mutations flow through
/// CallScriptService RPCs; a sync cycle is kicked after save so the cache
/// refreshes quickly.
class CallScriptManagerScreen extends ConsumerWidget {
  const CallScriptManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final isAdmin = auth.role?.toLowerCase() == 'admin';
    final db = ref.read(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isAdmin ? 'Manage Call Scripts' : 'Call Scripts'),
      ),
      body: StreamBuilder<List<CallScript>>(
        stream: db.callScriptDao.watchActiveCallScripts(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: EdenEmptyState(
                title: 'Error loading scripts',
                description: snapshot.error.toString(),
                icon: Icons.error_outline,
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final scripts = snapshot.data!;
          if (scripts.isEmpty) {
            return Center(
              child: EdenEmptyState(
                title: 'No call scripts',
                description: isAdmin
                    ? 'Tap + to create your first call script.'
                    : 'No active call scripts. Check back after your next sync.',
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
                trailing: isAdmin
                    ? const Icon(Icons.chevron_right)
                    : null,
                onTap: isAdmin
                    ? () => Navigator.of(context).push(
                          MaterialPageRoute<bool>(
                            builder: (_) => CallScriptEditorScreen(
                              existing: script,
                            ),
                          ),
                        )
                    : () => _showScriptDetail(context, script),
              );
            },
          );
        },
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<bool>(
                  builder: (_) => const CallScriptEditorScreen(),
                ),
              ),
              tooltip: 'New call script',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  void _showScriptDetail(BuildContext context, CallScript script) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
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
                Row(
                  children: [
                    Icon(Icons.description, color: theme.colorScheme.primary),
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
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Text(
                      script.content,
                      style:
                          theme.textTheme.bodyLarge?.copyWith(height: 1.6),
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
  final Widget? trailing;

  const _CallScriptCard({
    required this.script,
    required this.onTap,
    this.trailing,
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
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
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
                  if (trailing != null)
                    IconTheme(
                      data: IconThemeData(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.4),
                      ),
                      child: trailing!,
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
