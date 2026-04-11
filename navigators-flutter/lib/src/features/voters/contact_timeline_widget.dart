import 'package:eden_ui_flutter/eden_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../services/timeline_service.dart';
import 'sentiment_history_widget.dart';

/// Unified contact timeline for a single voter.
///
/// Merges contact logs, voter notes, and survey responses into a single
/// chronological list using [voterTimelineProvider]. Header shows door knock
/// count and a compact sentiment history.
class ContactTimelineWidget extends ConsumerWidget {
  final String voterId;

  const ContactTimelineWidget({super.key, required this.voterId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timelineAsync = ref.watch(voterTimelineProvider(voterId));
    final knockCountAsync = ref.watch(doorKnockCountProvider(voterId));
    final sentimentAsync = ref.watch(sentimentHistoryProvider(voterId));

    return timelineAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: EdenEmptyState(
          title: 'Error loading timeline',
          description: error.toString(),
          icon: Icons.error_outline,
        ),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return const Center(
            child: EdenEmptyState(
              title: 'No interactions yet',
              description:
                  'Door knocks, notes, and survey responses will appear here.',
              icon: Icons.timeline,
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          // +1 for header
          itemCount: entries.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _buildHeader(context, ref, knockCountAsync, sentimentAsync);
            }
            return _buildTimelineEntry(context, entries[index - 1]);
          },
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<int> knockCountAsync,
    AsyncValue<List<SentimentPoint>> sentimentAsync,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Door knock count badge
          Row(
            children: [
              const Icon(Icons.door_front_door, size: 18),
              const SizedBox(width: 6),
              knockCountAsync.when(
                data: (count) => EdenBadge(
                  label: '$count door knock${count == 1 ? '' : 's'}',
                  variant: EdenBadgeVariant.info,
                  size: EdenBadgeSize.sm,
                ),
                loading: () => const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (e, s) => const EdenBadge(
                  label: '-- door knocks',
                  variant: EdenBadgeVariant.neutral,
                  size: EdenBadgeSize.sm,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Sentiment history dots
          sentimentAsync.when(
            data: (points) => SentimentHistoryWidget(points: points),
            loading: () => const SizedBox.shrink(),
            error: (e, s) => const SizedBox.shrink(),
          ),

          const SizedBox(height: 8),
          const Divider(),
        ],
      ),
    );
  }

  Widget _buildTimelineEntry(BuildContext context, TimelineEntry entry) {
    final theme = Theme.of(context);
    final timeFormat = DateFormat('MMM d, yyyy h:mm a');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon column with connecting line
          Column(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: entry.iconColor.withValues(alpha: 0.15),
                child: Icon(entry.icon, size: 18, color: entry.iconColor),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.summary,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  timeFormat.format(entry.timestamp),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
