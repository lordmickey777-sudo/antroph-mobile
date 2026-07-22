import 'package:antroph_mobile/core/onboarding/app_setup_storage_service.dart';
import 'package:antroph_mobile/core/network/error_formatter.dart';
import 'package:antroph_mobile/core/responsive/responsive.dart';
import 'package:antroph_mobile/core/theme/theme_provider.dart';
import 'package:antroph_mobile/features/profile/data/profile_repository.dart';
import 'package:antroph_mobile/features/setup/data/voices_repository.dart';
import 'package:antroph_mobile/widgets/app_button.dart';
import 'package:antroph_mobile/widgets/toast.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class InterestSelectionPage extends StatefulWidget {
  const InterestSelectionPage({super.key});

  @override
  State<InterestSelectionPage> createState() => _InterestSelectionPageState();
}

class _InterestSelectionPageState extends State<InterestSelectionPage> {
  static const List<({String key, String label})> _vibeOptions = [
    (key: 'reduce_stress', label: 'Reduce stress'),
    (key: 'ease_anxiety', label: 'Ease anxiety'),
    (key: 'reflect_on_life', label: 'Reflect on life'),
    (key: 'build_better_habits', label: 'Build better habits'),
    (key: 'stay_disciplined', label: 'Stay disciplined'),
    (key: 'be_more_productive', label: 'Be more productive'),
    (key: 'spiritual', label: 'Spiritual'),
    (key: 'improve_relationships', label: 'Improve relationships'),
    (key: 'improve_communication', label: 'Improve communication'),
    (key: 'build_confidence', label: 'Build confidence'),
  ];

  static const int _maxSelections = 3;

