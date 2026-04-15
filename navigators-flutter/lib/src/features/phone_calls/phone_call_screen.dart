import 'package:eden_ui_flutter/eden_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../database/database.dart';
import '../../services/phone_call_service.dart';
import '../../services/voter_service.dart';
import '../door_knocking/note_input_widget.dart';
import 'call_disposition_sheet.dart';
import 'call_script_widget.dart';

/// Main screen for phone call interaction.
///
/// Flow: launch dialer -> show script (calling step) -> "Call Ended" ->
/// disposition -> (if answered) sentiment -> notes -> save.
/// For non-answered dispositions (voicemail, no_answer, refused, busy),
/// auto-saves and pops. Returns [PhoneCallResult] via Navigator.pop.
class PhoneCallScreen extends ConsumerStatefulWidget {
  final String voterId;
  final String voterName;
  final String voterPhone;
  final String turfId;

  const PhoneCallScreen({
    super.key,
    required this.voterId,
    required this.voterName,
    required this.voterPhone,
    required this.turfId,
  });

  @override
  ConsumerState<PhoneCallScreen> createState() => _PhoneCallScreenState();
}

/// Steps in the phone call flow.
enum _PhoneCallStep { calling, disposition, sentiment, notes }

class _PhoneCallScreenState extends ConsumerState<PhoneCallScreen> {
  _PhoneCallStep _currentStep = _PhoneCallStep.calling;
  String? _callStatus;
  double _sentiment = 3;
  NoteData _noteData = const NoteData();
  bool _isSaving = false;
  CallScript? _activeScript;
  bool _loadingScript = true;

  @override
  void initState() {
    super.initState();
    _loadActiveCallScript();
    _launchDialer();
  }

  Future<void> _loadActiveCallScript() async {
    final service = ref.read(phoneCallServiceProvider);
    final script = await service.getActiveCallScript();
    if (mounted) {
      setState(() {
        _activeScript = script;
        _loadingScript = false;
      });
    }
  }

