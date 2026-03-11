import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:antroph_mobile/features/story/models/mascot_model.dart';
import 'package:antroph_mobile/features/story/services/mascot_cache_service.dart';
import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

/// Drives a Rive face animation based on voice activity with expressive features.
/// Controls mouth movement, eye expressions, and head movements for lifelike animation.
class VoiceActivityFace extends StatefulWidget {
  const VoiceActivityFace({
    super.key,
    this.audioLevelStream,
    this.levelStream,
    this.mascotConfig,
    this.fallbackAsset = MascotConfig.defaultFallbackAsset,
    this.stateMachineName = MascotConfig.defaultStateMachine,
    this.threshold = 0.02,
    this.silenceDelay = const Duration(milliseconds: 300),
    this.fit = BoxFit.contain,
  }) : assert(audioLevelStream != null || levelStream != null);

  final Stream<double>? audioLevelStream;
  final Stream<double>? levelStream;

  /// Dynamic mascot configuration. When provided, this takes precedence over bundled assets.
  final MascotConfig? mascotConfig;

  /// Bundled fallback Rive asset when mascot loading fails.
  final String fallbackAsset;
  final String stateMachineName;

  /// RMS threshold above which we consider "speaking".
  final double threshold;

  /// How long to wait after falling below threshold before closing mouth.
  final Duration silenceDelay;

  final BoxFit fit;

  @override
  State<VoiceActivityFace> createState() => _VoiceActivityFaceState();
}

class _VoiceActivityFaceState extends State<VoiceActivityFace> {
  final MascotCacheService _mascotCacheService = MascotCacheService();

  StreamSubscription<double>? _levelSubscription;
  Timer? _silenceTimer;
  Timer? _idleAnimationTimer;
  Timer? _smoothingTimer;
  _ResolvedRiveSource? _resolvedSource;
  int _sourceResolutionId = 0;

  // Rive inputs - Try to find these in your state machine
  SMINumber? _mouthOpenInput; // 0-100: mouth openness
  SMINumber? _eyeOpenInput; // 0-100: eye openness
  SMITrigger? _blinkInput; // Trigger for blinks
  SMINumber? _eyeExpressionInput; // 0-3: expression type
  SMINumber? _headTiltInput; // -30 to 30: head tilt
  SMINumber? _headBobInput; // 0-10: vertical movement

  // Current state
  bool _isSpeaking = false;
  double _currentMouthValue = 0.0;
  double _targetMouthValue = 0.0;
  double _currentHeadBobValue = 0.0;
  double _targetHeadBobValue = 0.0;
  int _blinkCounter = 0;

  final _random = math.Random();

  Stream<double> get _effectiveLevelStream =>
      widget.audioLevelStream ?? widget.levelStream ?? Stream<double>.empty();

  @override
  void initState() {
    super.initState();
    _resolvedSource = _buildSourceFallback();
    unawaited(_resolveAndStoreRiveSource());
    _subscribeToLevelStream(_effectiveLevelStream);
    _startIdleAnimations();
    _startSmoothingLoop();
  }

  @override
  void didUpdateWidget(covariant VoiceActivityFace oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.audioLevelStream != widget.audioLevelStream ||
        oldWidget.levelStream != widget.levelStream) {
      _levelSubscription?.cancel();
      _levelSubscription = null;

      _silenceTimer?.cancel();
      _silenceTimer = null;
      _subscribeToLevelStream(_effectiveLevelStream);
    }

    if (_didSourceConfigurationChange(oldWidget)) {
      final fallbackSource = _buildSourceFallback();
      if (_resolvedSource == null) {
        setState(() {
          _resolvedSource = fallbackSource;
        });
      }
      unawaited(_resolveAndStoreRiveSource());
    }
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _silenceTimer = null;

    _idleAnimationTimer?.cancel();
    _idleAnimationTimer = null;

    _smoothingTimer?.cancel();
    _smoothingTimer = null;

    _levelSubscription?.cancel();
    _levelSubscription = null;

