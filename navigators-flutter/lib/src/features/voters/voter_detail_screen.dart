import 'package:eden_platform_flutter/eden_platform.dart';
import 'package:eden_ui_flutter/eden_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/voter_service.dart';
import '../phone_calls/phone_call_screen.dart';
import 'contact_timeline_widget.dart';
import 'suppress_voter_dialog.dart';
import 'voter_notes_tab.dart';

/// Full voter profile display screen with tabbed layout.
///
/// Three tabs:
/// - **Profile**: existing voter info (personal, address, registration, districts, voting history, tags)
/// - **Timeline**: unified contact timeline (door knocks, notes, survey responses)
/// - **Notes**: voter notes with visibility badges and add-note capability
class VoterDetailScreen extends ConsumerWidget {
  final String voterId;

  /// Optional turf ID for context (enables add-note on Notes tab).
  final String? turfId;

  const VoterDetailScreen({
    super.key,
    required this.voterId,
    this.turfId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voterAsync = ref.watch(voterDetailProvider(voterId));

    return voterAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Voter Profile')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Voter Profile')),
        body: Center(
          child: EdenEmptyState(
            title: 'Error loading voter',
            description: error.toString(),
            icon: Icons.error_outline,
          ),
        ),
      ),
      data: (voter) => DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: Text(voter.fullName),
            actions: [
              if (voter.phone.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.phone),
                  tooltip: 'Call voter',
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PhoneCallScreen(
                          voterId: voter.id,
                          voterName: voter.fullName,
                          voterPhone: voter.phone,
                          turfId: turfId ?? '',
                        ),
                      ),
                    );
                  },
                ),
            ],
            bottom: const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.person), text: 'Profile'),
                Tab(icon: Icon(Icons.timeline), text: 'Timeline'),
                Tab(icon: Icon(Icons.note), text: 'Notes'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _VoterProfileBody(voter: voter),
              ContactTimelineWidget(voterId: voterId),
              VoterNotesTab(voterId: voterId, turfId: turfId),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoterProfileBody extends ConsumerWidget {
  final Voter voter;

  const _VoterProfileBody({required this.voter});

  Future<void> _handleRemoveSuppression(
      BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from suppression list?'),
        content: Text(
            '${voter.fullName} will be removed from the suppression list and eligible for outreach again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref
          .read(voterServiceProvider)
          .removeFromSuppressionList(voter.id);
      ref.invalidate(voterDetailProvider(voter.id));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removed from suppression list')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove: $e')),
      );
    }
  }

  Future<void> _handleAddSuppression(
      BuildContext context, WidgetRef ref) async {
    final ok = await SuppressVoterDialog.show(
      context,
      voterId: voter.id,
      voterName: voter.fullName,
      isAlreadySuppressed: voter.isSuppressed,
    );
    if (ok) ref.invalidate(voterDetailProvider(voter.id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final auth = ref.watch(authProvider);
    final isAdmin = auth.role?.toLowerCase() == 'admin';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(context, theme),
          const SizedBox(height: 16),

          // Suppression warning
          if (voter.isSuppressed) ...[
            EdenAlert(
              title: 'Voter is suppressed',
              message:
                  'This voter is on the suppression list and will be excluded from outreach operations.',
              variant: EdenAlertVariant.danger,
            ),
            const SizedBox(height: 16),
          ],

          // Admin suppression actions
          if (isAdmin) ...[
            if (voter.isSuppressed)
              EdenButton(
                label: 'Remove from suppression list',
                icon: Icons.person_remove_outlined,
                onPressed: () => _handleRemoveSuppression(context, ref),
              )
            else
              EdenButton(
                label: 'Add to suppression list',
                icon: Icons.person_off_outlined,
                onPressed: () => _handleAddSuppression(context, ref),
              ),
            const SizedBox(height: 16),
          ],

          // Personal info
          _buildSection(theme, 'Personal Information', [
            _InfoRow('Voter ID', voter.sourceVoterId),
            _InfoRow('Year of Birth', voter.yearOfBirth > 0 ? '${voter.yearOfBirth}' : 'N/A'),
            _InfoRow('Source', voter.source),
          ]),

          // Residence address
          _buildSection(theme, 'Residence Address', [
            _InfoRow('Address', voter.residenceAddress),
          ]),

          // Mailing address (if different)
          if (voter.mailingAddress.isNotEmpty &&
              voter.mailingAddress != voter.residenceAddress) ...[
            _buildSection(theme, 'Mailing Address', [
              _InfoRow('Address', voter.mailingAddress),
            ]),
          ],

          // Registration
          _buildSection(theme, 'Registration', [
            _InfoRow('Registration Date', voter.registrationDate),
            _InfoRow('Party', _partyFullName(voter.party)),
            _InfoRow('Status', voter.status),
          ]),

          // Districts
          _buildSection(theme, 'Districts', [
            _InfoRow('Congressional', voter.congressionalDistrict),
            _InfoRow('State Senate', voter.stateSenateDistrict),
            _InfoRow('State House', voter.stateHouseDistrict),
            _InfoRow('County', voter.county),
            _InfoRow('Municipality', voter.municipality),
            if (voter.ward.isNotEmpty) _InfoRow('Ward', voter.ward),
            if (voter.precinct.isNotEmpty) _InfoRow('Precinct', voter.precinct),
          ]),

          // Voting history
          _buildVotingHistory(theme),

          // Tags
          _buildTagsSection(theme),

          // Geocode status
          _buildSection(theme, 'Geocoding', [
            _InfoRow('Status', voter.geocodeStatus),
          ]),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: _partyColor(voter.party),
          child: Text(
            voter.party.isNotEmpty ? voter.party : '?',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(voter.fullName, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Row(
                children: [
                  EdenBadge(
                    label: _partyFullName(voter.party),
                    variant: EdenBadgeVariant.info,
                    size: EdenBadgeSize.sm,
                  ),
                  const SizedBox(width: 8),
                  EdenBadge(
                    label: voter.status,
                    variant: voter.status.toLowerCase() == 'active'
                        ? EdenBadgeVariant.success
                        : EdenBadgeVariant.neutral,
                    size: EdenBadgeSize.sm,
                  ),
                  if (voter.isSuppressed) ...[
                    const SizedBox(width: 8),
                    const EdenBadge(
                      label: 'Suppressed',
                      variant: EdenBadgeVariant.danger,
                      size: EdenBadgeSize.sm,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSection(ThemeData theme, String title, List<_InfoRow> rows) {
    final filtered = rows.where((r) => r.value.isNotEmpty).toList();
    if (filtered.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ...filtered.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 140,
                      child: Text(
                        r.label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    Expanded(child: Text(r.value, style: theme.textTheme.bodyMedium)),
                  ],
                ),
              )),
          const Divider(),
        ],
      ),
    );
  }

  Widget _buildVotingHistory(ThemeData theme) {
    final records = voter.votingRecords;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Voting History (${records.length} elections)',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (records.isEmpty)
            Text('No voting history available.',
                style: theme.textTheme.bodySmall)
          else
            ...records.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.how_to_vote, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          r.election.isNotEmpty ? r.election : r.date,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      if (r.method.isNotEmpty)
                        EdenBadge(
                          label: r.method,
                          variant: EdenBadgeVariant.neutral,
                          size: EdenBadgeSize.sm,
                        ),
                    ],
                  ),
                )),
          const Divider(),
        ],
      ),
    );
  }

  Widget _buildTagsSection(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tags', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (voter.tags.isEmpty)
            Text('No tags assigned.', style: theme.textTheme.bodySmall)
          else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: voter.tags
                  .map((t) => EdenBadge(
                        label: t.name,
                        variant: EdenBadgeVariant.primary,
                        size: EdenBadgeSize.sm,
                      ))
                  .toList(),
            ),
          const Divider(),
        ],
      ),
    );
  }

  static String _partyFullName(String code) {
    switch (code.toUpperCase()) {
      case 'D':
        return 'Democrat';
      case 'R':
        return 'Republican';
      case 'G':
        return 'Green';
      case 'L':
        return 'Libertarian';
      case 'NL':
        return 'No Party';
      default:
        return code;
    }
  }

  static Color _partyColor(String party) {
    switch (party.toUpperCase()) {
      case 'D':
        return Colors.blue;
      case 'R':
        return Colors.red;
      case 'G':
        return Colors.green;
      case 'L':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }
}

class _InfoRow {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);
}
