import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../services/volunteer_service.dart';
import '../../sync/sync_engine.dart';

/// Admin-only screen for uploading new training materials.
///
/// Flow:
/// 1. Pick a file via file_picker.
/// 2. Fill title/description/sort order metadata form.
/// 3. On upload:
///    a. Request a presigned PUT URL + server-generated storage key.
///    b. PUT raw bytes directly to MinIO.
///    c. Call CreateTrainingMaterial with the same storage key as content_url.
///    d. Trigger a sync cycle so the new row appears locally.
class TrainingUploadScreen extends ConsumerStatefulWidget {
  const TrainingUploadScreen({super.key});

  @override
  ConsumerState<TrainingUploadScreen> createState() =>
      _TrainingUploadScreenState();
}

class _TrainingUploadScreenState extends ConsumerState<TrainingUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtl = TextEditingController();
  final _descCtl = TextEditingController();
  final _sortOrderCtl = TextEditingController(text: '0');

  PlatformFile? _selectedFile;
  bool _isUploading = false;
  String? _error;

  @override
  void dispose() {
    _titleCtl.dispose();
    _descCtl.dispose();
    _sortOrderCtl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      withData: kIsWeb, // bytes only needed on web; elsewhere use .path
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      setState(() {
        _selectedFile = file;
        _error = null;
        if (_titleCtl.text.isEmpty) {
          // Default title to filename without extension.
          final dot = file.name.lastIndexOf('.');
          _titleCtl.text = dot > 0 ? file.name.substring(0, dot) : file.name;
        }
      });
    }
  }

  String _inferContentType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.md') || lower.endsWith('.markdown')) {
      return 'text/markdown';
    }
    if (lower.endsWith('.txt')) return 'text/plain';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    return 'application/octet-stream';
  }

  Future<Uint8List> _readBytes(PlatformFile file) async {
    if (file.bytes != null) return file.bytes!;
    if (file.path != null) {
      return await File(file.path!).readAsBytes();
    }
    throw StateError('File has neither bytes nor path');
  }

  Future<void> _upload() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedFile == null) {
      setState(() => _error = 'Please choose a file first.');
      return;
    }

    setState(() {
      _isUploading = true;
      _error = null;
    });

    try {
      final svc = ref.read(volunteerServiceProvider);
      final contentType = _inferContentType(_selectedFile!.name);

      // 1. Request a presigned PUT URL and server-generated storage key.
      final uploadInfo = await svc.getTrainingUploadUrl(
        filename: _selectedFile!.name,
        contentType: contentType,
      );
      final presignedUrl = uploadInfo['presignedUrl'] as String? ?? '';
      final storageKey = uploadInfo['storageKey'] as String? ?? '';
      if (presignedUrl.isEmpty || storageKey.isEmpty) {
        throw Exception('Server did not return a valid upload URL');
      }

      // 2. Read bytes and PUT directly to MinIO.
      final bytes = await _readBytes(_selectedFile!);
      final putResp = await http.put(
        Uri.parse(presignedUrl),
        body: bytes,
        headers: {'Content-Type': contentType},
      );
      if (putResp.statusCode != 200) {
        throw Exception(
            'Upload to storage failed: ${putResp.statusCode} ${putResp.body}');
      }

      // 3. Register the metadata row pointing at the uploaded object.
      final sortOrder = int.tryParse(_sortOrderCtl.text.trim()) ?? 0;
      await svc.createTrainingMaterial(
        title: _titleCtl.text.trim(),
        description: _descCtl.text.trim(),
        contentUrl: storageKey,
        sortOrder: sortOrder,
      );

      // 4. Kick off a sync cycle so the new row lands in local Drift.
      try {
        await SyncEngine.instance?.runSyncCycle();
      } catch (_) {
        // Sync failure is non-fatal -- the next scheduled cycle will catch up.
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Training material uploaded')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _isUploading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fileLabel = _selectedFile?.name ?? 'Choose a file';

    return Semantics(
      identifier: 'training-upload-screen',
      explicitChildNodes: true,
      child: Scaffold(
      appBar: AppBar(title: const Text('Upload Training Material')),
      body: AbsorbPointer(
        absorbing: _isUploading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  identifier: 'training-upload-file-picker',
                  button: true,
                  child: OutlinedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.attach_file),
                    label: Text(fileLabel, overflow: TextOverflow.ellipsis),
                  ),
                ),
                const SizedBox(height: 16),
                Semantics(
                  identifier: 'training-upload-title',
                  textField: true,
                  child: TextFormField(
                    controller: _titleCtl,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Title is required'
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                Semantics(
                  identifier: 'training-upload-description',
                  textField: true,
                  child: TextFormField(
                    controller: _descCtl,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                    minLines: 2,
                    maxLines: 5,
                  ),
                ),
                const SizedBox(height: 16),
                Semantics(
                  identifier: 'training-upload-sort-order',
                  textField: true,
                  child: TextFormField(
                    controller: _sortOrderCtl,
                    decoration: const InputDecoration(
                      labelText: 'Sort order',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(height: 24),
                if (_isUploading) const LinearProgressIndicator(),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
                const SizedBox(height: 16),
                Semantics(
                  identifier: 'training-upload-submit',
                  button: true,
                  child: FilledButton.icon(
                    onPressed: _isUploading ? null : _upload,
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('Upload'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}
