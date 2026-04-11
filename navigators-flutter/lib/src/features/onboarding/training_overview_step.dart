import 'package:flutter/material.dart';

/// Training overview step for onboarding wizard.
///
/// Shows a preview of available training materials to introduce
/// the user to the Training tab.
class TrainingOverviewStep extends StatelessWidget {
  final List<Map<String, dynamic>> materials;

  const TrainingOverviewStep({
    super.key,
    required this.materials,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Training Materials',
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Text(
          'Here are some training resources to help you get started. '
          'You can access these anytime from the Training tab.',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        if (materials.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.school_outlined,
                    size: 48,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Training materials will be available soon.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: materials.length > 3 ? 3 : materials.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final material = materials[index];
              return Card(
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
                    material['title'] as String? ?? 'Untitled',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    material['description'] as String? ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            },
          ),
        if (materials.length > 3) ...[
          const SizedBox(height: 8),
          Text(
            '+ ${materials.length - 3} more available in the Training tab',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ],
    );
  }
}
