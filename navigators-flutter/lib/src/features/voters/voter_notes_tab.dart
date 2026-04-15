import 'package:drift/drift.dart' hide Column;
import 'package:eden_platform_flutter/eden_platform.dart';
import 'package:eden_ui_flutter/eden_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../database/database.dart';
import '../door_knocking/note_input_widget.dart';

/// Notes tab for a voter profile, showing all notes with visibility badges
/// and a button to add new notes.
///
/// Notes are loaded reactively via [VoterNoteDao.watchNotesForVoter].
/// New notes are written via [VoterNoteDao.insertNoteWithOutbox] for
/// offline-first sync.
class VoterNotesTab extends ConsumerWidget {
  final String voterId;

  /// Optional turf ID for new notes. If null, notes can still be viewed
  /// but the add-note button will be hidden.
  final String? turfId;

  const VoterNotesTab({
    super.key,
    required this.voterId,
    this.turfId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final notesStream = db.voterNoteDao.watchNotesForVoter(voterId);

    return StreamBuilder<List<VoterNote>>(
      stream: notesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: EdenEmptyState(
              title: 'Error loading notes',
              description: snapshot.error.toString(),
              icon: Icons.error_outline,
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final notes = snapshot.data!;

        return Stack(
          children: [
            if (notes.isEmpty)
              const Center(
                child: EdenEmptyState(
                  title: 'No notes yet',
                  description: 'Add a note about this voter to share with your team.',
                  icon: Icons.note_add,
                ),
              )
            else
              ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: notes.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) =>
                    _buildNoteCard(context, notes[index]),
              ),

            // FAB for adding notes (only if turf context is available)
            if (turfId != null)
              Positioned(
                right: 16,
                bottom: 16,
                child: Semantics(
                  identifier: 'voter-notes-add-fab',
                  button: true,
                  child: FloatingActionButton(
                    onPressed: () => _showAddNoteSheet(context, ref),
                    child: const Icon(Icons.note_add),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildNoteCard(BuildContext context, VoterNote note) {
    final theme = Theme.of(context);
    final timeFormat = DateFormat('MMM d, yyyy h:mm a');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: visibility badge + timestamp
          Row(
            children: [
              _visibilityBadge(note.visibility),
              const Spacer(),
              Text(
                timeFormat.format(note.createdAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color:
                      theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Note content
          Text(
            note.content,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _visibilityBadge(String visibility) {
    final EdenBadgeVariant variant;
    final String label;

    switch (visibility) {
      case 'private':
        variant = EdenBadgeVariant.neutral;
        label = 'Private';
      case 'team':
        variant = EdenBadgeVariant.info;
        label = 'Team';
      case 'org':
        variant = EdenBadgeVariant.success;
        label = 'Organization';
      default:
        variant = EdenBadgeVariant.neutral;
        label = visibility;
    }

    return EdenBadge(
      label: label,
      variant: variant,
      size: EdenBadgeSize.sm,
    );
  }

  void _showAddNoteSheet(BuildContext context, WidgetRef ref) {
    NoteData noteData = const NoteData();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NoteInputWidget(
              onChanged: (data) => noteData = data,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: Semantics(
                identifier: 'voter-notes-save-btn',
                button: true,
                child: EdenButton(
                label: 'Save Note',
                onPressed: () async {
                  if (noteData.content.trim().isEmpty) return;

                  final db = ref.read(databaseProvider);
                  final auth = ref.read(authProvider);
                  final userId = auth.userId ?? '';
                  final now = DateTime.now();

                  // Generate a simple UUID
                  final noteId = _generateNoteId();

                  await db.voterNoteDao.insertNoteWithOutbox(
                    VoterNotesCompanion(
                      id: Value(noteId),
                      voterId: Value(voterId),
                      userId: Value(userId),
                      turfId: Value(turfId!),
                      content: Value(noteData.content.trim()),
                      visibility: Value(noteData.visibility),
                      createdAt: Value(now),
                      updatedAt: Value(now),
                    ),
                    db.syncDao,
                  );

                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
              ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Generate a UUID v4 string.
  static String _generateNoteId() {
    final rng = DateTime.now().microsecondsSinceEpoch;
    // Simple but sufficient for client-side note IDs
    return '${rng.toRadixString(16).padLeft(12, '0')}-'
        '${(rng ~/ 1000).toRadixString(16).padLeft(4, '0')}-'
        '4${(rng % 0xfff).toRadixString(16).padLeft(3, '0')}-'
        '${(0x8000 | (rng & 0x3fff)).toRadixString(16)}-'
        '${DateTime.now().millisecondsSinceEpoch.toRadixString(16).padLeft(12, '0')}';
  }
}
