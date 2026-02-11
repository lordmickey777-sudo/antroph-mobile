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
  Future<_ResolvedRiveSource>? _sourceFuture;

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
  int _blinkCounter = 0;

  final _random = math.Random();

  Stream<double> get _effectiveLevelStream =>
      widget.audioLevelStream ?? widget.levelStream ?? Stream<double>.empty();

  @override
  void initState() {
    super.initState();
    _sourceFuture = _resolveRiveSource();
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

    if (oldWidget.mascotConfig != widget.mascotConfig ||
        oldWidget.fallbackAsset != widget.fallbackAsset ||
        oldWidget.stateMachineName != widget.stateMachineName) {
      _resetRiveInputs();
      _sourceFuture = _resolveRiveSource();
      if (mounted) {
        setState(() {});
      }
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

      // Map RMS to mouth openness (0-100)
      // Add some randomness for natural variation
      final baseOpenness = (rms / widget.threshold).clamp(0.3, 1.0) * 100;
      final variation = _random.nextDouble() * 15 - 7.5; // +/-7.5
      _targetMouthValue = (baseOpenness + variation).clamp(20.0, 100.0);

      // Subtle head bob when speaking
      _setHeadBob(5.0 + _random.nextDouble() * 3);
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
    _setHeadBob(0.0);
    _setEyeExpression(1); // Cute/happy expression when listening
  }

  /// Smooth interpolation loop for natural movement
  void _startSmoothingLoop() {
    const fps = 60;
    const easingSpeed = 0.25; // Higher = snappier, lower = smoother

    _smoothingTimer = Timer.periodic(Duration(milliseconds: 1000 ~/ fps), (
      timer,
    ) {
      if (!mounted) return;

      // Smooth mouth movement
      _currentMouthValue +=
          (_targetMouthValue - _currentMouthValue) * easingSpeed;
      if ((_currentMouthValue - _targetMouthValue).abs() < 0.5) {
        _currentMouthValue = _targetMouthValue;
      }
      _setMouthOpen(_currentMouthValue);
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
    if (input != null) {
      input.value = value.clamp(0.0, 100.0);
    }
  }

  void _setEyeExpression(int expression) {
    final input = _eyeExpressionInput;
    if (input != null) {
      input.value = expression.toDouble().clamp(0.0, 3.0);
    }
  }

  void _setHeadTilt(double degrees) {
    final input = _headTiltInput;
    if (input != null) {
      input.value = degrees.clamp(-30.0, 30.0);
    }
  }

  void _setHeadBob(double amount) {
    final input = _headBobInput;
    if (input != null) {
      input.value = amount.clamp(0.0, 10.0);
    }
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

  Widget _buildLoadingFace(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.white10 : Colors.black12;
    final border = isDark ? Colors.white24 : Colors.black12;
    final spinnerColor = isDark ? Colors.white70 : Colors.black54;

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        border: Border.all(color: border),
      ),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2, color: spinnerColor),
        ),
      ),
    );
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
      child: FutureBuilder<_ResolvedRiveSource>(
        future: _sourceFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return _buildLoadingFace(context);
          }

          final source =
              snapshot.data ??
              _ResolvedRiveSource.asset(
                widget.fallbackAsset,
                stateMachine: widget.stateMachineName,
              );
          return _buildRiveWidget(source);
        },
      ),
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
}
