import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/database.dart';
import 'training_detail_screen.dart';

/// Training materials list screen.
///
/// Reads from local Drift database (synced from server).
/// Displays published training materials sorted by sort_order.
/// Tap to open detail screen with markdown viewer.
class TrainingListScreen extends ConsumerWidget {
  const TrainingListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    NavigatorsDatabase db;
    try {
      db = ref.read(databaseProvider);
    } catch (_) {
      return Scaffold(
        appBar: AppBar(title: const Text('Training')),
        body: const Center(child: Text('Database not initialized')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Training Materials'),
      ),
      body: StreamBuilder<List<TrainingMaterial>>(
        stream: db.trainingDao.watchPublishedMaterials(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final materials = snapshot.data ?? [];
          if (materials.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.school_outlined,
                    size: 64,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No training materials available',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: materials.length,
            itemBuilder: (context, index) {
              final material = materials[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        theme.colorScheme.primary.withValues(alpha: 0.1),
                    child: Icon(
                      Icons.article_outlined,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  title: Text(
                    material.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: material.description.isNotEmpty
                      ? Text(
                          material.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TrainingDetailScreen(
                          materialId: material.id,
                          title: material.title,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
