import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../services/volunteer_service.dart';

/// Training material detail screen with markdown content viewer.
///
/// Fetches a presigned URL from TrainingService, downloads the markdown
/// content, and renders it using flutter_markdown's MarkdownBody widget.
class TrainingDetailScreen extends ConsumerStatefulWidget {
  final String materialId;
  final String title;

  const TrainingDetailScreen({
    super.key,
    required this.materialId,
    required this.title,
  });

  @override
  ConsumerState<TrainingDetailScreen> createState() =>
      _TrainingDetailScreenState();
}

class _TrainingDetailScreenState extends ConsumerState<TrainingDetailScreen> {
  String? _markdownContent;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = ref.read(volunteerServiceProvider);

      // Get presigned URL for the training material
      final url = await service.getTrainingDownloadUrl(widget.materialId);
      if (url.isEmpty) {
        throw Exception('No download URL returned');
      }

      // Fetch markdown content from presigned URL
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('Download failed: ${response.statusCode}');
      }

      if (mounted) {
        setState(() {
          _markdownContent = response.body;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Unable to load content. Please check your connection.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      identifier: 'training-detail-screen',
      explicitChildNodes: true,
      child: Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cloud_off,
                          size: 64,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Semantics(
                          identifier: 'training-detail-retry-btn',
                          button: true,
                          child: FilledButton.tonal(
                            onPressed: _loadContent,
                            child: const Text('Retry'),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: MarkdownBody(
                    data: _markdownContent ?? '',
                  ),
                ),
      ),
    );
  }
}
