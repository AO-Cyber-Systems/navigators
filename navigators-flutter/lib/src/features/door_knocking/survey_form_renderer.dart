import 'dart:convert';

import 'package:eden_ui_flutter/eden_ui.dart';
import 'package:flutter/material.dart';

import '../../database/database.dart';

/// A parsed survey field from the JSON schema.
class _SurveyField {
  final String id;
  final String label;
  final String type; // single_select, multi_select, text, number, boolean
  final bool required;
  final List<String> options; // For select types
  final int? maxLength;

  const _SurveyField({
    required this.id,
    required this.label,
    required this.type,
    this.required = false,
    this.options = const [],
    this.maxLength,
  });

  factory _SurveyField.fromJson(Map<String, dynamic> json) {
    return _SurveyField(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      type: json['type'] as String? ?? 'text',
      required: json['required'] as bool? ?? false,
      options: (json['options'] as List<dynamic>?)
              ?.map((o) => o.toString())
              .toList() ??
          [],
      maxLength: json['maxLength'] as int?,
    );
  }
}

/// Dynamic form renderer that reads a SurveyForm JSON schema and renders
/// Eden form widgets for each field.
///
/// Collects responses as `Map<String, dynamic>` keyed by field ID.
class SurveyFormRenderer extends StatefulWidget {
  final SurveyForm form;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const SurveyFormRenderer({
    super.key,
    required this.form,
    required this.onChanged,
  });

  @override
  State<SurveyFormRenderer> createState() => _SurveyFormRendererState();
}

class _SurveyFormRendererState extends State<SurveyFormRenderer> {
  late List<_SurveyField> _fields;
  final Map<String, dynamic> _responses = {};
  final Map<String, TextEditingController> _textControllers = {};
  String? _parseError;

  @override
  void initState() {
    super.initState();
    _parseSchema();
  }

  @override
  void dispose() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _parseSchema() {
    try {
      final schema = jsonDecode(widget.form.schema) as Map<String, dynamic>;
      final fieldList = schema['fields'] as List<dynamic>? ?? [];
      _fields = fieldList
          .map((f) => _SurveyField.fromJson(f as Map<String, dynamic>))
          .where((f) => f.id.isNotEmpty)
          .toList();

      // Initialize boolean fields to false
      for (final field in _fields) {
        if (field.type == 'boolean') {
          _responses[field.id] = false;
        }
      }
    } catch (e) {
      _parseError = 'Failed to load survey form: $e';
      _fields = [];
    }
  }

  void _updateResponse(String fieldId, dynamic value) {
    setState(() {
      _responses[fieldId] = value;
    });
    widget.onChanged(_responses);
  }

  @override
  Widget build(BuildContext context) {
    if (_parseError != null) {
      return EdenAlert(
        title: 'Survey Error',
        message: _parseError!,
        variant: EdenAlertVariant.danger,
      );
    }

    if (_fields.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.form.title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (widget.form.description.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            widget.form.description,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _fields.length,
          separatorBuilder: (_, _) => const SizedBox(height: 16),
          itemBuilder: (context, index) => _buildField(_fields[index]),
        ),
      ],
    );
  }

  Widget _buildField(_SurveyField field) {
    switch (field.type) {
      case 'single_select':
        return _buildSingleSelect(field);
      case 'multi_select':
        return _buildMultiSelect(field);
      case 'text':
        return _buildTextInput(field);
      case 'number':
        return _buildNumberInput(field);
      case 'boolean':
        return _buildBooleanToggle(field);
      default:
        return _buildTextInput(field);
    }
  }

  Widget _buildSingleSelect(_SurveyField field) {
    return EdenSelect<String>(
      label: _fieldLabel(field),
      hint: 'Select an option',
      value: _responses[field.id] as String?,
      options: field.options
          .map((o) => EdenSelectOption<String>(value: o, label: o))
          .toList(),
      onChanged: (value) => _updateResponse(field.id, value),
    );
  }

  Widget _buildMultiSelect(_SurveyField field) {
    final selected = (_responses[field.id] as List<String>?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _fieldLabel(field),
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: field.options.map((option) {
            final isSelected = selected.contains(option);
            return FilterChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (checked) {
                final updated = List<String>.from(selected);
                if (checked) {
                  updated.add(option);
                } else {
                  updated.remove(option);
                }
                _updateResponse(field.id, updated);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTextInput(_SurveyField field) {
    final controller = _textControllers.putIfAbsent(
      field.id,
      () => TextEditingController(),
    );

    return EdenInput(
      label: _fieldLabel(field),
      controller: controller,
      hint: 'Enter ${field.label.toLowerCase()}',
      onChanged: (value) => _updateResponse(field.id, value),
    );
  }

  Widget _buildNumberInput(_SurveyField field) {
    final controller = _textControllers.putIfAbsent(
      field.id,
      () => TextEditingController(),
    );

    return EdenInput(
      label: _fieldLabel(field),
      controller: controller,
      hint: 'Enter a number',
      keyboardType: TextInputType.number,
      onChanged: (value) {
        final parsed = int.tryParse(value) ?? double.tryParse(value);
        _updateResponse(field.id, parsed);
      },
    );
  }

  Widget _buildBooleanToggle(_SurveyField field) {
    final value = _responses[field.id] as bool? ?? false;
    return EdenToggle(
      label: field.label,
      value: value,
      onChanged: (v) => _updateResponse(field.id, v),
    );
  }

  String _fieldLabel(_SurveyField field) {
    return field.required ? '${field.label} *' : field.label;
  }

  /// Validate required fields. Returns true if valid.
  bool validate() {
    for (final field in _fields) {
      if (!field.required) continue;
      final value = _responses[field.id];
      if (value == null) return false;
      if (value is String && value.isEmpty) return false;
      if (value is List && value.isEmpty) return false;
    }
    return true;
  }

  /// Get current responses map.
  Map<String, dynamic> get responses => Map.unmodifiable(_responses);
}
