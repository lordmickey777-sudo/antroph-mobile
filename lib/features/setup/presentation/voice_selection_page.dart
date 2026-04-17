import 'dart:async';

import 'package:antroph_mobile/core/network/error_formatter.dart';
import 'package:antroph_mobile/core/onboarding/app_setup_storage_service.dart';
import 'package:antroph_mobile/core/responsive/responsive.dart';
import 'package:antroph_mobile/core/theme/theme_provider.dart';
import 'package:antroph_mobile/features/profile/data/profile_repository.dart';
import 'package:antroph_mobile/features/setup/data/voices_repository.dart';
import 'package:antroph_mobile/widgets/app_button.dart';
import 'package:antroph_mobile/widgets/toast.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

class VoiceSelectionPage extends StatefulWidget {
  const VoiceSelectionPage({super.key});

  @override
  State<VoiceSelectionPage> createState() => _VoiceSelectionPageState();
}

typedef _BrandedVoice = ({
  String name,
  String tone,
  IconData icon,
  String voiceId,
});

class _VoiceSelectionPageState extends State<VoiceSelectionPage> {
  // Branded mobile voices mapped to their backend voice_id.
  // The backend preview_audio_url for each voice_id is fetched from GET /ai/voices.
  static const List<_BrandedVoice> _voices = <_BrandedVoice>[
    (
      name: 'Nova',
      tone: 'Bright and playful',
      icon: Icons.wb_sunny_outlined,
      voiceId: 'shimmer',
    ),
    (
      name: 'Atlas',
      tone: 'Confident and grounded',
      icon: Icons.public_outlined,
      voiceId: 'cedar',
    ),
    (
      name: 'Luna',
      tone: 'Gentle and dreamy',
      icon: Icons.nights_stay_outlined,
      voiceId: 'marin',
    ),
    (
      name: 'Sage',
      tone: 'Calm and thoughtful',
      icon: Icons.self_improvement_outlined,
      voiceId: 'sage',
    ),
    (
      name: 'Echo',
      tone: 'Energetic and lively',
      icon: Icons.graphic_eq_outlined,
      voiceId: 'coral',
    ),
    (
      name: 'Milo',
      tone: 'Warm and friendly',
      icon: Icons.favorite_border,
      voiceId: 'ash',
    ),
  ];

  final ProfileRepository _profileRepository = ProfileRepository();
  final VoicesRepository _voicesRepository = VoicesRepository();
  final AudioPlayer _player = AudioPlayer();

  String? _selectedVoice;
  bool _isSaving = false;

  Map<String, String> _previewUrls = <String, String>{};
  String? _playingVoiceId;
  bool _playerLoading = false;
  StreamSubscription<PlayerState>? _playerSub;

  @override
  void initState() {
    super.initState();
    _restoreVoice();
    _loadVoices();
    _playerSub = _player.playerStateStream.listen(_onPlayerState);
  }

