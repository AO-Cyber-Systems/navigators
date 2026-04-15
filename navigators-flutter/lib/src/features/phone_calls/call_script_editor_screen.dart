import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/database.dart';
import '../../services/call_script_service.dart';
import '../../sync/sync_engine.dart';

/// Available variable placeholders for the call script body.
/// Snake_case, flat -- matches Objective 07 decision and existing scripts.
const _availableVariables = <_VariableHelp>[
  _VariableHelp('{{voter_first_name}}', 'Voter\'s first name'),
  _VariableHelp('{{voter_last_name}}', 'Voter\'s last name'),
  _VariableHelp('{{voter_party}}', 'Voter\'s party affiliation'),
  _VariableHelp('{{voter_address}}', 'Voter\'s address'),
  _VariableHelp('{{voter_last_contact}}', 'Date of last contact'),
];

class _VariableHelp {
  final String token;
  final String description;
  const _VariableHelp(this.token, this.description);
}

/// Admin editor for call scripts. Create mode when [existing] is null,
/// edit mode otherwise. Supports deactivate from the overflow in edit mode.
class CallScriptEditorScreen extends ConsumerStatefulWidget {
  final CallScript? existing;

  const CallScriptEditorScreen({super.key, this.existing});

  @override
  ConsumerState<CallScriptEditorScreen> createState() =>
      _CallScriptEditorScreenState();
}

class _CallScriptEditorScreenState
    extends ConsumerState<CallScriptEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late bool _isActive;
  bool _isLoading = false;

  bool get _isEditMode => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existing?.title ?? '');
    _contentController =
        TextEditingController(text: widget.existing?.content ?? '');
    _isActive = widget.existing?.isActive ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final svc = ref.read(callScriptServiceProvider);
      if (_isEditMode) {
        await svc.updateCallScript(
          id: widget.existing!.id,
          title: _titleController.text.trim(),
          content: _contentController.text,
          isActive: _isActive,
        );
      } else {
        await svc.createCallScript(
          title: _titleController.text.trim(),
          content: _contentController.text,
        );
      }
      // Kick a sync cycle so the local Drift cache reflects the change.
      final syncFuture = SyncEngine.instance?.runSyncCycle();
      if (syncFuture != null) unawaited(syncFuture);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deactivate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate call script?'),
        content: const Text(
          'Navigators will no longer see this script after their next sync. '
          'This can be undone by editing the script and re-enabling it.',
        ),
        actions: [
          Semantics(
            identifier: 'call-script-editor-deactivate-cancel',
            button: true,
            child: TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
          ),
          Semantics(
            identifier: 'call-script-editor-deactivate-confirm',
            button: true,
            child: FilledButton.tonal(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                foregroundColor: Theme.of(ctx).colorScheme.error,
              ),
              child: const Text('Deactivate'),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final svc = ref.read(callScriptServiceProvider);
      await svc.deactivateCallScript(widget.existing!.id);
      final syncFuture = SyncEngine.instance?.runSyncCycle();
      if (syncFuture != null) unawaited(syncFuture);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deactivate failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _insertVariable(String token) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    final insertAt =
        selection.isValid ? selection.start : text.length;
    final newText =
        text.substring(0, insertAt) + token + text.substring(insertAt);
    _contentController.value = TextEditingValue(
      text: newText,
      selection:
          TextSelection.collapsed(offset: insertAt + token.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'call-script-editor-screen',
      explicitChildNodes: true,
      child: Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Call Script' : 'New Call Script'),
        actions: [
          if (_isEditMode)
            Semantics(
              identifier: 'call-script-editor-menu',
              button: true,
              child: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'deactivate') _deactivate();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'deactivate',
                    child: Text('Deactivate'),
                  ),
                ],
              ),
            ),
          Semantics(
            identifier: 'call-script-editor-save',
            button: true,
            child: TextButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Semantics(
              identifier: 'call-script-editor-title',
              textField: true,
              child: TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                maxLength: 120,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Title is required'
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            Semantics(
              identifier: 'call-script-editor-body',
              textField: true,
              child: TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: 'Body',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                minLines: 8,
                maxLines: 20,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Body is required'
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ExpansionTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Available variables'),
                subtitle: const Text('Tap to insert at cursor'),
                childrenPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                children: _availableVariables.map((v) {
                  return ListTile(
                    dense: true,
                    title: Text(
                      v.token,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    subtitle: Text(v.description),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      tooltip: 'Copy',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: v.token));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Copied ${v.token}'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                    onTap: () => _insertVariable(v.token),
                  );
                }).toList(),
              ),
            ),
            if (_isEditMode) ...[
              const SizedBox(height: 12),
              Semantics(
                identifier: 'call-script-editor-active-toggle',
                toggled: _isActive,
                child: SwitchListTile(
                  title: const Text('Active'),
                  subtitle: const Text(
                      'Inactive scripts are hidden from Navigators after their next sync'),
                  value: _isActive,
                  onChanged: _isLoading
                      ? null
                      : (v) => setState(() => _isActive = v),
                ),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }
}