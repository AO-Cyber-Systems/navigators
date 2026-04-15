import 'package:eden_ui_flutter/eden_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/import_service.dart';
import 'import_progress_card.dart';

/// Admin-only screen for uploading voter files and monitoring import progress.
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  String _sourceType = 'cvr';
  bool _isUploading = false;
  String? _uploadError;
  String? _selectedFileName;
  PlatformFile? _selectedFile;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(importJobsProvider.notifier).loadJobs();
    });
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'csv'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFile = result.files.first;
        _selectedFileName = result.files.first.name;
        _uploadError = null;
      });
    }
  }

  Future<void> _startImport() async {
    if (_selectedFile == null || _selectedFile!.bytes == null) {
      setState(() => _uploadError = 'Please select a file first.');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadError = null;
    });

    try {
      final service = ref.read(importServiceProvider);

      // 1. Start import job and get presigned URL
      final result = await service.startImport(
        fileName: _selectedFileName!,
        sourceType: _sourceType,
      );

      // 2. Upload file to presigned URL
      await service.uploadFileToPresignedUrl(result.uploadUrl, _selectedFile!.bytes!);

      // 3. Confirm upload to trigger processing
      await service.confirmUpload(result.jobId);

      // 4. Refresh job list
      await ref.read(importJobsProvider.notifier).loadJobs();

      setState(() {
        _isUploading = false;
        _selectedFile = null;
        _selectedFileName = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Import started successfully')),
        );
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _uploadError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final jobsState = ref.watch(importJobsProvider);

    return Semantics(
      identifier: 'import-screen',
      explicitChildNodes: true,
      child: Scaffold(
      appBar: AppBar(title: const Text('Import Voters')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Upload section
            EdenCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Upload Voter File', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),

                    // Source type selector
                    Row(
                      children: [
                        Text('Source Type:', style: theme.textTheme.bodyMedium),
                        const SizedBox(width: 16),
                        Semantics(
                          identifier: 'import-source-type',
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'cvr', label: Text('CVR')),
                              ButtonSegment(value: 'l2', label: Text('L2')),
                            ],
                            selected: {_sourceType},
                            onSelectionChanged: (v) =>
                                setState(() => _sourceType = v.first),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // File picker
                    Row(
                      children: [
                        Semantics(
                          identifier: 'import-select-file-btn',
                          button: true,
                          child: EdenButton(
                            label: 'Select File',
                            onPressed: _isUploading ? null : _pickFile,
                            icon: Icons.upload_file,
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (_selectedFileName != null)
                          Expanded(
                            child: Text(
                              _selectedFileName!,
                              style: theme.textTheme.bodyMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Field mapping note
                    Text(
                      'Default field mapping will be used for ${_sourceType.toUpperCase()} format. '
                      'Column order should match the standard ${_sourceType.toUpperCase()} export.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Error display
                    if (_uploadError != null) ...[
                      EdenAlert(
                        title: 'Upload Error',
                        message: _uploadError!,
                        variant: EdenAlertVariant.danger,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Start import button
                    Semantics(
                      identifier: 'import-start-btn',
                      button: true,
                      child: EdenButton(
                        label: _isUploading ? 'Uploading...' : 'Start Import',
                        onPressed: _isUploading || _selectedFile == null
                            ? null
                            : _startImport,
                        icon: Icons.play_arrow,
                      ),
                    ),

                    if (_isUploading) ...[
                      const SizedBox(height: 8),
                      const LinearProgressIndicator(),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Import jobs list
            Text('Import Jobs', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),

            if (jobsState.isLoading && jobsState.jobs.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (jobsState.error != null)
              EdenAlert(
                title: 'Error loading jobs',
                message: jobsState.error!,
                variant: EdenAlertVariant.danger,
              )
            else if (jobsState.jobs.isEmpty)
              const EdenEmptyState(
                title: 'No imports yet',
                description: 'Upload a voter file above to start an import.',
                icon: Icons.cloud_upload_outlined,
              )
            else
              ...jobsState.jobs.map(
                (job) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ImportProgressCard(job: job),
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }
}
