import 'package:flutter/material.dart';

/// Legal acknowledgment step for onboarding wizard.
///
/// Displays Maine Title 21-A Section 196-A voter data usage agreement
/// with a checkbox for user acknowledgment.
class LegalAcknowledgmentStep extends StatelessWidget {
  final bool acknowledged;
  final ValueChanged<bool> onChanged;

  const LegalAcknowledgmentStep({
    super.key,
    required this.acknowledged,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome to Navigators',
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Text(
          'Before you begin, please review and acknowledge the following '
          'legal requirements regarding voter data usage.',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.gavel,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Maine Title 21-A, Section 196-A',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Voter data may only be used for political purposes. '
                'You agree not to use voter information for commercial '
                'solicitation or any purpose prohibited by Maine law.\n\n'
                'Specifically, you acknowledge that:\n\n'
                '1. Voter registration data is provided solely for use in '
                'connection with political campaigns, voter registration, '
                'and election-related activities.\n\n'
                '2. You will not use this data for commercial purposes, '
                'including but not limited to marketing, advertising, or '
                'solicitation of products or services.\n\n'
                '3. Violation of these terms may result in civil and '
                'criminal penalties under Maine law.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Version: 21-A-196A-v1',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        CheckboxListTile(
          value: acknowledged,
          onChanged: (value) => onChanged(value ?? false),
          title: const Text(
            'I acknowledge that I have read and agree to the voter data '
            'usage terms described above.',
          ),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }
}