  @override
  void dispose() {
    _playerSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _restoreVoice() async {
    final savedVoice = await AppSetupStorageService.getSelectedVoice();
    if (!mounted || savedVoice == null || savedVoice.isEmpty) return;
    setState(() => _selectedVoice = savedVoice);
  }

  Future<void> _loadVoices() async {
    try {
      final result = await _voicesRepository.fetchVoices();
      if (!mounted) return;
      final map = <String, String>{};
      for (final v in result.voices) {
        final url = v.previewAudioUrl;
        if (url != null && url.isNotEmpty) {
          map[v.voiceId] = url;
        }
      }
      setState(() => _previewUrls = map);
    } catch (_) {
      // Non-fatal: selection still works without previews.
    }
  }

  void _onPlayerState(PlayerState state) {
    if (!mounted) return;
    if (state.processingState == ProcessingState.completed) {
      setState(() {
        _playingVoiceId = null;
        _playerLoading = false;
      });
    }
  }

  Future<void> _onVoiceTap(_BrandedVoice voice) async {
    setState(() => _selectedVoice = voice.name);

    final url = _previewUrls[voice.voiceId];
    if (url == null || url.isEmpty) {
      // No preview available — selection still works.
      return;
    }

    // Re-tapping the currently playing voice stops playback.
    if (_playingVoiceId == voice.voiceId && _player.playing) {
      await _player.stop();
      if (mounted) setState(() => _playingVoiceId = null);
      return;
    }

    setState(() {
      _playingVoiceId = voice.voiceId;
      _playerLoading = true;
    });

    try {
      await _player.stop();
      await _player.setUrl(url);
      if (!mounted) return;
      setState(() => _playerLoading = false);
      await _player.play();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _playingVoiceId = null;
        _playerLoading = false;
      });
    }
  }

  Future<void> _continue() async {
    final selectedVoice = _selectedVoice;
    if (selectedVoice == null || _isSaving) return;

    final savedVibe = await AppSetupStorageService.getSelectedVibe();
    if (!mounted) return;
    if (savedVibe == null || savedVibe.isEmpty) {
      showToast(context, 'Please choose a goal first.');
      if (context.canPop()) context.pop();
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _profileRepository.savePersonalization(vibe: savedVibe);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      final message = error is ApiError ? error.message : error.toString();
      showToast(context, message);
      return;
    }

    await _player.stop();
    await AppSetupStorageService.saveSelectedVoice(selectedVoice);
    final selected = _voices.firstWhere(
      (v) => v.name == selectedVoice,
      orElse: () => _voices.first,
    );
    await AppSetupStorageService.saveSelectedVoiceId(selected.voiceId);
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
                      _SetupHeader(
                        currentStep: 2,
                        totalSteps: 2,
                        title: 'Select one of 6 voices',
                        subtitle:
                            'Tap a voice to hear a quick preview, then pick the one you like best.',
                        onBack: _isSaving
                            ? null
                            : () {
                                if (context.canPop()) {
                                  context.pop();
                                } else {
                                  context.go('/setup/interests');
                                }
                              },
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
                            final isPlaying = _playingVoiceId == voice.voiceId;
                            final hasPreview =
                                _previewUrls[voice.voiceId]?.isNotEmpty == true;
                            return _VoiceCard(
                              name: voice.name,
                              tone: voice.tone,
                              icon: voice.icon,
                              isSelected: isSelected,
                              isPlaying: isPlaying,
                              isLoading: isPlaying && _playerLoading,
                              hasPreview: hasPreview,
                              onTap: () => _onVoiceTap(voice),
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
    required this.isPlaying,
    required this.isLoading,
    required this.hasPreview,
    required this.onTap,
  });

  final String name;
  final String tone;
  final IconData icon;
  final bool isSelected;
  final bool isPlaying;
  final bool isLoading;
  final bool hasPreview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = isSelected ? Colors.black : Colors.white;
    final fadedForeground = isSelected ? Colors.black54 : Colors.white54;
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
                child: Icon(icon, color: foreground),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    TypographyText(
                      name,
                      variant: TypographyVariant.body1,
                      color: foreground,
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
              if (hasPreview) ...<Widget>[
                _PreviewIndicator(
                  isPlaying: isPlaying,
                  isLoading: isLoading,
                  color: foreground,
                ),
                const SizedBox(width: 10),
              ] else ...<Widget>[
                Icon(Icons.volume_off_outlined, size: 18, color: fadedForeground),
                const SizedBox(width: 10),
              ],
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

class _PreviewIndicator extends StatelessWidget {
  const _PreviewIndicator({
    required this.isPlaying,
    required this.isLoading,
    required this.color,
  });

  final bool isPlaying;
  final bool isLoading;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      );
    }
    return Icon(
      isPlaying ? Icons.stop_circle_outlined : Icons.play_circle_outline,
      color: color,
      size: 26,
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
        const SizedBox(height: 24),
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
          child: Icon(
            Icons.arrow_back,
            size: 18,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}
