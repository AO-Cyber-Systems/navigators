import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/sms_service.dart';

class ConversationThreadScreen extends ConsumerStatefulWidget {
  final String voterId;
  final String voterName;

  const ConversationThreadScreen({
    super.key,
    required this.voterId,
    required this.voterName,
  });

  @override
  ConsumerState<ConversationThreadScreen> createState() =>
      _ConversationThreadScreenState();
}

class _ConversationThreadScreenState
    extends ConsumerState<ConversationThreadScreen> {
  final List<SMSMessage> _messages = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isSending = false;
  String? _error;
  String _nextPageToken = '';
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Load older messages when scrolling near the top
    if (_scrollController.position.pixels <=
            _scrollController.position.minScrollExtent + 200 &&
        !_isLoadingMore &&
        _nextPageToken.isNotEmpty) {
      _loadOlderMessages();
    }
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final smsService = ref.read(smsServiceProvider);
      final result = await smsService.getConversation(widget.voterId);
      if (mounted) {
        setState(() {
          _messages
            ..clear()
            ..addAll(result.messages);
          _nextPageToken = result.nextPageToken;
          _isLoading = false;
        });
        _scrollToBottom();
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

  Future<void> _loadOlderMessages() async {
    if (_nextPageToken.isEmpty || _isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final smsService = ref.read(smsServiceProvider);
      final result = await smsService.getConversation(
        widget.voterId,
        pageToken: _nextPageToken,
      );
      if (mounted) {
        setState(() {
          _messages.insertAll(0, result.messages);
          _nextPageToken = result.nextPageToken;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final body = _messageController.text.trim();
    if (body.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    // Optimistic add
    final optimisticMsg = SMSMessage(
      id: 'pending-${DateTime.now().millisecondsSinceEpoch}',
      voterId: widget.voterId,
      userId: '',
      direction: 'outbound',
      messageType: 'p2p',
      body: body,
      status: 'queued',
      createdAt: DateTime.now().toIso8601String(),
      fromNumber: '',
      toNumber: '',
    );
    setState(() {
      _messages.add(optimisticMsg);
    });
    _messageController.clear();
    _scrollToBottom();

    try {
      final smsService = ref.read(smsServiceProvider);
      final sent = await smsService.sendP2PMessage(widget.voterId, body);
      if (mounted) {
        setState(() {
          final idx = _messages.indexOf(optimisticMsg);
          if (idx >= 0) {
            _messages[idx] = sent;
          }
          _isSending = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.remove(optimisticMsg);
          _messageController.text = body;
          _isSending = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: ${e.toString()}'),
            action: SnackBarAction(label: 'Retry', onPressed: _sendMessage),
          ),
        );
      }
    }
  }

  String _formatTime(String isoTimestamp) {
    if (isoTimestamp.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoTimestamp);
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      final min = dt.minute.toString().padLeft(2, '0');
      return '$hour:$min $amPm';
    } catch (_) {
      return '';
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'queued':
        return Icons.schedule;
      case 'sent':
        return Icons.check;
      case 'delivered':
        return Icons.done_all;
      case 'failed':
      case 'undelivered':
        return Icons.error_outline;
      default:
        return Icons.check;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'delivered':
        return Colors.blue;
      case 'failed':
      case 'undelivered':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.voterName.isNotEmpty
            ? widget.voterName
            : 'Conversation'),
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildMessageList(),
          ),
          _buildComposeBar(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_isLoading && _messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Failed to load messages'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadMessages,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Text(
          'No messages yet. Send one below.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _messages.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (_isLoadingMore && index == 0) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final msgIndex = _isLoadingMore ? index - 1 : index;
        final msg = _messages[msgIndex];
        return _buildMessageBubble(msg);
      },
    );
  }

  Widget _buildMessageBubble(SMSMessage msg) {
    final isOutbound = msg.isOutbound;
    final alignment =
        isOutbound ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = isOutbound
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    final textColor = isOutbound
        ? Theme.of(context).colorScheme.onPrimary
        : Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft:
                    isOutbound ? const Radius.circular(16) : Radius.zero,
                bottomRight:
                    isOutbound ? Radius.zero : const Radius.circular(16),
              ),
            ),
            child: Text(msg.body, style: TextStyle(color: textColor)),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatTime(msg.createdAt),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
              if (isOutbound) ...[
                const SizedBox(width: 4),
                Icon(
                  _statusIcon(msg.status),
                  size: 14,
                  color: _statusColor(msg.status),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComposeBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                maxLines: null,
                maxLength: 1600,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _isSending ? null : _sendMessage,
              icon: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}
