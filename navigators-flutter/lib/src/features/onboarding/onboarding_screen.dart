import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/volunteer_service.dart';
import 'legal_acknowledgment_step.dart';
import 'training_overview_step.dart';

/// Multi-step onboarding wizard using Stepper widget.
///
/// Steps:
/// 1. Welcome + Legal acknowledgment (Title 21-A Section 196-A)
/// 2. Training overview (preview of available materials)
/// 3. Complete (confirmation + start app)
///
/// Gates new users: shown instead of main app tabs until onboarding is complete.
class OnboardingScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _currentStep = 0;
  bool _legalAcknowledged = false;
  bool _isLoading = false;
  List<Map<String, dynamic>> _trainingMaterials = [];

  // Track if legal was already acknowledged (partial onboarding)
  bool _legalAlreadyDone = false;

  @override
  void initState() {
    super.initState();
    _checkExistingStatus();
    _loadTrainingMaterials();
  }

  Future<void> _checkExistingStatus() async {
    try {
      final service = ref.read(volunteerServiceProvider);
      final status = await service.getOnboardingStatus();
      final legalDone = status['legalAcknowledgedAt'] != null;
      if (mounted && legalDone) {
        setState(() {
          _legalAcknowledged = true;
          _legalAlreadyDone = true;
          _currentStep = 1; // Skip to training overview
        });
      }
    } catch (_) {
      // Continue from beginning
    }
  }

  Future<void> _loadTrainingMaterials() async {
    try {
      final service = ref.read(volunteerServiceProvider);
      final materials = await service.listTrainingMaterials();
      if (mounted) {
        setState(() => _trainingMaterials = materials);
      }
    } catch (_) {
      // Training materials not critical for onboarding flow
    }
  }

  Future<void> _handleLegalContinue() async {
    if (!_legalAcknowledged) return;

    setState(() => _isLoading = true);
    try {
      if (!_legalAlreadyDone) {
        final service = ref.read(volunteerServiceProvider);
        await service.acknowledgeLegal('21-A-196A-v1');
      }
      if (mounted) {
        setState(() {
          _currentStep = 1;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save acknowledgment: $e')),
        );
      }
    }
  }

  Future<void> _handleTrainingContinue() async {
    setState(() => _currentStep = 2);
  }

  Future<void> _handleComplete() async {
    setState(() => _isLoading = true);
    try {
      final service = ref.read(volunteerServiceProvider);
      await service.completeOnboarding();
      if (mounted) {
        widget.onComplete();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to complete onboarding: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Get Started'),
        automaticallyImplyLeading: false,
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: _isLoading
            ? null
            : () {
                switch (_currentStep) {
                  case 0:
                    _handleLegalContinue();
                  case 1:
                    _handleTrainingContinue();
                  case 2:
                    _handleComplete();
                }
              },
        onStepTapped: null, // Disable jumping between steps
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              children: [
                if (_currentStep == 2)
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _handleComplete,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check),
                    label: const Text('Start Using Navigators'),
                  )
                else
                  FilledButton(
                    onPressed: _isLoading
                        ? null
                        : (_currentStep == 0 && !_legalAcknowledged)
                            ? null
                            : details.onStepContinue,
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Continue'),
                  ),
              ],
            ),
          );
        },
        steps: [
          Step(
            title: const Text('Legal Acknowledgment'),
            subtitle: const Text('Voter data usage agreement'),
            content: LegalAcknowledgmentStep(
              acknowledged: _legalAcknowledged,
              onChanged: (value) =>
                  setState(() => _legalAcknowledged = value),
            ),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('Training Overview'),
            subtitle: const Text('Available resources'),
            content: TrainingOverviewStep(materials: _trainingMaterials),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('Ready to Go'),
            subtitle: const Text('Complete setup'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.celebration,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  "You're all set!",
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'You have completed the onboarding process. '
                  'You can now access all features of the Navigators app, '
                  'including voter outreach, events, and training materials.',
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
            isActive: _currentStep >= 2,
            state: StepState.indexed,
          ),
        ],
      ),
    );
  }
}
