import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/sms_service.dart';

/// Step-based campaign creation wizard.
///
/// Steps: Name -> Template -> Segment -> Review & Launch
enum _CampaignStep { name, template, segment, review }

class CampaignCreateScreen extends ConsumerStatefulWidget {
  const CampaignCreateScreen({super.key});

  @override
  ConsumerState<CampaignCreateScreen> createState() =>
      _CampaignCreateScreenState();
}

class _CampaignCreateScreenState extends ConsumerState<CampaignCreateScreen> {
  _CampaignStep _currentStep = _CampaignStep.name;
  final _nameController = TextEditingController();

  // Template selection
  List<SMSTemplate> _templates = [];
  bool _loadingTemplates = false;
  String? _selectedTemplateId;
  SMSTemplate? _selectedTemplate;

  // Segment filters
  String? _selectedDistrict;
  String? _selectedParty;
  final List<String> _selectedTags = [];

  // 10DLC status
  String? _tenDlcStatus;
  bool _loadingDlcStatus = false;

  // Creation state
  bool _isCreating = false;
  SMSCampaign? _createdCampaign;

  static const _parties = ['Republican', 'Democrat', 'Independent', 'Green', 'Libertarian'];
  static const _districts = ['HD-1', 'HD-2', 'HD-3', 'SD-1', 'SD-2', 'CD-1', 'CD-2'];
  static const _tags = ['Priority', 'Contacted', 'Volunteer', 'Donor', 'New Voter'];

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    setState(() => _loadingTemplates = true);
    try {
      final smsService = ref.read(smsServiceProvider);
      final templates = await smsService.listTemplates();
      if (mounted) {
        setState(() {
          _templates = templates;
          _loadingTemplates = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingTemplates = false);
    }
  }

  Future<void> _check10DLCStatus() async {
    setState(() => _loadingDlcStatus = true);
    try {
      final smsService = ref.read(smsServiceProvider);
      final result = await smsService.get10DLCStatus();
      if (mounted) {
        setState(() {
          _tenDlcStatus = result.status;
          _loadingDlcStatus = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _tenDlcStatus = 'unknown';
          _loadingDlcStatus = false;
        });
      }
    }
  }

  void _nextStep() {
    setState(() {
      switch (_currentStep) {
        case _CampaignStep.name:
          if (_nameController.text.trim().isEmpty) return;
          _currentStep = _CampaignStep.template;
          break;
        case _CampaignStep.template:
          if (_selectedTemplateId == null) return;
          _currentStep = _CampaignStep.segment;
          break;
        case _CampaignStep.segment:
          _currentStep = _CampaignStep.review;
          _check10DLCStatus();
          break;
        case _CampaignStep.review:
          break;
      }
    });
  }

  void _previousStep() {
    setState(() {
      switch (_currentStep) {
        case _CampaignStep.name:
          break;
        case _CampaignStep.template:
          _currentStep = _CampaignStep.name;
          break;
        case _CampaignStep.segment:
          _currentStep = _CampaignStep.template;
          break;
        case _CampaignStep.review:
          _currentStep = _CampaignStep.segment;
          break;
      }
    });
  }

  String _buildSegmentFilters() {
    final filters = <String, dynamic>{};
    if (_selectedParty != null) filters['party'] = _selectedParty;
    if (_selectedDistrict != null) filters['district'] = _selectedDistrict;
    if (_selectedTags.isNotEmpty) filters['tags'] = _selectedTags;
    return jsonEncode(filters);
  }

  Future<void> _createCampaign() async {
    setState(() => _isCreating = true);
    try {
      final smsService = ref.read(smsServiceProvider);
      final campaign = await smsService.createCampaign(
        _nameController.text.trim(),
        _selectedTemplateId!,
        _buildSegmentFilters(),
      );
      if (mounted) {
        setState(() {
          _createdCampaign = campaign;
          _isCreating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _launchCampaign() async {
    if (_createdCampaign == null) return;
    try {
      final smsService = ref.read(smsServiceProvider);
      await smsService.launchCampaign(_createdCampaign!.id);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to launch: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Campaign'),
      ),
      body: _createdCampaign != null
          ? _buildSuccessView()
          : _buildStepContent(),
      bottomNavigationBar:
          _createdCampaign != null ? null : _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (_currentStep != _CampaignStep.name)
              OutlinedButton(
                onPressed: _previousStep,
                child: const Text('Back'),
              ),
            const Spacer(),
            if (_currentStep != _CampaignStep.review)
              FilledButton(
                onPressed: _nextStep,
                child: const Text('Next'),
              ),
            if (_currentStep == _CampaignStep.review)
              FilledButton(
                onPressed: _isCreating ? null : _createCampaign,
                child: _isCreating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create Campaign'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step indicator
          _buildStepIndicator(),
          const SizedBox(height: 24),
          // Step content
          switch (_currentStep) {
            _CampaignStep.name => _buildNameStep(),
            _CampaignStep.template => _buildTemplateStep(),
            _CampaignStep.segment => _buildSegmentStep(),
            _CampaignStep.review => _buildReviewStep(),
          },
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = ['Name', 'Template', 'Segment', 'Review'];
    final currentIndex = _CampaignStep.values.indexOf(_currentStep);

    return Row(
      children: List.generate(steps.length, (i) {
        final isActive = i <= currentIndex;
        return Expanded(
          child: Column(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: isActive
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Text(
                  '${i + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isActive
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(steps[i],
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildNameStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Campaign Name',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            hintText: 'e.g., "Spring Outreach 2026"',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildTemplateStep() {
    if (_loadingTemplates) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_templates.isEmpty) {
      return Center(
        child: Column(
          children: [
            const Text('No templates available.'),
            const SizedBox(height: 8),
            const Text('Create a template first.'),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Template',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...List.generate(_templates.length, (i) {
          final template = _templates[i];
          final isSelected = template.id == _selectedTemplateId;
          return Card(
            color: isSelected
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            child: ListTile(
              title: Text(template.name),
              subtitle: Text(template.body,
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: isSelected
                  ? Icon(Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () {
                setState(() {
                  _selectedTemplateId = template.id;
                  _selectedTemplate = template;
                });
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSegmentStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Define Segment',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text('Select filters to target specific voters.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                )),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _selectedDistrict,
          decoration: const InputDecoration(
            labelText: 'District',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('All districts')),
            ..._districts
                .map((d) => DropdownMenuItem(value: d, child: Text(d))),
          ],
          onChanged: (v) => setState(() => _selectedDistrict = v),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _selectedParty,
          decoration: const InputDecoration(
            labelText: 'Party',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('All parties')),
            ..._parties
                .map((p) => DropdownMenuItem(value: p, child: Text(p))),
          ],
          onChanged: (v) => setState(() => _selectedParty = v),
        ),
        const SizedBox(height: 12),
        Text('Tags', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: _tags.map((tag) {
            final isSelected = _selectedTags.contains(tag);
            return FilterChip(
              label: Text(tag),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedTags.add(tag);
                  } else {
                    _selectedTags.remove(tag);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    final bool is10DLCApproved = _tenDlcStatus == 'approved';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Review Campaign',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        _reviewRow('Name', _nameController.text),
        _reviewRow('Template', _selectedTemplate?.name ?? ''),
        _reviewRow('District', _selectedDistrict ?? 'All'),
        _reviewRow('Party', _selectedParty ?? 'All'),
        _reviewRow('Tags',
            _selectedTags.isEmpty ? 'None' : _selectedTags.join(', ')),
        const SizedBox(height: 16),
        if (_selectedTemplate != null) ...[
          Text('Message Preview',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_selectedTemplate!.body),
          ),
        ],
        const SizedBox(height: 16),
        // 10DLC status check
        if (_loadingDlcStatus)
          const Row(
            children: [
              SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 8),
              Text('Checking 10DLC status...'),
            ],
          )
        else if (_tenDlcStatus != null && !is10DLCApproved)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning,
                        color: Theme.of(context)
                            .colorScheme
                            .onErrorContainer),
                    const SizedBox(width: 8),
                    Text(
                      '10DLC Not Approved',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context)
                            .colorScheme
                            .onErrorContainer,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'A2P campaign messaging requires 10DLC registration approval. '
                  'Current status: ${_tenDlcStatus ?? "unknown"}. '
                  'You can create the campaign now and launch it after approval.',
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    final bool is10DLCApproved = _tenDlcStatus == 'approved';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle,
                size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text('Campaign Created!',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('"${_createdCampaign!.name}" is ready.',
                style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 24),
            if (is10DLCApproved)
              FilledButton.icon(
                onPressed: _launchCampaign,
                icon: const Icon(Icons.rocket_launch),
                label: const Text('Launch Now'),
              )
            else
              Column(
                children: [
                  FilledButton.tonal(
                    onPressed: null,
                    child: const Text('Launch Now (10DLC required)'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '10DLC approval required before launching.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back to Campaigns'),
            ),
          ],
        ),
      ),
    );
  }
}
