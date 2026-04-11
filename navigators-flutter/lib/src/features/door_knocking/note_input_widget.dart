import 'package:eden_ui_flutter/eden_ui.dart';
import 'package:flutter/material.dart';

/// Note content and visibility value.
class NoteData {
  final String content;
  final String visibility;

  const NoteData({this.content = '', this.visibility = 'team'});
}

/// Text input with visibility selector for voter notes.
///
/// Provides a multiline text field and a compact dropdown for
/// visibility selection (private/team/org). Default visibility is 'team'.
class NoteInputWidget extends StatefulWidget {
  final ValueChanged<NoteData> onChanged;

  const NoteInputWidget({super.key, required this.onChanged});

  @override
  State<NoteInputWidget> createState() => _NoteInputWidgetState();
}

class _NoteInputWidgetState extends State<NoteInputWidget> {
  final _controller = TextEditingController();
  String _visibility = 'team';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _notifyChanged() {
    widget.onChanged(NoteData(
      content: _controller.text,
      visibility: _visibility,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Notes',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        EdenInput(
          controller: _controller,
          hint: 'Add a note about this visit...',
          maxLines: 4,
          onChanged: (_) => _notifyChanged(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Spacer(),
            SizedBox(
              width: 140,
              child: EdenSelect<String>(
                label: 'Visibility',
                size: EdenSelectSize.sm,
                value: _visibility,
                options: const [
                  EdenSelectOption(value: 'private', label: 'Private'),
                  EdenSelectOption(value: 'team', label: 'Team'),
                  EdenSelectOption(value: 'org', label: 'Organization'),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _visibility = value);
                    _notifyChanged();
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
