import 'package:eden_ui_flutter/eden_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/database.dart';
import '../../services/door_knock_service.dart';
import 'door_disposition_sheet.dart';
import 'note_input_widget.dart';
import 'survey_form_renderer.dart';

/// Main screen for at-the-door interaction.
///
/// Flow: disposition -> (if answered) sentiment -> survey -> notes -> save.
/// For non-answer dispositions (not_home, refused, moved), auto-saves and pops.
/// Returns [DoorKnockResult] via Navigator.pop.
class DoorKnockScreen extends ConsumerStatefulWidget {
  final String voterId;
  final String voterName;
  final String turfId;

  const DoorKnockScreen({
    super.key,
    required this.voterId,
    required this.voterName,
    required this.turfId,
  });

  @override
  ConsumerState<DoorKnockScreen> createState() => _DoorKnockScreenState();
}

/// Steps in the door knock flow after "answered" disposition.
enum _DoorKnockStep { disposition, sentiment, survey, notes }

class _DoorKnockScreenState extends ConsumerState<DoorKnockScreen> {
  _DoorKnockStep _currentStep = _DoorKnockStep.disposition;
  String? _doorStatus;
  double _sentiment = 3;
  SurveyForm? _activeSurveyForm;
  Map<String, dynamic> _surveyResponses = {};
  NoteData _noteData = const NoteData();
  bool _isSaving = false;
  bool _loadingForm = true;
  final _surveyRendererKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadActiveSurveyForm();
  }

  Future<void> _loadActiveSurveyForm() async {
    final service = ref.read(doorKnockServiceProvider);
    final form = await service.getActiveSurveyForm();
    if (mounted) {
      setState(() {
        _activeSurveyForm = form;
        _loadingForm = false;
      });
    }
  }

  Future<void> _onDispositionSelected(String status) async {
    setState(() => _doorStatus = status);

    // Non-answer dispositions: quick save and pop
    if (status != 'answered') {
      await _saveAndPop();
      return;
    }

    // Answered: advance to sentiment step
    setState(() => _currentStep = _DoorKnockStep.sentiment);
  }

  void _advanceStep() {
    setState(() {
      switch (_currentStep) {
        case _DoorKnockStep.sentiment:
          // Skip survey step if no active form
          if (_activeSurveyForm != null) {
            _currentStep = _DoorKnockStep.survey;
          } else {
            _currentStep = _DoorKnockStep.notes;
          }
        case _DoorKnockStep.survey:
          _currentStep = _DoorKnockStep.notes;
        default:
          break;
      }
    });
  }

  Future<void> _saveAndPop() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final service = ref.read(doorKnockServiceProvider);
      final result = await service.saveDoorKnockSession(
        DoorKnockSession(
          voterId: widget.voterId,
          turfId: widget.turfId,
          doorStatus: _doorStatus!,
          sentiment: _doorStatus == 'answered' ? _sentiment.round() : null,
          notes: _noteData.content,
          surveyResponses:
              _surveyResponses.isNotEmpty ? _surveyResponses : null,
          surveyFormId: _activeSurveyForm?.id,
          surveyFormVersion: _activeSurveyForm?.version,
          noteVisibility: _noteData.visibility,
        ),
      );

      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.voterName),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Step indicator (only for answered flow)
          if (_doorStatus == 'answered') _buildStepIndicator(theme),

          // Content area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildStepContent(),
            ),
          ),

          // Bottom action bar (only for answered flow after disposition)
          if (_doorStatus == 'answered' &&
              _currentStep != _DoorKnockStep.disposition)
            _buildBottomBar(theme),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(ThemeData theme) {
    final steps = <String>['Sentiment', 'Survey', 'Notes'];
    // Map current step to index (0-based, skipping disposition)
    final currentIndex = switch (_currentStep) {
      _DoorKnockStep.sentiment => 0,
      _DoorKnockStep.survey => 1,
      _DoorKnockStep.notes => 2,
      _ => 0,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Row(
        children: List.generate(steps.length, (i) {
          final isActive = i == currentIndex;
          final isCompleted = i < currentIndex;
          return Expanded(
            child: Row(
              children: [
                if (i > 0)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: isCompleted
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                    ),
                  ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive || isCompleted
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                    border: Border.all(
                      color: isActive || isCompleted
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: isCompleted
                      ? Icon(Icons.check,
                          size: 16, color: theme.colorScheme.onPrimary)
                      : Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isActive
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case _DoorKnockStep.disposition:
        return DoorDispositionSheet(onSelected: _onDispositionSelected);

      case _DoorKnockStep.sentiment:
        return _buildSentimentStep();

      case _DoorKnockStep.survey:
        return _buildSurveyStep();

      case _DoorKnockStep.notes:
        return NoteInputWidget(
          onChanged: (data) => _noteData = data,
        );
    }
  }

  Widget _buildSentimentStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How receptive was this voter?',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Rate from 1 (hostile) to 5 (very supportive)',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 24),
        Center(
          child: EdenRating(
            value: _sentiment,
            size: EdenRatingSize.lg,
            onChanged: (value) {
              setState(() => _sentiment = value);
            },
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            _sentimentLabel(_sentiment.round()),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ),
      ],
    );
  }

  String _sentimentLabel(int value) {
    switch (value) {
      case 1:
        return 'Hostile';
      case 2:
        return 'Unfavorable';
      case 3:
        return 'Neutral';
      case 4:
        return 'Favorable';
      case 5:
        return 'Very Supportive';
      default:
        return '';
    }
  }

  Widget _buildSurveyStep() {
    if (_loadingForm) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_activeSurveyForm == null) {
      return const EdenEmptyState(
        title: 'No survey available',
        description: 'No active survey form is available. Skipping.',
        icon: Icons.assignment_outlined,
      );
    }

    return SurveyFormRenderer(
      key: _surveyRendererKey,
      form: _activeSurveyForm!,
      onChanged: (responses) {
        _surveyResponses = responses;
      },
    );
  }

  Widget _buildBottomBar(ThemeData theme) {
    final isLastStep = _currentStep == _DoorKnockStep.notes ||
        (_currentStep == _DoorKnockStep.survey && _activeSurveyForm == null) ||
        (_currentStep == _DoorKnockStep.sentiment &&
            _activeSurveyForm == null);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_currentStep != _DoorKnockStep.sentiment)
              TextButton(
                onPressed: () {
                  setState(() {
                    switch (_currentStep) {
                      case _DoorKnockStep.notes:
                        _currentStep = _activeSurveyForm != null
                            ? _DoorKnockStep.survey
                            : _DoorKnockStep.sentiment;
                      case _DoorKnockStep.survey:
                        _currentStep = _DoorKnockStep.sentiment;
                      default:
                        break;
                    }
                  });
                },
                child: const Text('Back'),
              ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _isSaving
                  ? null
                  : isLastStep
                      ? _saveAndPop
                      : _advanceStep,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(isLastStep ? Icons.check : Icons.arrow_forward),
              label: Text(isLastStep ? 'Save & Next' : 'Continue'),
            ),
          ],
        ),
      ),
    );
  }
}