  Future<void> _launchDialer() async {
    try {
      final uri = Uri.parse('tel:${widget.voterPhone}');
      // canLaunchUrl returns false on iOS simulator; proceed regardless.
      if (kDebugMode || await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Non-fatal: dialer launch failure should not block disposition flow.
      debugPrint('Failed to launch dialer: $e');
    }
    // Dialer launched (or failed silently). Screen remains for script display.
  }

  void _onCallEnded() {
    setState(() => _currentStep = _PhoneCallStep.disposition);
  }

  Future<void> _onDispositionSelected(String status) async {
    setState(() => _callStatus = status);

    // Non-answered dispositions: quick save and pop
    if (status != 'answered') {
      await _saveAndPop();
      return;
    }

    // Answered: advance to sentiment step
    setState(() => _currentStep = _PhoneCallStep.sentiment);
  }

  void _advanceStep() {
    setState(() {
      switch (_currentStep) {
        case _PhoneCallStep.sentiment:
          _currentStep = _PhoneCallStep.notes;
        default:
          break;
      }
    });
  }

  Future<void> _saveAndPop() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final service = ref.read(phoneCallServiceProvider);
      final result = await service.savePhoneCallSession(
        PhoneCallSession(
          voterId: widget.voterId,
          turfId: widget.turfId,
          callStatus: _callStatus!,
          sentiment: _callStatus == 'answered' ? _sentiment.round() : null,
          notes: _noteData.content,
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

    return Semantics(
      identifier: 'phone-call-screen',
      explicitChildNodes: true,
      child: Scaffold(
      appBar: AppBar(
        title: Text(widget.voterName),
        leading: Semantics(
          identifier: 'phone-call-close-btn',
          button: true,
          child: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      body: Column(
        children: [
          // Step indicator (only for answered flow after disposition)
          if (_callStatus == 'answered') _buildStepIndicator(theme),

          // Content area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildStepContent(),
            ),
          ),

          // Bottom action bar
          _buildBottomBar(theme),
        ],
      ),
      ),
    );
  }

  Widget _buildStepIndicator(ThemeData theme) {
    final steps = <String>['Sentiment', 'Notes'];
    final currentIndex = switch (_currentStep) {
      _PhoneCallStep.sentiment => 0,
      _PhoneCallStep.notes => 1,
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
      case _PhoneCallStep.calling:
        return _buildCallingStep();

      case _PhoneCallStep.disposition:
        return CallDispositionSheet(onSelected: _onDispositionSelected);

      case _PhoneCallStep.sentiment:
        return _buildSentimentStep();

      case _PhoneCallStep.notes:
        return NoteInputWidget(
          onChanged: (data) => _noteData = data,
        );
    }
  }

  Widget _buildCallingStep() {
    final voterAsync = ref.watch(voterDetailProvider(widget.voterId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Phone status banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.green.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.phone_in_talk, color: Colors.green, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Calling ${widget.voterName}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.green.shade800,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.voterPhone,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.green.shade600,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Call script
        if (_loadingScript)
          const Center(child: CircularProgressIndicator())
        else
          voterAsync.when(
            loading: () => CallScriptWidget(
              script: _activeScript,
              voterContext: VoterScriptContext(
                firstName: widget.voterName.split(' ').first,
                lastName: widget.voterName.split(' ').last,
                party: '',
                address: '',
              ),
            ),
            error: (_, _) => CallScriptWidget(
              script: _activeScript,
              voterContext: VoterScriptContext(
                firstName: widget.voterName.split(' ').first,
                lastName: widget.voterName.split(' ').last,
                party: '',
                address: '',
              ),
            ),
            data: (voter) => CallScriptWidget(
              script: _activeScript,
              voterContext: VoterScriptContext(
                firstName: voter.firstName,
                lastName: voter.lastName,
                party: _partyFullName(voter.party),
                address: voter.residenceAddress,
              ),
            ),
          ),
      ],
    );
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
          child: Semantics(
            identifier: 'phone-call-sentiment-rating',
            slider: true,
            child: EdenRating(
              value: _sentiment,
              size: EdenRatingSize.lg,
              onChanged: (value) {
                setState(() => _sentiment = value);
              },
            ),
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

  Widget _buildBottomBar(ThemeData theme) {
    // Calling step: show "Call Ended" button
    if (_currentStep == _PhoneCallStep.calling) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            child: Semantics(
              identifier: 'phone-call-ended-btn',
              button: true,
              child: FilledButton.icon(
                onPressed: _onCallEnded,
                icon: const Icon(Icons.call_end),
                label: const Text('Call Ended'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Disposition step: no bottom bar (cards handle selection)
    if (_currentStep == _PhoneCallStep.disposition) {
      return const SizedBox.shrink();
    }

    // Sentiment/Notes: Back + Continue/Save
    final isLastStep = _currentStep == _PhoneCallStep.notes;

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
            if (_currentStep != _PhoneCallStep.sentiment)
              Semantics(
                identifier: 'phone-call-back-btn',
                button: true,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      switch (_currentStep) {
                        case _PhoneCallStep.notes:
                          _currentStep = _PhoneCallStep.sentiment;
                        default:
                          break;
                      }
                    });
                  },
                  child: const Text('Back'),
                ),
              ),
            const Spacer(),
            Semantics(
              identifier: isLastStep
                  ? 'phone-call-save-btn'
                  : 'phone-call-continue-btn',
              button: true,
              child: FilledButton.icon(
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
            ),
          ],
        ),
      ),
    );
  }

  static String _partyFullName(String code) {
    switch (code.toUpperCase()) {
      case 'D':
        return 'Democrat';
      case 'R':
        return 'Republican';
      case 'G':
        return 'Green';
      case 'L':
        return 'Libertarian';
      case 'NL':
        return 'No Party';
      default:
        return code;
    }
  }
}
