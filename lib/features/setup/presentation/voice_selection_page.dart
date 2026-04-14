import 'package:antroph_mobile/core/onboarding/app_setup_storage_service.dart';
import 'package:antroph_mobile/core/responsive/responsive.dart';
import 'package:antroph_mobile/core/theme/theme_provider.dart';
import 'package:antroph_mobile/widgets/app_button.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class VoiceSelectionPage extends StatefulWidget {
  const VoiceSelectionPage({super.key});

  @override
  State<VoiceSelectionPage> createState() => _VoiceSelectionPageState();
}

class _VoiceSelectionPageState extends State<VoiceSelectionPage> {
  static const List<({String name, String tone, IconData icon})>
  _voices = <({String name, String tone, IconData icon})>[
    (name: 'Nova', tone: 'Bright and playful', icon: Icons.wb_sunny_outlined),
    (
      name: 'Atlas',
      tone: 'Confident and grounded',
      icon: Icons.public_outlined,
    ),
    (name: 'Luna', tone: 'Gentle and dreamy', icon: Icons.nights_stay_outlined),
    (
      name: 'Sage',
      tone: 'Calm and thoughtful',
      icon: Icons.self_improvement_outlined,
    ),
    (
      name: 'Echo',
      tone: 'Energetic and lively',
      icon: Icons.graphic_eq_outlined,
    ),
    (name: 'Milo', tone: 'Warm and friendly', icon: Icons.favorite_border),
  ];

  String? _selectedVoice;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _restoreVoice();
  }

  Future<void> _restoreVoice() async {
    final savedVoice = await AppSetupStorageService.getSelectedVoice();
    if (!mounted || savedVoice == null || savedVoice.isEmpty) return;
    setState(() => _selectedVoice = savedVoice);
  }

  Future<void> _continue() async {
    final selectedVoice = _selectedVoice;
    if (selectedVoice == null || _isSaving) return;

    setState(() => _isSaving = true);
    await AppSetupStorageService.saveSelectedVoice(selectedVoice);
    await AppSetupStorageService.markSetupCompleted();
    if (!mounted) return;
    context.go('/setup/welcome');
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
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xFF16191B), Color(0xFF0A0C0D)],
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
                      const _SetupHeader(
                        step: 'Step 2 of 2',
                        title: 'Select one of 6 voices',
                        subtitle:
                            'Choose the voice style Aura should use first. You can wire this to your backend later.',
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: ListView.separated(
                          itemCount: _voices.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final voice = _voices[index];
                            final isSelected = voice.name == _selectedVoice;
                            return _VoiceCard(
                              name: voice.name,
                              tone: voice.tone,
                              icon: voice.icon,
                              isSelected: isSelected,
                              onTap: () =>
                                  setState(() => _selectedVoice = voice.name),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: AppButton(
                          onPressed: _selectedVoice == null ? null : _continue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
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

class _VoiceCard extends StatelessWidget {
  const _VoiceCard({
    required this.name,
    required this.tone,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String name;
  final String tone;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : const Color(0xFF1B1D1F),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? Colors.white : Colors.white10,
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.black.withValues(alpha: 0.08)
                      : Colors.white10,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? Colors.black : Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    TypographyText(
                      name,
                      variant: TypographyVariant.body1,
                      color: isSelected ? Colors.black : Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    const SizedBox(height: 4),
                    TypographyText(
                      tone,
                      variant: TypographyVariant.body2,
                      color: isSelected ? Colors.black87 : Colors.white70,
                    ),
                  ],
                ),
              ),
              Icon(
                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isSelected ? Colors.black : Colors.white54,
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
