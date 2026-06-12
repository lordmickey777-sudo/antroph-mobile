import 'dart:async';
import 'dart:math' as math;

import 'package:antroph_mobile/core/network/error_formatter.dart';
import 'package:antroph_mobile/core/onboarding/app_setup_storage_service.dart';
import 'package:antroph_mobile/core/responsive/responsive.dart';
import 'package:antroph_mobile/core/theme/theme_provider.dart';
import 'package:antroph_mobile/features/profile/data/profile_repository.dart';
import 'package:antroph_mobile/features/setup/data/voice_option.dart';
import 'package:antroph_mobile/features/setup/data/voices_repository.dart';
import 'package:antroph_mobile/widgets/app_button.dart';
import 'package:antroph_mobile/widgets/toast.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

class VoiceSelectionPage extends StatefulWidget {
  const VoiceSelectionPage({super.key});

  @override
  State<VoiceSelectionPage> createState() => _VoiceSelectionPageState();
}

typedef _BrandedVoice = ({
  String name,
  String tone,
  String voiceId,
  List<Color> gradient,
});

class _VoiceSelectionPageState extends State<VoiceSelectionPage>
    with TickerProviderStateMixin {
  // Branded mobile voices mapped to their backend voice_id.
  // Gradients drive the orb, background tint, and strip accents.
  static const List<_BrandedVoice> _fallbackVoices = <_BrandedVoice>[
    (
      name: 'Nova',
      tone: 'Bright and playful',
      voiceId: 'shimmer',
      gradient: <Color>[Color(0xFFFFD36E), Color(0xFFFF6A88)],
    ),
    (
      name: 'Atlas',
      tone: 'Confident and grounded',
      voiceId: 'cedar',
      gradient: <Color>[Color(0xFF7FD8FF), Color(0xFF2E5BFF)],
    ),
    (
      name: 'Luna',
      tone: 'Gentle and dreamy',
      voiceId: 'marin',
      gradient: <Color>[Color(0xFFC7B8FF), Color(0xFF5B5AD6)],
    ),
    (
      name: 'Sage',
      tone: 'Calm and thoughtful',
      voiceId: 'sage',
      gradient: <Color>[Color(0xFFA8E6B1), Color(0xFF2F9E7B)],
    ),
    (
      name: 'Echo',
      tone: 'Energetic and lively',
      voiceId: 'coral',
      gradient: <Color>[Color(0xFFFF9BE4), Color(0xFF8A2BE2)],
    ),
    (
      name: 'Milo',
      tone: 'Warm and friendly',
      voiceId: 'ash',
      gradient: <Color>[Color(0xFFFFC7A8), Color(0xFFE94F6E)],
    ),
    (
      name: 'Alloy',
      tone: 'Versatile and clear',
      voiceId: 'alloy',
      gradient: <Color>[Color(0xFFE0E0E0), Color(0xFF757575)],
    ),
    (
      name: 'Ballad',
      tone: 'Melodic and engaging',
      voiceId: 'ballad',
      gradient: <Color>[Color(0xFFFFD700), Color(0xFFFFA000)],
    ),
    (
      name: 'Resonance',
      tone: 'Rich and resonant',
      voiceId: 'echo',
      gradient: <Color>[Color(0xFF303F9F), Color(0xFF1A237E)],
    ),
    (
      name: 'Verse',
      tone: 'Confident and expressive',
      voiceId: 'verse',
      gradient: <Color>[Color(0xFFFF8A65), Color(0xFFD84315)],
    ),
  ];

  final ProfileRepository _profileRepository = ProfileRepository();
  final VoicesRepository _voicesRepository = VoicesRepository();
  final AudioPlayer _player = AudioPlayer();

  late final AnimationController _idleController;

  int _selectedIndex = 0;
  bool _hasUserSelected = false;
  bool _isSaving = false;

  late List<_BrandedVoice> _voices = List<_BrandedVoice>.of(_fallbackVoices);
  Map<String, String> _previewUrls = <String, String>{};
  String? _playingVoiceId;
  bool _playerLoading = false;
  bool _audioSessionConfigured = false;
  StreamSubscription<PlayerState>? _playerSub;

  _BrandedVoice get _current => _voices[_safeSelectedIndex];

  int get _safeSelectedIndex {
    if (_voices.isEmpty) return 0;
    return _selectedIndex.clamp(0, _voices.length - 1);
  }

  @override
  void initState() {
    super.initState();
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
    _restoreVoice();
    _loadVoices();
    _playerSub = _player.playerStateStream.listen(_onPlayerState);
  }

  @override
  void dispose() {
    _idleController.dispose();
    _playerSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _restoreVoice() async {
    final savedVoice = await AppSetupStorageService.getSelectedVoice();
    final savedVoiceId = await AppSetupStorageService.getSelectedVoiceId();
    if (!mounted) return;
    final savedKey = _voiceLookupKey(savedVoiceId ?? savedVoice ?? '');
    if (savedKey.isEmpty) return;
    final index = _voices.indexWhere(
      (v) =>
          _voiceLookupKey(v.voiceId) == savedKey ||
          _voiceLookupKey(v.name) == savedKey,
    );
    if (index < 0) return;
    setState(() {
      _selectedIndex = index;
      _hasUserSelected = true;
    });
  }

  Future<void> _loadVoices() async {
    try {
      final result = await _voicesRepository.fetchVoices();
      if (!mounted) return;
      final map = <String, String>{};
      final backendVoices = <_BrandedVoice>[];
      final activeVoices = result.voices
          .where((voice) => voice.isActive && voice.voiceId.trim().isNotEmpty)
          .toList(growable: false);
      for (var i = 0; i < activeVoices.length; i++) {
        final v = activeVoices[i];
        backendVoices.add(_brandedVoiceFromOption(v, i));
        final url = _readyPreviewUrl(v);
        if (url != null && url.isNotEmpty) {
          map[v.voiceId.trim()] = url;
          map[_voiceLookupKey(v.voiceId)] = url;
          map[_voiceLookupKey(v.displayName)] = url;
        }
      }
      final nextVoices = backendVoices.isNotEmpty ? backendVoices : _voices;
      for (final voice in nextVoices) {
        final url = _resolvePreviewUrl(map, voice);
        if (url != null && url.isNotEmpty) {
          map[voice.voiceId] = url;
        }
      }
      final nextSelectedIndex = _nextSelectedIndex(
        nextVoices,
        selectedVoice: result.selectedVoice,
      );
      setState(() {
        _voices = nextVoices;
        _selectedIndex = nextSelectedIndex;
        _previewUrls = map;
      });
      debugPrint(
        '[VoiceSelection] loaded ${map.length} voice preview URLs for ${nextVoices.length} voices',
      );
    } catch (error) {
      debugPrint('[VoiceSelection] failed to load voice previews: $error');
      // Non-fatal: selection still works without previews.
    }
  }

  _BrandedVoice _brandedVoiceFromOption(VoiceOption option, int index) {
    final fallback = _fallbackFor(option.voiceId, option.displayName);
    final fallbackGradient =
        fallback?.gradient ??
        _fallbackVoices[index % _fallbackVoices.length].gradient;
    final description = option.description?.trim();
    final style = option.style?.trim();
    final gender = option.gender?.trim();
    return (
      name: option.displayName.trim().isNotEmpty
          ? option.displayName.trim()
          : fallback?.name ?? option.voiceId.trim(),
      tone: description?.isNotEmpty == true
          ? description!
          : style?.isNotEmpty == true
          ? style!
          : gender?.isNotEmpty == true
          ? gender!
          : fallback?.tone ?? 'Expressive and clear',
      voiceId: option.voiceId.trim(),
      gradient: fallbackGradient,
    );
  }

  _BrandedVoice? _fallbackFor(String voiceId, String displayName) {
    final idKey = _voiceLookupKey(voiceId);
    final nameKey = _voiceLookupKey(displayName);
    for (final voice in _fallbackVoices) {
      if (_voiceLookupKey(voice.voiceId) == idKey ||
          _voiceLookupKey(voice.name) == nameKey ||
          _voiceLookupKey(voice.name) == idKey ||
          _voiceLookupKey(voice.voiceId) == nameKey) {
        return voice;
      }
    }
    return null;
  }

  String? _readyPreviewUrl(VoiceOption option) {
    final url = option.previewAudioUrl?.trim();
    if (url == null || url.isEmpty) return null;
    final status = option.previewAudioStatus?.trim().toLowerCase() ?? '';
    if (status.isNotEmpty && status != 'ready') return null;
    return url;
  }

  int _nextSelectedIndex(
    List<_BrandedVoice> voices, {
    required String selectedVoice,
  }) {
    if (voices.isEmpty) return 0;
    final current = _voices.isEmpty ? null : _current;
    final keys = <String>[
      if (_hasUserSelected && current != null) _voiceLookupKey(current.voiceId),
      if (_hasUserSelected && current != null) _voiceLookupKey(current.name),
      _voiceLookupKey(selectedVoice),
    ].where((key) => key.isNotEmpty).toList(growable: false);

    for (final key in keys) {
      final index = voices.indexWhere(
        (voice) =>
            _voiceLookupKey(voice.voiceId) == key ||
            _voiceLookupKey(voice.name) == key,
      );
      if (index >= 0) return index;
    }
    return _selectedIndex.clamp(0, voices.length - 1);
  }

  String _voiceLookupKey(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  String? _resolvePreviewUrl(Map<String, String> map, _BrandedVoice voice) {
    return map[voice.voiceId] ??
        map[_voiceLookupKey(voice.voiceId)] ??
        map[_voiceLookupKey(voice.name)];
  }

  Future<void> _configureAudioSession() async {
    if (_audioSessionConfigured) return;
    try {
      final session = await AudioSession.instance;
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.defaultToSpeaker,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          avAudioSessionRouteSharingPolicy:
              AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: false,
        ),
      );
      await session.setActive(true);
      _audioSessionConfigured = true;
    } catch (error) {
      debugPrint('[VoiceSelection] audio session configure failed: $error');
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

  Future<void> _selectAndPreview(int index) async {
    if (_isSaving) return;
    final voice = _voices[index];
    final switching = index != _selectedIndex;

    if (switching) {
      HapticFeedback.selectionClick();
      setState(() {
        _selectedIndex = index;
        _hasUserSelected = true;
      });
    }

    final url = _resolvePreviewUrl(_previewUrls, voice);
    if (url == null || url.isEmpty) return;

    // Re-tapping the currently playing voice stops playback.
    if (!switching && _playingVoiceId == voice.voiceId && _player.playing) {
      await _player.stop();
      if (mounted) setState(() => _playingVoiceId = null);
      return;
    }

    setState(() {
      _playingVoiceId = voice.voiceId;
      _playerLoading = true;
    });

    try {
      await _configureAudioSession();
      await _player.stop();
      await _player.setUrl(url);
      if (!mounted) return;
      setState(() => _playerLoading = false);
      await _player.play();
    } catch (error) {
      debugPrint(
        '[VoiceSelection] failed to play ${voice.voiceId} preview: $error',
      );
      if (!mounted) return;
      setState(() {
        _playingVoiceId = null;
        _playerLoading = false;
      });
    }
  }

  Future<void> _continue() async {
    if (_isSaving || !_hasUserSelected) return;
    final selectedVoice = _current.name;

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
    await AppSetupStorageService.saveSelectedVoiceId(_current.voiceId);
    await AppSetupStorageService.markSetupCompleted();
    if (!mounted) return;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = AppPadding.form.of(context);
    final voice = _current;
    final isPlayingCurrent = _playingVoiceId == voice.voiceId;
    final hasPreview = _previewUrls[voice.voiceId]?.isNotEmpty == true;

    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        body: AnimatedContainer(
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.45),
              radius: 1.3,
              colors: <Color>[
                Color.lerp(
                  voice.gradient.first,
                  const Color(0xFF0A0C0D),
                  0.92,
                )!,
                const Color(0xFF07090A),
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: ContentWidth.form),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    24,
                    horizontalPadding,
                    20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _SetupHeader(
                        currentStep: 2,
                        totalSteps: 2,
                        title: 'Pick a voice for Aura',
                        subtitle: 'Tap the orb to hear a preview.',
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
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              _VoiceOrb(
                                gradient: voice.gradient,
                                idle: _idleController,
                                isPlaying: isPlayingCurrent && _player.playing,
                                isLoading: isPlayingCurrent && _playerLoading,
                                hasPreview: hasPreview,
                                onTap: () => _selectAndPreview(_selectedIndex),
                              ),
                              const SizedBox(height: 20),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 280),
                                transitionBuilder: (child, anim) =>
                                    FadeTransition(
                                      opacity: anim,
                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(0, 0.15),
                                          end: Offset.zero,
                                        ).animate(anim),
                                        child: child,
                                      ),
                                    ),
                                child: Column(
                                  key: ValueKey<String>(voice.name),
                                  children: <Widget>[
                                    TypographyText(
                                      voice.name,
                                      variant: TypographyVariant.h2,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    const SizedBox(height: 6),
                                    TypographyText(
                                      voice.tone,
                                      variant: TypographyVariant.body2,
                                      color: Colors.white.withValues(
                                        alpha: 0.72,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _VoiceStrip(
                        voices: _voices,
                        selectedIndex: _selectedIndex,
                        playingVoiceId: _playingVoiceId,
                        previewUrls: _previewUrls,
                        onSelect: _selectAndPreview,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: AppButton(
                          onPressed: (_isSaving || !_hasUserSelected)
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

class _VoiceOrb extends StatelessWidget {
  const _VoiceOrb({
    required this.gradient,
    required this.idle,
    required this.isPlaying,
    required this.isLoading,
    required this.hasPreview,
    required this.onTap,
  });

  final List<Color> gradient;
  final AnimationController idle;
  final bool isPlaying;
  final bool isLoading;
  final bool hasPreview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 230,
        height: 230,
        child: AnimatedBuilder(
          animation: idle,
          builder: (context, _) {
            final t = idle.value;
            final breathing = 1 + math.sin(t * 2 * math.pi) * 0.02;
            final playingPulse = isPlaying
                ? 1 + math.sin(t * math.pi * 8) * 0.035
                : 1.0;
            return Stack(
              alignment: Alignment.center,
              children: <Widget>[
                if (isPlaying) ..._buildRipples(t),
                Transform.scale(
                  scale: breathing * playingPulse,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 550),
                    curve: Curves.easeOut,
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: Alignment(
                          math.sin(t * 2 * math.pi) * 0.25,
                          math.cos(t * 2 * math.pi) * 0.25 - 0.15,
                        ),
                        radius: 0.95,
                        colors: <Color>[
                          gradient.first,
                          gradient.last,
                          Color.lerp(gradient.last, Colors.black, 0.55)!,
                        ],
                        stops: const <double>[0.0, 0.6, 1.0],
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: gradient.first.withValues(alpha: 0.18),
                          blurRadius: 38,
                          spreadRadius: 0,
                        ),
                        BoxShadow(
                          color: gradient.last.withValues(alpha: 0.12),
                          blurRadius: 60,
                          spreadRadius: -14,
                        ),
                      ],
                    ),
                    child: Align(
                      alignment: const Alignment(-0.35, -0.5),
                      child: Container(
                        width: 60,
                        height: 38,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(40),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              Colors.white.withValues(alpha: 0.5),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _OrbOverlay(
                  isPlaying: isPlaying,
                  isLoading: isLoading,
                  hasPreview: hasPreview,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildRipples(double t) {
    return <Widget>[
      for (int i = 0; i < 3; i++) _buildRipple((t + i / 3) % 1.0),
    ];
  }

  Widget _buildRipple(double t) {
    final size = 180 + t * 70;
    return IgnorePointer(
      child: Opacity(
        opacity: (1 - t).clamp(0.0, 1.0) * 0.45,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: gradient.first.withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbOverlay extends StatelessWidget {
  const _OrbOverlay({
    required this.isPlaying,
    required this.isLoading,
    required this.hasPreview,
  });

  final bool isPlaying;
  final bool isLoading;
  final bool hasPreview;

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (isLoading) {
      child = const SizedBox(
        key: ValueKey('loading'),
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
        ),
      );
    } else if (isPlaying) {
      child = const Icon(
        Icons.stop_rounded,
        key: ValueKey('stop'),
        color: Colors.black,
        size: 26,
      );
    } else {
      child = Icon(
        hasPreview ? Icons.play_arrow_rounded : Icons.volume_off_rounded,
        key: ValueKey(hasPreview ? 'play' : 'mute'),
        color: Colors.black,
        size: hasPreview ? 28 : 22,
      );
    }

    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            spreadRadius: -2,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: child,
      ),
    );
  }
}

class _VoiceStrip extends StatelessWidget {
  const _VoiceStrip({
    required this.voices,
    required this.selectedIndex,
    required this.playingVoiceId,
    required this.previewUrls,
    required this.onSelect,
  });

  final List<_BrandedVoice> voices;
  final int selectedIndex;
  final String? playingVoiceId;
  final Map<String, String> previewUrls;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: voices.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final voice = voices[index];
          return _VoicePill(
            voice: voice,
            isSelected: index == selectedIndex,
            isPlaying: playingVoiceId == voice.voiceId,
            hasPreview: previewUrls[voice.voiceId]?.isNotEmpty == true,
            onTap: () => onSelect(index),
          );
        },
      ),
    );
  }
}

class _VoicePill extends StatelessWidget {
  const _VoicePill({
    required this.voice,
    required this.isSelected,
    required this.isPlaying,
    required this.hasPreview,
    required this.onTap,
  });

  final _BrandedVoice voice;
  final bool isSelected;
  final bool isPlaying;
  final bool hasPreview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.08),
              width: isSelected ? 1.2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _PillOrb(
                gradient: voice.gradient,
                isSelected: isSelected,
                isPlaying: isPlaying,
              ),
              const SizedBox(width: 10),
              TypographyText(
                voice.name,
                variant: TypographyVariant.body2,
                fontSize: 13,
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.72),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
              if (!hasPreview) ...<Widget>[
                const SizedBox(width: 6),
                Icon(
                  Icons.volume_off_outlined,
                  size: 12,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PillOrb extends StatelessWidget {
  const _PillOrb({
    required this.gradient,
    required this.isSelected,
    required this.isPlaying,
  });

  final List<Color> gradient;
  final bool isSelected;
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.4),
          radius: 0.95,
          colors: <Color>[gradient.first, gradient.last],
        ),
        boxShadow: isSelected
            ? <BoxShadow>[
                BoxShadow(
                  color: gradient.first.withValues(alpha: 0.55),
                  blurRadius: 12,
                  spreadRadius: -2,
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: isPlaying
          ? const Icon(Icons.graphic_eq_rounded, size: 13, color: Colors.white)
          : null,
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
          child: Icon(Icons.arrow_back, size: 18, color: Colors.black),
        ),
      ),
    );
  }
}
