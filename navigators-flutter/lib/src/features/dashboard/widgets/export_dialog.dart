import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../services/analytics_service.dart';

/// Dialog for exporting filtered analytics data as CSV or Excel.
///
/// Allows selection of export type (contacts, voters, tasks),
/// format (CSV, Excel), and date range. Downloads file and
/// opens share sheet.
class ExportDialog extends ConsumerStatefulWidget {
  const ExportDialog({super.key});

  @override
  ConsumerState<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends ConsumerState<ExportDialog> {
  String _exportType = 'contacts';
  String _format = 'csv';
  late DateTimeRange _dateRange;
  bool _exporting = false;

  static const _exportTypes = {
    'contacts': 'Contact Logs',
    'voters': 'Voters',
    'tasks': 'Tasks',
  };

  static const _formats = {
    'csv': 'CSV (.csv)',
    'xlsx': 'Excel (.xlsx)',
  };

  @override
  void initState() {
    super.initState();
    _dateRange = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 30)),
      end: DateTime.now(),
    );
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      helpText: 'Select export date range',
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  String get _formattedDateRange {
    final fmt = DateFormat('MMM d, yyyy');
    return '${fmt.format(_dateRange.start)} - ${fmt.format(_dateRange.end)}';
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final svc = ref.read(analyticsServiceProvider);
      final result = await svc.exportData(
        exportType: _exportType,
        format: _format,
        since: _dateRange.start.toUtc().toIso8601String(),
        until: _dateRange.end.toUtc().toIso8601String(),
      );

      // Save to temp file
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${result.filename}');
      await file.writeAsBytes(result.bytes);

      // Share/open file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Navigators Export',
      );

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'export-dialog',
      explicitChildNodes: true,
      child: AlertDialog(
      title: const Text('Export Data'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Export type
          Semantics(
            identifier: 'export-dialog-type',
            child: DropdownButtonFormField<String>(
            initialValue: _exportType,
            decoration: const InputDecoration(
              labelText: 'Data Type',
              border: OutlineInputBorder(),
            ),
            items: _exportTypes.entries
                .map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _exportType = v);
            },
            ),
          ),
          const SizedBox(height: 16),

          // Format
          Semantics(
            identifier: 'export-dialog-format',
            child: DropdownButtonFormField<String>(
            initialValue: _format,
            decoration: const InputDecoration(
              labelText: 'Format',
              border: OutlineInputBorder(),
            ),
            items: _formats.entries
                .map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _format = v);
            },
            ),
          ),
          const SizedBox(height: 16),

          // Date range
          Semantics(
            identifier: 'export-dialog-date-range',
            button: true,
            child: InkWell(
              onTap: _pickDateRange,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date Range',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(_formattedDateRange),
              ),
            ),
          ),
        ],
      ),
      actions: [
        Semantics(
          identifier: 'export-dialog-cancel',
          button: true,
          child: TextButton(
            onPressed: _exporting ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ),
        Semantics(
          identifier: 'export-dialog-submit',
          button: true,
          child: ElevatedButton.icon(
            onPressed: _exporting ? null : _export,
            icon: _exporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            label: const Text('Export'),
          ),
        ),
      ],
      ),
    );
  }
}
