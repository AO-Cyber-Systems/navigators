import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/sms_service.dart';
import '../../services/voter_service.dart';
import 'conversation_thread_screen.dart';

class ComposeMessageScreen extends ConsumerStatefulWidget {
  final String? voterId;
  final String? voterName;

  const ComposeMessageScreen({
    super.key,
    this.voterId,
    this.voterName,
  });

  @override
  ConsumerState<ComposeMessageScreen> createState() =>
      _ComposeMessageScreenState();
}

class _ComposeMessageScreenState extends ConsumerState<ComposeMessageScreen> {
  String? _selectedVoterId;
  String? _selectedVoterName;
  final TextEditingController _bodyController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  List<VoterSummary> _searchResults = [];
  bool _isSearching = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    if (widget.voterId != null) {
      _selectedVoterId = widget.voterId;
      _selectedVoterName = widget.voterName ?? 'Selected Voter';
    }
  }

  @override
  void dispose() {
    _bodyController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchVoters(String query) async {
    if (query.length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final voterService = ref.read(voterServiceProvider);
      final result = await voterService.searchVoters(query, pageSize: 10);
      if (mounted) {
        setState(() {
          _searchResults = result.voters;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _selectVoter(VoterSummary voter) {
    setState(() {
      _selectedVoterId = voter.id;
      _selectedVoterName = voter.fullName;
      _searchResults = [];
      _searchController.clear();
    });
  }

  void _clearVoter() {
    setState(() {
      _selectedVoterId = null;
      _selectedVoterName = null;
    });
  }

  Future<void> _send() async {
    if (_selectedVoterId == null || _bodyController.text.trim().isEmpty) return;
    setState(() => _isSending = true);

    try {
      final smsService = ref.read(smsServiceProvider);
      await smsService.sendP2PMessage(
          _selectedVoterId!, _bodyController.text.trim());
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ConversationThreadScreen(
              voterId: _selectedVoterId!,
              voterName: _selectedVoterName ?? '',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: ${e.toString()}'),
            action: SnackBarAction(label: 'Retry', onPressed: _send),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bodyLength = _bodyController.text.length;
    final canSend =
        _selectedVoterId != null && _bodyController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Message'),
        actions: [
          TextButton(
            onPressed: canSend && !_isSending ? _send : null,
            child: _isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Send'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Voter selection area
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant),
              ),
            ),
            child: _selectedVoterId != null
                ? Row(
                    children: [
                      const Text('To: ',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Chip(
                        label: Text(_selectedVoterName ?? ''),
                        onDeleted:
                            widget.voterId == null ? _clearVoter : null,
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search voter by name...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: _searchVoters,
                      ),
                      if (_isSearching)
                        const Padding(
                          padding: EdgeInsets.all(8),
                          child: Center(
                              child:
                                  CircularProgressIndicator(strokeWidth: 2)),
                        ),
                      if (_searchResults.isNotEmpty)
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final voter = _searchResults[index];
                              return ListTile(
                                dense: true,
                                title: Text(voter.fullName),
                                subtitle: Text(
                                    '${voter.party} - ${voter.resCity}'),
                                onTap: () => _selectVoter(voter),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
          ),

          // Message body
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _bodyController,
                maxLines: null,
                maxLength: 1600,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: 'Type your message...',
                  border: InputBorder.none,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),

          // Character count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '$bodyLength / 1600',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: bodyLength > 1500
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.outline,
                      ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(bodyLength / 160).ceil()} segment${(bodyLength / 160).ceil() == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
