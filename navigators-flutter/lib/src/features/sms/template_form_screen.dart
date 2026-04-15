import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/sms_service.dart';

class TemplateFormScreen extends ConsumerStatefulWidget {
  final String? templateId;

  const TemplateFormScreen({super.key, this.templateId});

  @override
  ConsumerState<TemplateFormScreen> createState() => _TemplateFormScreenState();
}

class _TemplateFormScreenState extends ConsumerState<TemplateFormScreen> {
  final _nameController = TextEditingController();
  final _bodyController = TextEditingController();
  final _bodyFocusNode = FocusNode();
  bool _isLoading = false;
  bool _isSaving = false;
  String? _previewText;
  String? _previewError;

  static const _availableMergeFields = [
    'FirstName',
    'LastName',
    'City',
    'District',
    'Party',
  ];

  bool get _isEditMode => widget.templateId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _loadTemplate();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bodyController.dispose();
    _bodyFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadTemplate() async {
    setState(() => _isLoading = true);
    try {
      final smsService = ref.read(smsServiceProvider);
      final template = await smsService.getTemplate(widget.templateId!);
      if (mounted) {
        _nameController.text = template.name;
        _bodyController.text = template.body;
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load template: ${e.toString()}')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  void _insertMergeField(String field) {
    final text = _bodyController.text;
    final selection = _bodyController.selection;
    final tag = '{{.$field}}';

    if (selection.isValid && selection.start >= 0) {
      final newText = text.replaceRange(selection.start, selection.end, tag);
      _bodyController.text = newText;
      _bodyController.selection = TextSelection.collapsed(
        offset: selection.start + tag.length,
      );
    } else {
      _bodyController.text = text + tag;
      _bodyController.selection = TextSelection.collapsed(
        offset: _bodyController.text.length,
      );
    }
    _bodyFocusNode.requestFocus();
  }

  List<String> _extractMergeFields() {
    final body = _bodyController.text;
    final regex = RegExp(r'\{\{\.(\w+)\}\}');
    final matches = regex.allMatches(body);
    return matches.map((m) => m.group(1)!).toSet().toList();
  }

  Future<void> _preview() async {
    if (_isEditMode) {
      try {
        final smsService = ref.read(smsServiceProvider);
        final rendered = await smsService.previewTemplate(widget.templateId!);
        setState(() {
          _previewText = rendered;
          _previewError = null;
        });
      } catch (e) {
        setState(() {
          _previewText = null;
          _previewError = e.toString();
        });
      }
    } else {
      // Local preview with sample data
      var preview = _bodyController.text;
      const sampleData = {
        'FirstName': 'Jane',
        'LastName': 'Smith',
        'City': 'Portland',
        'District': 'HD-42',
        'Party': 'Republican',
      };
      for (final entry in sampleData.entries) {
        preview = preview.replaceAll('{{.${entry.key}}}', entry.value);
      }
      setState(() {
        _previewText = preview;
        _previewError = null;
      });
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final body = _bodyController.text.trim();

    if (name.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and body are required')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final mergeFields = _extractMergeFields();

    try {
      final smsService = ref.read(smsServiceProvider);
      if (_isEditMode) {
        await smsService.updateTemplate(
            widget.templateId!, name, body, mergeFields);
      } else {
        await smsService.createTemplate(name, body, mergeFields);
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
            title: Text(_isEditMode ? 'Edit Template' : 'New Template')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Semantics(
      identifier: 'sms-template-form-screen',
      explicitChildNodes: true,
      child: Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Template' : 'New Template'),
        actions: [
          Semantics(
            identifier: 'sms-template-form-save',
            button: true,
            child: TextButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              identifier: 'sms-template-form-name',
              textField: true,
              child: TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Template Name',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Semantics(
              identifier: 'sms-template-form-body',
              textField: true,
              child: TextField(
                controller: _bodyController,
                focusNode: _bodyFocusNode,
                maxLines: 6,
                maxLength: 1600,
                decoration: const InputDecoration(
                  labelText: 'Message Body',
                  hintText:
                      'Use {{.FirstName}}, {{.LastName}}, etc. for merge fields',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                onChanged: (_) => setState(() {
                  _previewText = null;
                  _previewError = null;
                }),
              ),
            ),
            const SizedBox(height: 12),
            Text('Merge Fields',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _availableMergeFields
                  .map((field) => ActionChip(
                        label: Text('{{.$field}}'),
                        onPressed: () => _insertMergeField(field),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Semantics(
                  identifier: 'sms-template-form-preview-btn',
                  button: true,
                  child: OutlinedButton.icon(
                    onPressed: _preview,
                    icon: const Icon(Icons.preview),
                    label: const Text('Preview'),
                  ),
                ),
              ],
            ),
            if (_previewText != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Preview',
                        style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 4),
                    Text(_previewText!),
                  ],
                ),
              ),
            ],
            if (_previewError != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Preview error: $_previewError',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer),
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
