import 'package:eden_ui_flutter/eden_ui.dart';
import 'package:flutter/material.dart';

import '../../database/database.dart';

/// Data class for voter context used in script variable interpolation.
class VoterScriptContext {
  final String firstName;
  final String lastName;
  final String party;
  final String address;

  const VoterScriptContext({
    required this.firstName,
    required this.lastName,
    required this.party,
    required this.address,
  });
}

/// Displays a call script with voter variable interpolation.
///
/// Supports {{voter.firstName}}, {{voter.lastName}}, {{voter.party}},
/// and {{voter.address}} template variables. Renders as a Card with the
/// script title as header and interpolated content as body text.
///
/// If [script] is null, shows an [EdenEmptyState] with a "No script available"
/// message and still allows the caller to proceed to disposition.
class CallScriptWidget extends StatelessWidget {
  /// The call script to display. If null, shows empty state.
  final CallScript? script;

  /// Voter data for variable interpolation.
  final VoterScriptContext voterContext;

  const CallScriptWidget({
    super.key,
    required this.script,
    required this.voterContext,
  });

  @override
  Widget build(BuildContext context) {
    if (script == null) {
      return const EdenEmptyState(
        title: 'No script available',
        description:
            'No active call script is available. You can still proceed with the call.',
        icon: Icons.description_outlined,
      );
    }

    final interpolated = _interpolate(script!.content);
    final theme = Theme.of(context);

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    script!.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              interpolated,
              style: theme.textTheme.bodyLarge?.copyWith(
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Replace {{voter.*}} template variables with voter context values.
  String _interpolate(String content) {
    return content
        .replaceAll('{{voter.firstName}}', voterContext.firstName)
        .replaceAll('{{voter.lastName}}', voterContext.lastName)
        .replaceAll('{{voter.party}}', voterContext.party)
        .replaceAll('{{voter.address}}', voterContext.address);
  }
}
