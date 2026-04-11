import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/sms_service.dart';
import 'compose_message_screen.dart';
import 'conversation_thread_screen.dart';

class ConversationListScreen extends ConsumerStatefulWidget {
  const ConversationListScreen({super.key});

  @override
  ConsumerState<ConversationListScreen> createState() =>
      _ConversationListScreenState();
}

class _ConversationListScreenState
    extends ConsumerState<ConversationListScreen> {
  final List<ConversationSummary> _conversations = [];
  bool _isLoading = true;
  String? _error;
  String _nextPageToken = '';
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _nextPageToken.isNotEmpty) {
      _loadMore();
    }
  }

  Future<void> _loadConversations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final smsService = ref.read(smsServiceProvider);
      final result = await smsService.listConversations();
      if (mounted) {
        setState(() {
          _conversations
            ..clear()
            ..addAll(result.conversations);
          _nextPageToken = result.nextPageToken;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_nextPageToken.isEmpty || _isLoading) return;
    setState(() => _isLoading = true);
    try {
      final smsService = ref.read(smsServiceProvider);
      final result =
          await smsService.listConversations(pageToken: _nextPageToken);
      if (mounted) {
        setState(() {
          _conversations.addAll(result.conversations);
          _nextPageToken = result.nextPageToken;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _formatRelativeTime(String isoTimestamp) {
    if (isoTimestamp.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoTimestamp);
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.month}/${dt.day}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _conversations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48,
                color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text('Failed to load conversations',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadConversations,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline,
                size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text('No conversations yet',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Send a text to start one.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    )),
            const SizedBox(height: 24),
            FloatingActionButton.extended(
              heroTag: 'compose_empty',
              onPressed: () => _navigateToCompose(),
              icon: const Icon(Icons.edit),
              label: const Text('New Message'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadConversations,
          child: ListView.separated(
            controller: _scrollController,
            itemCount: _conversations.length + (_isLoading ? 1 : 0),
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index == _conversations.length) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final conv = _conversations[index];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(
                    conv.voterName.isNotEmpty
                        ? conv.voterName[0].toUpperCase()
                        : '?',
                  ),
                ),
                title: Text(
                  conv.voterName.isNotEmpty ? conv.voterName : 'Unknown Voter',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  conv.lastMessageBody,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  _formatRelativeTime(conv.lastMessageAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ConversationThreadScreen(
                        voterId: conv.voterId,
                        voterName: conv.voterName,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'compose_fab',
            onPressed: () => _navigateToCompose(),
            child: const Icon(Icons.edit),
          ),
        ),
      ],
    );
  }

  void _navigateToCompose() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ComposeMessageScreen(),
      ),
    );
  }
}
