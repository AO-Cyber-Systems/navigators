import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/sms_service.dart';
import 'campaign_create_screen.dart';

class CampaignListScreen extends ConsumerStatefulWidget {
  const CampaignListScreen({super.key});

  @override
  ConsumerState<CampaignListScreen> createState() =>
      _CampaignListScreenState();
}

class _CampaignListScreenState extends ConsumerState<CampaignListScreen> {
  List<SMSCampaign> _campaigns = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCampaigns();
  }

  Future<void> _loadCampaigns() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final smsService = ref.read(smsServiceProvider);
      final result = await smsService.listCampaigns();
      if (mounted) {
        setState(() {
          _campaigns = result.campaigns;
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

  Future<void> _pauseCampaign(SMSCampaign campaign) async {
    try {
      final smsService = ref.read(smsServiceProvider);
      await smsService.pauseCampaign(campaign.id);
      _loadCampaigns();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pause: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _cancelCampaign(SMSCampaign campaign) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Campaign'),
        content:
            Text('Cancel "${campaign.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel Campaign'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final smsService = ref.read(smsServiceProvider);
      await smsService.cancelCampaign(campaign.id);
      _loadCampaigns();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel: ${e.toString()}')),
        );
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'draft':
        return Colors.grey;
      case 'sending':
        return Colors.blue;
      case 'paused':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Campaigns')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'campaign_create',
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const CampaignCreateScreen(),
            ),
          );
          _loadCampaigns();
        },
        child: const Icon(Icons.add),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Failed to load campaigns'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadCampaigns,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_campaigns.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.campaign_outlined,
                size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text('No campaigns yet',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Create a campaign to send bulk messages.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    )),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCampaigns,
      child: ListView.builder(
        itemCount: _campaigns.length,
        itemBuilder: (context, index) {
          final campaign = _campaigns[index];
          return _buildCampaignCard(campaign);
        },
      ),
    );
  }

  Widget _buildCampaignCard(SMSCampaign campaign) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: () => _showCampaignDetail(campaign),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      campaign.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(campaign.status).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      campaign.status.toUpperCase(),
                      style: TextStyle(
                        color: _statusColor(campaign.status),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  if (campaign.isSending || campaign.isPaused)
                    PopupMenuButton<String>(
                      onSelected: (action) {
                        if (action == 'pause') _pauseCampaign(campaign);
                        if (action == 'cancel') _cancelCampaign(campaign);
                      },
                      itemBuilder: (_) => [
                        if (campaign.isSending)
                          const PopupMenuItem(
                              value: 'pause', child: Text('Pause')),
                        const PopupMenuItem(
                            value: 'cancel', child: Text('Cancel')),
                      ],
                    ),
                ],
              ),
              if (campaign.totalRecipients > 0) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: campaign.progressPercent,
                    minHeight: 6,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${campaign.sentCount} / ${campaign.totalRecipients} sent',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (campaign.deliveredCount > 0)
                      Text(
                        '${campaign.deliveredCount} delivered',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.green,
                            ),
                      ),
                    if (campaign.failedCount > 0)
                      Text(
                        '${campaign.failedCount} failed',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.red,
                            ),
                      ),
                  ],
                ),
              ],
              if (campaign.isSending) ...[
                const SizedBox(height: 4),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showCampaignDetail(SMSCampaign campaign) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(campaign.name,
                style: Theme.of(ctx).textTheme.headlineSmall),
            const SizedBox(height: 16),
            _detailRow('Status', campaign.status.toUpperCase()),
            _detailRow(
                'Total Recipients', campaign.totalRecipients.toString()),
            _detailRow('Sent', campaign.sentCount.toString()),
            _detailRow('Delivered', campaign.deliveredCount.toString()),
            _detailRow('Failed', campaign.failedCount.toString()),
            if (campaign.launchedAt.isNotEmpty)
              _detailRow('Launched', campaign.launchedAt),
            if (campaign.completedAt.isNotEmpty)
              _detailRow('Completed', campaign.completedAt),
            _detailRow('Created', campaign.createdAt),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value),
        ],
      ),
    );
  }
}
