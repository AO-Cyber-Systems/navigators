import 'package:eden_ui_flutter/eden_ui.dart';
import 'package:flutter/material.dart';

import '../../services/import_service.dart';

/// Card widget displaying import job progress and status.
class ImportProgressCard extends StatefulWidget {
  final ImportJob job;

  const ImportProgressCard({super.key, required this.job});

  @override
  State<ImportProgressCard> createState() => _ImportProgressCardState();
}

class _ImportProgressCardState extends State<ImportProgressCard> {
  bool _errorsExpanded = false;

  EdenBadgeVariant _statusVariant(String status) {
    switch (status.toLowerCase()) {
      case 'complete':
        return EdenBadgeVariant.success;
      case 'failed':
        return EdenBadgeVariant.danger;
      case 'parsing':
      case 'staging':
      case 'merging':
      case 'geocoding':
        return EdenBadgeVariant.info;
      case 'pending':
        return EdenBadgeVariant.neutral;
      default:
        return EdenBadgeVariant.neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final job = widget.job;
    final errors = job.errorList;

    return EdenCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: filename + status
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.fileName,
                        style: theme.textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${job.sourceType.toUpperCase()} import',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                EdenBadge(
                  label: job.status,
                  variant: _statusVariant(job.status),
                  size: EdenBadgeSize.sm,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Progress bar
            if (job.isActive || job.isComplete) ...[
              EdenProgress(value: job.progress),
              const SizedBox(height: 8),
            ],

            // Row counts
            Row(
              children: [
                _CountChip('Total', job.totalRows, theme),
                const SizedBox(width: 12),
                _CountChip('Merged', job.mergedRows, theme),
                const SizedBox(width: 12),
                _CountChip('Skipped', job.skippedRows, theme),
                const SizedBox(width: 12),
                _CountChip('Errors', job.errorRows, theme,
                    isError: job.errorRows > 0),
              ],
            ),

            // Created timestamp
            const SizedBox(height: 8),
            Text(
              'Started: ${job.createdAt}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),

            // Error list (expandable)
            if (errors.isNotEmpty) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () => setState(() => _errorsExpanded = !_errorsExpanded),
                child: Row(
                  children: [
                    Icon(
                      _errorsExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 16,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${errors.length} error(s)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
              if (_errorsExpanded) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: errors
                        .take(20) // Show max 20 errors
                        .map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                e,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  final int count;
  final ThemeData theme;
  final bool isError;

  const _CountChip(this.label, this.count, this.theme, {this.isError = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$count',
          style: theme.textTheme.titleSmall?.copyWith(
            color: isError && count > 0 ? theme.colorScheme.error : null,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
