import 'package:antroph_mobile/core/onboarding/app_setup_storage_service.dart';
import 'package:antroph_mobile/core/network/error_formatter.dart';
import 'package:antroph_mobile/core/responsive/responsive.dart';
import 'package:antroph_mobile/core/theme/theme_provider.dart';
import 'package:antroph_mobile/features/profile/data/profile_repository.dart';
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
  static const List<
    ({String key, String label, String emoji, String description})
  >
  _vibeOptions = [
    (
      key: 'feel_good',
      label: 'Feel-good & uplifting',
      emoji: '😊',
      description: 'Warm, happy stories that leave you smiling',
    ),
    (
      key: 'thrilling',
      label: 'Thrilling & intense',
      emoji: '🔥',
      description: 'Edge-of-your-seat stories with high stakes',
    ),
    (
      key: 'calm',
      label: 'Calm & soothing',
      emoji: '🌙',
      description: 'Gentle, peaceful stories for winding down',
    ),
    (
      key: 'funny',
      label: 'Funny & silly',
      emoji: '😂',
      description: 'Playful, laugh-out-loud moments and characters',
    ),
    (
      key: 'mysterious',
      label: 'Mysterious & surprising',
      emoji: '🕵️',
      description: 'Twists, secrets, and stories that make you think',
    ),
  ];

  final ProfileRepository _profileRepository = ProfileRepository();
  String? _selectedVibeKey;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _restoreSelection();
  }

  Future<void> _restoreSelection() async {
    final saved = await AppSetupStorageService.getSelectedVibe();
    if (mounted && saved != null && saved.isNotEmpty) {
      setState(() => _selectedVibeKey = saved);
    }

    try {
      final personalization = await _profileRepository.getPersonalization();
      if (!mounted || personalization == null || personalization.vibe.isEmpty) {
        return;
      }

      setState(() => _selectedVibeKey = personalization.vibe);
    } catch (_) {
      // Ignore restore failures and allow selection flow to continue.
    }
  }

  Future<void> _selectVibe(String vibeKey) async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
      _selectedVibeKey = vibeKey;
    });

    try {
      await _profileRepository.savePersonalization(vibe: vibeKey);
      await AppSetupStorageService.saveSelectedVibe(vibeKey);
      final hasCompletedSetup =
          await AppSetupStorageService.hasCompletedSetup();
      if (!mounted) return;

      if (hasCompletedSetup) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/home');
        }
        return;
      }

      context.go('/setup/voice');
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      final message = error is ApiError ? error.message : error.toString();
      showToast(context, message);
    }
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
                        step: 'Step 1 of 2',
                        title: 'What kind of stories are you in the mood for?',
                        subtitle:
                            'Pick one vibe. Aura will use it to personalize your home feed right away.',
                      ),
                      const SizedBox(height: 28),
                      Expanded(
                        child: GridView.builder(
                          itemCount: _vibeOptions.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                                childAspectRatio: 0.96,
                              ),
                          itemBuilder: (context, index) {
                            final option = _vibeOptions[index];
                            final isSelected = option.key == _selectedVibeKey;
                            final isBusy = _isSaving && isSelected;
                            return _VibeCard(
                              emoji: option.emoji,
                              title: option.label,
                              description: option.description,
                              isSelected: isSelected,
                              isBusy: isBusy,
                              onTap: () => _selectVibe(option.key),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 18),
                      TypographyText(
                        _isSaving
                            ? 'Saving your vibe...'
                            : 'Tap a vibe to continue. You can change this later from your profile.',
                        variant: TypographyVariant.body2,
                        color: Colors.white70,
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

class _VibeCard extends StatelessWidget {
  const _VibeCard({
    required this.emoji,
    required this.title,
    required this.description,
    required this.isSelected,
    required this.isBusy,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String description;
  final bool isSelected;
  final bool isBusy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: isBusy ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isSelected ? Colors.white : Colors.white12,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isSelected
                  ? const <Color>[Color(0xFFFFFFFF), Color(0xFFE6EEF2)]
                  : const <Color>[Color(0xFF232628), Color(0xFF151718)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(emoji, style: const TextStyle(fontSize: 26)),
                  const Spacer(),
                  if (isBusy)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isSelected ? Colors.black : Colors.white,
                      ),
                    )
                  else
                    Icon(
                      isSelected
                          ? Icons.check_circle
                          : Icons.arrow_forward_rounded,
                      color: isSelected ? Colors.black : Colors.white54,
                    ),
                ],
              ),
              const Spacer(),
              TypographyText(
                title,
                variant: TypographyVariant.body1,
                color: isSelected ? Colors.black : Colors.white,
                fontWeight: FontWeight.w700,
              ),
              const SizedBox(height: 8),
              TypographyText(
                description,
                variant: TypographyVariant.body2,
                color: isSelected ? Colors.black87 : Colors.white70,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetupHeader extends StatelessWidget {
  const _SetupHeader({
    required this.step,
    required this.title,
    required this.subtitle,
  });

  final String step;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: Colors.white.withValues(alpha: 0.08),
          ),
          child: TypographyText(
            step,
            variant: TypographyVariant.body2,
            color: Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 20),
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
