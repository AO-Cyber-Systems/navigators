import 'dart:async';

import 'package:eden_ui_flutter/eden_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/voter_service.dart';

/// Debounced search bar for voter search.
/// Calls [voterSearchProvider] on text change with 300ms debounce.
class VoterSearchBar extends ConsumerStatefulWidget {
  /// Called when the user submits a search or clears the field.
  final VoidCallback? onSearchChanged;

  const VoterSearchBar({super.key, this.onSearchChanged});

  @override
  ConsumerState<VoterSearchBar> createState() => _VoterSearchBarState();
}

class _VoterSearchBarState extends ConsumerState<VoterSearchBar> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (value.trim().isEmpty) {
        ref.read(voterSearchProvider.notifier).clear();
      } else {
        ref.read(voterSearchProvider.notifier).search(value.trim());
      }
      widget.onSearchChanged?.call();
    });
  }

  void _onClear() {
    _controller.clear();
    ref.read(voterSearchProvider.notifier).clear();
    widget.onSearchChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return EdenSearchInput(
      controller: _controller,
      hint: 'Search voters by name, address...',
      onChanged: _onChanged,
      onClear: _onClear,
    );
  }
}