    super.dispose();
  }

  void _subscribeToLevelStream(Stream<double> stream) {
    _levelSubscription = stream.listen(
      _handleAudioLevel,
      onDone: () => _stopSpeaking(),
      onError: (_) => _stopSpeaking(),
      cancelOnError: false,
    );
  }

  void _handleAudioLevel(double rms) {
    if (rms >= widget.threshold) {
      _silenceTimer?.cancel();
      _silenceTimer = null;

      if (!_isSpeaking) {
        _isSpeaking = true;
        _setEyeExpression(0); // Neutral/speaking expression
      }

      final normalizedLevel =
          ((rms - widget.threshold) / (widget.threshold * 5)).clamp(0.0, 1.0);
      final easedLevel = Curves.easeOutCubic.transform(normalizedLevel);
      final baseOpenness = 18.0 + (easedLevel * 82.0);
      final variation = _random.nextDouble() * 6 - 3; // +/-3
      _targetMouthValue = (baseOpenness + variation).clamp(18.0, 100.0);
      _targetHeadBobValue = (1.2 + easedLevel * 3.8).clamp(0.0, 6.0);
    } else {
      _scheduleStopSpeaking();
    }
  }

  void _scheduleStopSpeaking() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(widget.silenceDelay, () {
      _stopSpeaking();
    });
  }

  void _stopSpeaking() {
    _isSpeaking = false;
    _targetMouthValue = 0.0;
    _targetHeadBobValue = 0.0;
    _setEyeExpression(1); // Cute/happy expression when listening
  }

  /// Smooth interpolation loop for natural movement
  void _startSmoothingLoop() {
    const fps = 60;
    const mouthEasingSpeed = 0.2;
    const headBobEasingSpeed = 0.16;

    _smoothingTimer = Timer.periodic(Duration(milliseconds: 1000 ~/ fps), (
      timer,
    ) {
      if (!mounted) return;

      // Smooth mouth movement
      _currentMouthValue +=
          (_targetMouthValue - _currentMouthValue) * mouthEasingSpeed;
      if ((_currentMouthValue - _targetMouthValue).abs() < 0.5) {
        _currentMouthValue = _targetMouthValue;
      }
      _setMouthOpen(_currentMouthValue);

      _currentHeadBobValue +=
          (_targetHeadBobValue - _currentHeadBobValue) * headBobEasingSpeed;
      if ((_currentHeadBobValue - _targetHeadBobValue).abs() < 0.1) {
        _currentHeadBobValue = _targetHeadBobValue;
      }
      _setHeadBob(_currentHeadBobValue);
    });
  }

  /// Idle animations: random blinks, subtle expressions
  void _startIdleAnimations() {
    _idleAnimationTimer = Timer.periodic(const Duration(milliseconds: 2500), (
      timer,
    ) {
      if (!mounted) return;

      _blinkCounter++;

      // Blink every 2-5 iterations (5-12.5 seconds)
      if (_blinkCounter >= 2 && _random.nextDouble() > 0.6) {
        _triggerBlink();
        _blinkCounter = 0;
      }

      // Occasional cute expression when not speaking
      if (!_isSpeaking && _random.nextDouble() > 0.85) {
        _setEyeExpression(_random.nextInt(3)); // Random cute expression
      }

      // Subtle head tilt variation
      if (!_isSpeaking && _random.nextDouble() > 0.7) {
        final tilt = (_random.nextDouble() - 0.5) * 10; // -5 to 5 degrees
        _setHeadTilt(tilt);
      }
    });
  }

  void _triggerBlink() {
    _blinkInput?.fire();
  }

  void _setMouthOpen(double value) {
    final input = _mouthOpenInput;
    if (input != null && (input.value - value).abs() > 0.5) {
      input.value = value.clamp(0.0, 100.0);
    }
  }

  void _setEyeOpen(double value) {
    final input = _eyeOpenInput;
    final clamped = value.clamp(0.0, 100.0);
    if (input != null && (input.value - clamped).abs() > 0.1) {
      input.value = clamped;
    }
  }

  void _setEyeExpression(int expression) {
    final input = _eyeExpressionInput;
    final clamped = expression.toDouble().clamp(0.0, 3.0);
    if (input != null && (input.value - clamped).abs() > 0.01) {
      input.value = clamped;
    }
  }

  void _setHeadTilt(double degrees) {
    final input = _headTiltInput;
    final clamped = degrees.clamp(-30.0, 30.0);
    if (input != null && (input.value - clamped).abs() > 0.1) {
      input.value = clamped;
    }
  }

  void _setHeadBob(double amount) {
    final input = _headBobInput;
    final clamped = amount.clamp(0.0, 10.0);
    if (input != null && (input.value - clamped).abs() > 0.1) {
      input.value = clamped;
    }
  }

  bool _didSourceConfigurationChange(VoiceActivityFace oldWidget) {
    return oldWidget.fallbackAsset.trim() != widget.fallbackAsset.trim() ||
        oldWidget.stateMachineName.trim() != widget.stateMachineName.trim() ||
        !_sameMascotConfig(oldWidget.mascotConfig, widget.mascotConfig);
  }

  bool _sameMascotConfig(MascotConfig? a, MascotConfig? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return a == b;

    return a.id == b.id &&
        a.name == b.name &&
        a.riveAssetUrl == b.riveAssetUrl &&
        a.stateMachine == b.stateMachine &&
        a.artboard == b.artboard &&
        a.fallbackAsset == b.fallbackAsset &&
        a.localAssetPath == b.localAssetPath;
  }

  Future<void> _resolveAndStoreRiveSource() async {
    final requestId = ++_sourceResolutionId;
    final source = await _resolveRiveSource();
    if (!mounted || requestId != _sourceResolutionId) return;
    if (_resolvedSource == source) return;

    setState(() {
      _resetRiveInputs();
      _resolvedSource = source;
    });
  }

  _ResolvedRiveSource _buildSourceFallback() {
    final mascot = widget.mascotConfig;
    final fallback = widget.fallbackAsset.trim().isEmpty
        ? MascotConfig.defaultFallbackAsset
        : widget.fallbackAsset.trim();
    final stateMachine =
        mascot?.effectiveStateMachine ?? widget.stateMachineName;
    final artboard = mascot?.artboard?.trim().isNotEmpty == true
        ? mascot!.artboard!.trim()
        : null;

    if (mascot == null) {
      return _ResolvedRiveSource.asset(
        fallback,
        stateMachine: stateMachine,
        artboard: artboard,
      );
    }

    final localAssetPath = mascot.localAssetPath?.trim() ?? '';
    if (localAssetPath.isNotEmpty) {
      final localFile = File(localAssetPath);
      if (localFile.existsSync()) {
        return _ResolvedRiveSource.file(
          localFile.path,
          stateMachine: stateMachine,
          artboard: artboard,
        );
      }
    }

    final assetRef = mascot.riveAssetUrl.trim();
    if (assetRef.startsWith('assets/')) {
      return _ResolvedRiveSource.asset(
        assetRef,
        stateMachine: stateMachine,
        artboard: artboard,
      );
    }

    if (_looksLikeLocalFilePath(assetRef)) {
      final file = assetRef.startsWith('file://')
          ? File(Uri.parse(assetRef).toFilePath())
          : File(assetRef);
      if (file.existsSync()) {
        return _ResolvedRiveSource.file(
          file.path,
          stateMachine: stateMachine,
          artboard: artboard,
        );
      }
    }

    return _ResolvedRiveSource.asset(
      mascot.effectiveFallbackAsset,
      stateMachine: stateMachine,
      artboard: artboard,
    );
  }

  Future<_ResolvedRiveSource> _resolveRiveSource() async {
    final mascot = widget.mascotConfig;
    final fallback = widget.fallbackAsset.trim().isEmpty
        ? MascotConfig.defaultFallbackAsset
        : widget.fallbackAsset.trim();
    final stateMachine =
        mascot?.effectiveStateMachine ?? widget.stateMachineName;
    final artboard = mascot?.artboard?.trim().isNotEmpty == true
        ? mascot!.artboard!.trim()
        : null;

    if (mascot == null) {
      return _ResolvedRiveSource.asset(fallback, stateMachine: stateMachine);
    }

    final localAssetPath = mascot.localAssetPath?.trim() ?? '';
    if (localAssetPath.isNotEmpty) {
      final localFile = File(localAssetPath);
      if (await localFile.exists()) {
        return _ResolvedRiveSource.file(
          localAssetPath,
          stateMachine: stateMachine,
          artboard: artboard,
        );
      }
    }

    final assetRef = mascot.riveAssetUrl.trim();
    if (assetRef.startsWith('assets/')) {
      return _ResolvedRiveSource.asset(
        assetRef,
        stateMachine: stateMachine,
        artboard: artboard,
      );
    }

    if (_looksLikeLocalFilePath(assetRef)) {
      final file = assetRef.startsWith('file://')
          ? File(Uri.parse(assetRef).toFilePath())
          : File(assetRef);
      if (await file.exists()) {
        return _ResolvedRiveSource.file(
          file.path,
          stateMachine: stateMachine,
          artboard: artboard,
        );
      }
    }

    if (assetRef.isNotEmpty) {
      try {
        final cached = await _mascotCacheService.cacheMascot(mascot);
        return _ResolvedRiveSource.file(
          cached.path,
          stateMachine: stateMachine,
          artboard: artboard,
        );
      } catch (_) {
        final cachedPath = await _mascotCacheService.getCachedPath(mascot.id);
        if (cachedPath != null) {
          return _ResolvedRiveSource.file(
            cachedPath,
            stateMachine: stateMachine,
            artboard: artboard,
          );
        }
      }
    }

    return _ResolvedRiveSource.asset(
      mascot.effectiveFallbackAsset,
      stateMachine: stateMachine,
      artboard: artboard,
    );
  }

  bool _looksLikeLocalFilePath(String value) {
    if (value.isEmpty) return false;
    return value.startsWith('/') ||
        value.startsWith('./') ||
        value.startsWith('../') ||
        value.startsWith('file://');
  }

  void _resetRiveInputs() {
    _mouthOpenInput = null;
    _eyeOpenInput = null;
    _blinkInput = null;
    _eyeExpressionInput = null;
    _headTiltInput = null;
    _headBobInput = null;
  }

  void _onRiveInit(Artboard artboard, String configuredStateMachine) {
    _resetRiveInputs();

    var controller = StateMachineController.fromArtboard(
      artboard,
      configuredStateMachine,
    );
    if (controller == null &&
        configuredStateMachine != widget.stateMachineName) {
      controller = StateMachineController.fromArtboard(
        artboard,
        widget.stateMachineName,
      );
    }
    if (controller == null &&
        widget.stateMachineName != MascotConfig.defaultStateMachine) {
      controller = StateMachineController.fromArtboard(
        artboard,
        MascotConfig.defaultStateMachine,
      );
    }

    if (controller == null) {
      debugPrint(
        '⚠️ State machine "$configuredStateMachine" not found in Rive file',
      );
      return;
    }

    artboard.addController(controller);

    // Try to find all available inputs
    _mouthOpenInput = controller.findInput<double>('mouthOpen') as SMINumber?;
    _eyeOpenInput = controller.findInput<double>('eyeOpen') as SMINumber?;
    _blinkInput = controller.findInput<bool>('blink') as SMITrigger?;
    _eyeExpressionInput =
        controller.findInput<double>('eyeExpression') as SMINumber?;
    _headTiltInput = controller.findInput<double>('headTilt') as SMINumber?;
    _headBobInput = controller.findInput<double>('headBob') as SMINumber?;

    // Debug: Print what inputs were found
    debugPrint('🎭 Rive inputs found:');
    debugPrint('  - mouthOpen: ${_mouthOpenInput != null ? "✓" : "✗"}');
    debugPrint('  - eyeOpen: ${_eyeOpenInput != null ? "✓" : "✗"}');
    debugPrint('  - blink: ${_blinkInput != null ? "✓" : "✗"}');
    debugPrint('  - eyeExpression: ${_eyeExpressionInput != null ? "✓" : "✗"}');
    debugPrint('  - headTilt: ${_headTiltInput != null ? "✓" : "✗"}');
    debugPrint('  - headBob: ${_headBobInput != null ? "✓" : "✗"}');

    // Initialize default values
    _setEyeOpen(100.0); // Eyes open
    _setMouthOpen(0.0); // Mouth closed
    _setEyeExpression(1); // Cute expression
  }

  Widget _buildRiveWidget(_ResolvedRiveSource source) {
    final key = ValueKey(
      '${source.type.name}:${source.path}:${source.stateMachine}:${source.artboard ?? ''}',
    );

    if (source.type == _RiveSourceType.file) {
      return RiveAnimation.file(
        source.path,
        key: key,
        artboard: source.artboard,
        onInit: (artboard) => _onRiveInit(artboard, source.stateMachine),
        fit: widget.fit,
      );
    }

    return RiveAnimation.asset(
      source.path,
      key: key,
      artboard: source.artboard,
      onInit: (artboard) => _onRiveInit(artboard, source.stateMachine),
      fit: widget.fit,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Debug: Trigger a blink on tap
        _triggerBlink();
      },
      child: _buildRiveWidget(_resolvedSource ?? _buildSourceFallback()),
    );
  }
}

enum _RiveSourceType { asset, file }

class _ResolvedRiveSource {
  const _ResolvedRiveSource.asset(
    this.path, {
    required this.stateMachine,
    this.artboard,
  }) : type = _RiveSourceType.asset;

  const _ResolvedRiveSource.file(
    this.path, {
    required this.stateMachine,
    this.artboard,
  }) : type = _RiveSourceType.file;

  final _RiveSourceType type;
  final String path;
  final String stateMachine;
  final String? artboard;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _ResolvedRiveSource &&
        other.type == type &&
        other.path == path &&
        other.stateMachine == stateMachine &&
        other.artboard == artboard;
  }

  @override
  int get hashCode => Object.hash(type, path, stateMachine, artboard);
}
