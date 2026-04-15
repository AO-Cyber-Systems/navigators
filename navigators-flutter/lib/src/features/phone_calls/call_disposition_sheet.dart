import 'package:flutter/material.dart';

/// Five phone call disposition options.
enum CallDisposition {
  answered('answered', 'Answered', Icons.phone_in_talk, Colors.green),
  voicemail('voicemail', 'Voicemail', Icons.voicemail, Colors.blue),
  noAnswer('no_answer', 'No Answer', Icons.phone_missed, Colors.grey),
  refused('refused', 'Refused', Icons.phone_disabled, Colors.red),
  busy('busy', 'Busy', Icons.phone_locked, Colors.orange);

  const CallDisposition(this.value, this.label, this.icon, this.color);

  final String value;
  final String label;
  final IconData icon;
  final Color color;
}

/// Displays 5 tappable cards in a 2-column grid for quick call status recording.
///
/// Mirrors [DoorDispositionSheet] but with phone-specific dispositions.
/// Can be used inline within [PhoneCallScreen] or shown via a bottom sheet.
class CallDispositionSheet extends StatelessWidget {
  final ValueChanged<String> onSelected;

  const CallDispositionSheet({super.key, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What happened on the call?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: CallDisposition.values
                .map((d) => _CallDispositionCard(
                      disposition: d,
                      onTap: () => onSelected(d.value),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _CallDispositionCard extends StatelessWidget {
  final CallDisposition disposition;
  final VoidCallback onTap;

  const _CallDispositionCard({
    required this.disposition,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      identifier: 'phone-call-disposition-${disposition.value.replaceAll('_', '-')}',
      button: true,
      child: Material(
      color: disposition.color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: disposition.color.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                disposition.icon,
                size: 36,
                color: disposition.color,
              ),
              const SizedBox(height: 8),
              Text(
                disposition.label,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: disposition.color,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
