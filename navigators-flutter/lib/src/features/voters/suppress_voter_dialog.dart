import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/voter_service.dart';

/// Dialog to add a voter to the suppression list.
///
/// Collects a reason (dropdown) and optional note. If reason is `other`, the
/// note becomes required. Submits to `VoterService.addToSuppressionList` and
/// returns `true` on success.
class SuppressVoterDialog extends ConsumerStatefulWidget {
  final String voterId;
  final String voterName;
  final bool isAlreadySuppressed;

  const SuppressVoterDialog({
    super.key,
    required this.voterId,
    required this.voterName,
    this.isAlreadySuppressed = false,
  });

  static Future<bool> show(
    BuildContext context, {
    required String voterId,
    required String voterName,
    required bool isAlreadySuppressed,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => SuppressVoterDialog(
        voterId: voterId,
        voterName: voterName,
        isAlreadySuppressed: isAlreadySuppressed,
      ),
    );
    return result ?? false;
  }

  @override
  ConsumerState<SuppressVoterDialog> createState() =>
      _SuppressVoterDialogState();
}

class _SuppressVoterDialogState extends ConsumerState<SuppressVoterDialog> {
  static const _reasonOptions = <({String value, String label})>[
    (value: 'opt_out', label: 'Opt-out'),
    (value: 'deceased', label: 'Deceased'),
    (value: 'do_not_contact', label: 'Do not contact'),
    (value: 'other', label: 'Other'),
  ];

  String _reason = 'opt_out';
  final TextEditingController _notesCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final notes = _notesCtrl.text.trim();
    if (_reason == 'other' && notes.isEmpty) {
      setState(() => _error = 'A note is required when selecting "Other".');
      return;
    }
    final combined = notes.isEmpty ? _reason : '$_reason: $notes';

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref
          .read(voterServiceProvider)
          .addToSuppressionList(widget.voterId, combined);
      if (!mounted) return;
      final msg = widget.isAlreadySuppressed
          ? 'Suppression reason updated'
          : 'Added to suppression list';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'suppress-voter-dialog',
      explicitChildNodes: true,
      child: AlertDialog(
        title: Text(widget.isAlreadySuppressed
            ? 'Update suppression reason'
            : 'Suppress voter'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.voterName,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 16),
              Semantics(
                identifier: 'suppress-voter-dialog-reason',
                child: DropdownButtonFormField<String>(
                  initialValue: _reason,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    border: OutlineInputBorder(),
                  ),
                  items: _reasonOptions
                      .map((o) => DropdownMenuItem<String>(
                            value: o.value,
                            child: Text(o.label),
                          ))
                      .toList(),
                  onChanged: _submitting
                      ? null
                      : (v) {
                          if (v != null) setState(() => _reason = v);
                        },
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                identifier: 'suppress-voter-dialog-note',
                textField: true,
                child: TextField(
                  controller: _notesCtrl,
                  enabled: !_submitting,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: _reason == 'other'
                        ? 'Note (required)'
                        : 'Note (optional)',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
        actions: [
          Semantics(
            identifier: 'suppress-voter-dialog-cancel',
            button: true,
            child: TextButton(
              onPressed:
                  _submitting ? null : () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
          ),
          Semantics(
            identifier: 'suppress-voter-dialog-submit',
            button: true,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              child: Text(_submitting
                  ? 'Saving...'
                  : (widget.isAlreadySuppressed ? 'Update' : 'Suppress')),
            ),
          ),
        ],
      ),
    );
  }
}
