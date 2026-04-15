import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/voter_service.dart';

/// Expandable filter panel for voter list filtering.
class VoterFilterPanel extends ConsumerStatefulWidget {
  const VoterFilterPanel({super.key});

  @override
  ConsumerState<VoterFilterPanel> createState() => _VoterFilterPanelState();
}

class _VoterFilterPanelState extends ConsumerState<VoterFilterPanel> {
  bool _expanded = false;
  String? _party;
  String? _status;
  final _congressionalCtrl = TextEditingController();
  final _senateCtrl = TextEditingController();
  final _houseCtrl = TextEditingController();
  final _municipalityCtrl = TextEditingController();
  final _countyCtrl = TextEditingController();
  int? _minVoteCount;

  static const _parties = [
    ('All', null),
    ('Democrat', 'D'),
    ('Green', 'G'),
    ('Libertarian', 'L'),
    ('No Party', 'NL'),
    ('Republican', 'R'),
  ];

  static const _statuses = [
    ('All', null),
    ('Active', 'active'),
    ('Inactive', 'inactive'),
  ];

  @override
  void dispose() {
    _congressionalCtrl.dispose();
    _senateCtrl.dispose();
    _houseCtrl.dispose();
    _municipalityCtrl.dispose();
    _countyCtrl.dispose();
    super.dispose();
  }

  void _applyFilters() {
    final filters = VoterFilters(
      party: _party,
      status: _status,
      congressionalDistrict:
          _congressionalCtrl.text.isNotEmpty ? _congressionalCtrl.text : null,
      stateSenateDistrict: _senateCtrl.text.isNotEmpty ? _senateCtrl.text : null,
      stateHouseDistrict: _houseCtrl.text.isNotEmpty ? _houseCtrl.text : null,
      municipality:
          _municipalityCtrl.text.isNotEmpty ? _municipalityCtrl.text : null,
      county: _countyCtrl.text.isNotEmpty ? _countyCtrl.text : null,
      minVoteCount: _minVoteCount,
    );
    ref.read(voterListProvider.notifier).loadVoters(filters: filters);
  }

  void _clearFilters() {
    setState(() {
      _party = null;
      _status = null;
      _congressionalCtrl.clear();
      _senateCtrl.clear();
      _houseCtrl.clear();
      _municipalityCtrl.clear();
      _countyCtrl.clear();
      _minVoteCount = null;
    });
    ref.read(voterListProvider.notifier).loadVoters(filters: const VoterFilters());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Semantics(
          identifier: 'voter-filter-toggle',
          button: true,
          child: InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  _expanded ? Icons.filter_list_off : Icons.filter_list,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text('Filters', style: theme.textTheme.titleSmall),
                const Spacer(),
                Icon(
                  _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 20,
                ),
              ],
            ),
          ),
          ),
        ),
        if (_expanded) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Party dropdown
                Semantics(
                  identifier: 'voter-filter-party',
                  child: DropdownButtonFormField<String?>(
                    initialValue: _party,
                    decoration: const InputDecoration(
                      labelText: 'Party',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: _parties
                        .map((p) =>
                            DropdownMenuItem(value: p.$2, child: Text(p.$1)))
                        .toList(),
                    onChanged: (v) => setState(() => _party = v),
                  ),
                ),
                const SizedBox(height: 8),
                // Status dropdown
                Semantics(
                  identifier: 'voter-filter-status',
                  child: DropdownButtonFormField<String?>(
                    initialValue: _status,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: _statuses
                        .map((s) =>
                            DropdownMenuItem(value: s.$2, child: Text(s.$1)))
                        .toList(),
                    onChanged: (v) => setState(() => _status = v),
                  ),
                ),
                const SizedBox(height: 8),
                // District fields
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        identifier: 'voter-filter-congressional',
                        textField: true,
                        child: TextField(
                          controller: _congressionalCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Cong. District',
                            isDense: true,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Semantics(
                        identifier: 'voter-filter-senate',
                        textField: true,
                        child: TextField(
                          controller: _senateCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Senate Dist.',
                            isDense: true,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Semantics(
                        identifier: 'voter-filter-house',
                        textField: true,
                        child: TextField(
                          controller: _houseCtrl,
                          decoration: const InputDecoration(
                            labelText: 'House Dist.',
                            isDense: true,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        identifier: 'voter-filter-municipality',
                        textField: true,
                        child: TextField(
                          controller: _municipalityCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Municipality',
                            isDense: true,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Semantics(
                        identifier: 'voter-filter-county',
                        textField: true,
                        child: TextField(
                          controller: _countyCtrl,
                          decoration: const InputDecoration(
                            labelText: 'County',
                            isDense: true,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Min vote count
                Row(
                  children: [
                    Text('Min Votes: ${_minVoteCount ?? 0}',
                        style: theme.textTheme.bodySmall),
                    Expanded(
                      child: Semantics(
                        identifier: 'voter-filter-min-votes-slider',
                        slider: true,
                        child: Slider(
                          value: (_minVoteCount ?? 0).toDouble(),
                          min: 0,
                          max: 20,
                          divisions: 20,
                          onChanged: (v) =>
                              setState(() => _minVoteCount = v.round()),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Semantics(
                      identifier: 'voter-filter-clear-btn',
                      button: true,
                      child: TextButton(
                        onPressed: _clearFilters,
                        child: const Text('Clear'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Semantics(
                      identifier: 'voter-filter-apply-btn',
                      button: true,
                      child: FilledButton(
                        onPressed: _applyFilters,
                        child: const Text('Apply'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