  final ProfileRepository _profileRepository = ProfileRepository();
  final VoicesRepository _voicesRepository = VoicesRepository();
  final Set<String> _selectedVibeKeys = <String>{};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _redirectIfAlreadyOnboarded();
    _restoreSelection();
    // Warm the voices cache in the background so /setup/voice opens instantly.
    _voicesRepository.prefetch();
  }

  @override
  void reassemble() {
    super.reassemble();
    _redirectIfAlreadyOnboarded();
  }

  Future<void> _redirectIfAlreadyOnboarded() async {
    try {
      final profile = await _profileRepository.getMyProfile();
      if (!mounted || !profile.onboardingCompleted) return;
      context.go('/home');
    } catch (_) {
      // Ignore profile failures and allow the setup flow to continue.
    }
  }

  Future<void> _restoreSelection() async {
    final saved = await AppSetupStorageService.getSelectedVibe();
    if (mounted && saved != null && saved.isNotEmpty) {
      setState(() {
        _selectedVibeKeys
          ..clear()
          ..addAll(_splitKeys(saved));
      });
    }

    try {
      final personalization = await _profileRepository.getPersonalization();
      if (!mounted || personalization == null || personalization.vibe.isEmpty) {
        return;
      }

      setState(() {
        _selectedVibeKeys
          ..clear()
          ..addAll(_splitKeys(personalization.vibe));
      });
    } catch (_) {
      // Ignore restore failures and allow selection flow to continue.
    }
  }

  Iterable<String> _splitKeys(String raw) => raw
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .take(_maxSelections);

  void _toggleVibe(String vibeKey) {
    if (_isSaving) return;
    setState(() {
      if (_selectedVibeKeys.contains(vibeKey)) {
        _selectedVibeKeys.remove(vibeKey);
      } else if (_selectedVibeKeys.length < _maxSelections) {
        _selectedVibeKeys.add(vibeKey);
      }
    });
  }

  Future<void> _continue() async {
    if (_selectedVibeKeys.isEmpty || _isSaving) return;
    final joined = _selectedVibeKeys.join(',');

    setState(() => _isSaving = true);
    await AppSetupStorageService.saveSelectedVibe(joined);
    if (!mounted) return;

    final hasCompletedSetup = await AppSetupStorageService.hasCompletedSetup();
    if (!mounted) return;

    if (hasCompletedSetup) {
      try {
        await _profileRepository.savePersonalization(vibe: joined);
        await _profileRepository.completeOnboarding();
      } catch (error) {
        if (!mounted) return;
        setState(() => _isSaving = false);
        final message = error is ApiError ? error.message : error.toString();
        showToast(context, message);
        return;
      }
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
      return;
    }

    context.push('/setup/voice');
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = AppPadding.form.of(context);
    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0xFF151718), Color(0xFF0B0D0E)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: ContentWidth.form),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    32,
                    horizontalPadding,
                    24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _SetupHeader(
                        currentStep: 1,
                        totalSteps: 2,
                        title: 'What do you want to focus on?',
                        subtitle:
                            'Pick up to 3 goals. You can always update these later.',
                        onBack: (context.canPop() && !_isSaving)
                            ? () => context.pop()
                            : null,
                      ),
                      const SizedBox(height: 28),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final option in _vibeOptions)
                                _VibeChip(
                                  label: option.label,
                                  isSelected: _selectedVibeKeys.contains(
                                    option.key,
                                  ),
                                  isAtCapacity:
                                      _selectedVibeKeys.length >=
                                          _maxSelections &&
                                      !_selectedVibeKeys.contains(option.key),
                                  onTap: () => _toggleVibe(option.key),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: AppButton(
                          onPressed: _selectedVibeKeys.isEmpty || _isSaving
                              ? null
                              : _continue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            disabledBackgroundColor: Colors.white.withValues(
                              alpha: 0.18,
                            ),
                            disabledForegroundColor: Colors.white.withValues(
                              alpha: 0.6,
                            ),
                            shape: const StadiumBorder(),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const TypographyText(
                                  'Continue',
                                  variant: TypographyVariant.body1,
                                  color: Colors.black,
                                  fontWeight: FontWeight.w600,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VibeChip extends StatelessWidget {
  const _VibeChip({
    required this.label,
    required this.isSelected,
    required this.isAtCapacity,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final bool isAtCapacity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = isAtCapacity;
    final foreground = isSelected
        ? Colors.black
        : (disabled ? Colors.white38 : Colors.white);
    final background = isSelected ? Colors.white : const Color(0xFF1C1F21);
    final border = isSelected
        ? Colors.white
        : (disabled ? Colors.white10 : Colors.white12);

    return Opacity(
      opacity: disabled ? 0.6 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: disabled ? null : onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: border),
              color: background,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TypographyText(
                  label,
                  variant: TypographyVariant.body2,
                  fontSize: 13,
                  color: foreground,
                  fontWeight: FontWeight.w600,
                ),
                const SizedBox(width: 6),
                Icon(
                  isSelected ? Icons.check : Icons.add,
                  size: 14,
                  color: foreground,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SetupHeader extends StatelessWidget {
  const _SetupHeader({
    required this.currentStep,
    required this.totalSteps,
    required this.title,
    required this.subtitle,
    this.onBack,
  });

  final int currentStep;
  final int totalSteps;
  final String title;
  final String subtitle;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            if (onBack != null) ...<Widget>[
              _BackCircle(onTap: onBack!),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Row(
                children: <Widget>[
                  for (int i = 0; i < totalSteps; i++) ...<Widget>[
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        height: 4,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: i < currentStep
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                    if (i < totalSteps - 1) const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 54),
        TypographyText(
          title,
          variant: TypographyVariant.h3,
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        const SizedBox(height: 10),
        TypographyText(
          subtitle,
          variant: TypographyVariant.body2,
          color: Colors.white70,
        ),
      ],
    );
  }
}

class _BackCircle extends StatelessWidget {
  const _BackCircle({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 36,
          height: 36,
          child: Icon(Icons.arrow_back, size: 18, color: Colors.black),
        ),
      ),
    );
  }
}
