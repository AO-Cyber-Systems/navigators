import 'package:flutter/material.dart';

/// Four door status options for the door knock disposition step.
enum DoorDisposition {
  notHome('not_home', 'Not Home', Icons.home_outlined, Colors.grey),
  answered('answered', 'Answered', Icons.door_front_door, Colors.green),
  refused('refused', 'Refused', Icons.do_not_disturb, Colors.red),
  moved('moved', 'Moved', Icons.moving, Colors.orange);

  const DoorDisposition(this.value, this.label, this.icon, this.color);

  final String value;
  final String label;
  final IconData icon;
  final Color color;
}

/// Displays 4 large tappable cards in a 2x2 grid for quick door status recording.
///
/// Can be used inline within [DoorKnockScreen] or shown via [EdenBottomSheet.show].
class DoorDispositionSheet extends StatelessWidget {
  final ValueChanged<String> onSelected;

  const DoorDispositionSheet({super.key, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What happened at the door?',
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
            children: DoorDisposition.values
                .map((d) => _DispositionCard(
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

class _DispositionCard extends StatelessWidget {
  final DoorDisposition disposition;
  final VoidCallback onTap;

  const _DispositionCard({
    required this.disposition,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      identifier: 'door-knock-disposition-${disposition.value.replaceAll('_', '-')}',
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
