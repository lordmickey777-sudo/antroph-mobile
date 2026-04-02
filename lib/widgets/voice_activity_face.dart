import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:antroph_mobile/features/home/models/expression_models.dart';
import 'package:antroph_mobile/features/story/models/mascot_model.dart';
import 'package:antroph_mobile/features/story/services/mascot_cache_service.dart';
import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

import '../core/analytics/posthog_service.dart';
import '../core/logging/logger.dart';
import '../core/security/rive_crypto_service.dart';

/// Drives a Rive face animation based on voice activity with expressive features.
/// Controls mouth movement, eye expressions, and head movements for lifelike animation.
class VoiceActivityFace extends StatefulWidget {
  const VoiceActivityFace({
    super.key,
    this.audioLevelStream,
    this.levelStream,
    this.expressionStream,
    this.mascotConfig,
    this.fallbackAsset = MascotConfig.defaultFallbackAsset,
    this.stateMachineName = MascotConfig.defaultStateMachine,
    this.threshold = 0.02,
    this.silenceDelay = const Duration(milliseconds: 300),
    this.fit = BoxFit.contain,
  }) : assert(audioLevelStream != null || levelStream != null);

  final Stream<double>? audioLevelStream;
  final Stream<double>? levelStream;
  final Stream<MascotExpressionEvent>? expressionStream;

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
  final RiveCryptoService _riveCryptoService = RiveCryptoService();

  StreamSubscription<double>? _levelSubscription;
  StreamSubscription<MascotExpressionEvent>? _expressionSubscription;
  Timer? _silenceTimer;
  Timer? _idleAnimationTimer;
  Timer? _smoothingTimer;
  Timer? _expressionResetTimer;
  _ResolvedRiveSource? _resolvedSource;
  int _sourceResolutionId = 0;
  int _artboardLoadId = 0;
  Artboard? _loadedArtboard;

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
  bool _expressionOverrideActive = false;

  final _random = math.Random();

  Stream<double> get _effectiveLevelStream =>
      widget.audioLevelStream ?? widget.levelStream ?? Stream<double>.empty();

  @override
  void initState() {
    super.initState();
    _resolvedSource = _buildSourceFallback();
    unawaited(_loadAndStoreArtboard(_resolvedSource!));
    unawaited(_resolveAndStoreRiveSource());
    _subscribeToLevelStream(_effectiveLevelStream);
    _subscribeToExpressionStream(widget.expressionStream);
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

    if (oldWidget.expressionStream != widget.expressionStream) {
      _expressionSubscription?.cancel();
      _expressionSubscription = null;
      _expressionResetTimer?.cancel();
      _expressionResetTimer = null;
      _expressionOverrideActive = false;
      _subscribeToExpressionStream(widget.expressionStream);
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

    _expressionResetTimer?.cancel();
    _expressionResetTimer = null;

    _levelSubscription?.cancel();
    _levelSubscription = null;

    _expressionSubscription?.cancel();
    _expressionSubscription = null;

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

  void _subscribeToExpressionStream(Stream<MascotExpressionEvent>? stream) {
    if (stream == null) return;
    _expressionSubscription = stream.listen(
      _handleMascotExpression,
      onError: (_) {},
      cancelOnError: false,
    );
  }

  void _handleAudioLevel(double rms) {
    if (rms >= widget.threshold) {
      _silenceTimer?.cancel();
      _silenceTimer = null;

      if (!_isSpeaking) {
        _isSpeaking = true;
        if (!_expressionOverrideActive) {
          _setEyeExpression(0); // Neutral/speaking expression
        }
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
    if (!_expressionOverrideActive) {
      _setEyeExpression(1); // Cute/happy expression when listening
    }
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

      if (_expressionOverrideActive) return;

      // Occasional cute expression when not speaking
      if (!_isSpeaking && _random.nextDouble() > 0.85) {
        _setEyeExpression(
          _random.nextInt(2),
        ); // Generic mascots only assume 0/1
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
    final maxExpression = _maxEyeExpressionAllowed().toDouble();
    final clamped = expression.toDouble().clamp(0.0, maxExpression);
    if (clamped != expression.toDouble()) {
      Log.i.d(
        '[VoiceActivityFace] clamped eyeExpression '
        'requested=$expression '
        'applied=${clamped.toInt()} '
        'max=${maxExpression.toInt()} '
        'element=${widget.mascotConfig?.id ?? 'fallback'}',
      );
    }
    if (input != null && (input.value - clamped).abs() > 0.01) {
      input.value = clamped;
    }
  }

  int _maxEyeExpressionAllowed() {
    final explicit = widget.mascotConfig?.maxEyeExpression;
    if (explicit != null) {
      return explicit.clamp(0, 10);
    }

    final source = _resolvedSource;
    if (source?.type == _RiveSourceType.asset &&
        source?.path == MascotConfig.defaultFallbackAsset) {
      return 3;
    }

    return 1;
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

  void _handleMascotExpression(MascotExpressionEvent event) {
    final eventElementId = event.riveElementId?.trim() ?? '';
    final currentElementId = widget.mascotConfig?.id.trim() ?? '';
    if (eventElementId.isNotEmpty &&
        currentElementId.isNotEmpty &&
        eventElementId != currentElementId) {
      return;
    }

    final params = _resolveExpressionParams(event.expression);
    _expressionOverrideActive = true;
    _expressionResetTimer?.cancel();
    _applyExpressionParams(params, event.intensity);

    if (event.durationMs <= 0) {
      _resetExpressionOverride();
      return;
    }

    _expressionResetTimer = Timer(
      Duration(milliseconds: event.durationMs),
      _resetExpressionOverride,
    );
  }

  void _applyExpressionParams(ExpressionParams params, double intensity) {
    if (params.eyeExpression != null) {
      _setEyeExpression(params.eyeExpression!);
    }
    if (params.eyeOpen != null) {
      _setEyeOpen(
        _scaleFromNeutral(params.eyeOpen!, intensity, neutral: 100.0),
      );
    }
    if (params.headTilt != null) {
      _setHeadTilt(params.headTilt! * intensity);
    }
    if (params.headBob != null) {
      _setHeadBob(params.headBob! * intensity);
    }
    if (params.blink == true) {
      _triggerBlink();
    }
    // Keep lip sync local and audio-driven to avoid semantic expression events
    // fighting the mouth animation timing.
    if (!_isSpeaking && params.mouthOpen != null) {
      _targetMouthValue = params.mouthOpen!.clamp(0.0, 100.0);
    }
  }

  void _resetExpressionOverride() {
    _expressionOverrideActive = false;
    final neutral = _lookupConfiguredExpression('neutral');
    if (neutral != null) {
      _applyExpressionParams(neutral, 1.0);
      if (_isSpeaking) {
        _setEyeExpression(0);
      }
      return;
    }

    _setEyeOpen(100.0);
    _setHeadTilt(0.0);
    if (_isSpeaking) {
      _setEyeExpression(0);
    } else {
      _setHeadBob(0.0);
      _setEyeExpression(1);
    }
  }

  ExpressionParams _resolveExpressionParams(String expression) {
    final configured = _lookupConfiguredExpression(expression);
    if (configured != null) {
      return configured;
    }

    switch (expression.trim().toLowerCase()) {
      case 'happy':
        return const ExpressionParams(
          eyeExpression: 1,
          headTilt: 4,
          headBob: 2,
        );
      case 'sad':
        return const ExpressionParams(
          eyeExpression: 0,
          eyeOpen: 72,
          headTilt: -4,
        );
      case 'excited':
        return const ExpressionParams(
          eyeExpression: 1,
          eyeOpen: 100,
          headBob: 4,
        );
      case 'surprised':
        return const ExpressionParams(eyeExpression: 1, eyeOpen: 100);
      case 'worried':
        return const ExpressionParams(
          eyeExpression: 0,
          eyeOpen: 84,
          headTilt: -2,
        );
      case 'thinking':
        return const ExpressionParams(eyeExpression: 0, headTilt: 6);
      case 'neutral':
      default:
        return const ExpressionParams(eyeExpression: 1, eyeOpen: 100);
    }
  }

  ExpressionParams? _lookupConfiguredExpression(String expression) {
    final key = expression.trim().toLowerCase();
    if (key.isEmpty) return null;

    final expressions = widget.mascotConfig?.expressions;
    if (expressions == null || expressions.isEmpty) return null;

    for (final entry in expressions.entries) {
      if (entry.key.trim().toLowerCase() == key) {
        return entry.value;
      }
    }
    return null;
  }

  double _scaleFromNeutral(
    double target,
    double intensity, {
    required double neutral,
  }) {
    return neutral + ((target - neutral) * intensity.clamp(0.0, 1.0));
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
    if (_resolvedSource == source && _loadedArtboard != null) return;

    Log.i.d(
      '[VoiceActivityFace] resolved source '
      'type=${source.type.name} '
      'path=${source.path ?? '<direct>'} '
      'stateMachine=${source.stateMachine} '
      'artboard=${source.artboard ?? '<main>'}',
    );

    if (_resolvedSource != source) {
      setState(() {
        _resetRiveInputs();
        _loadedArtboard = null;
        _resolvedSource = source;
      });
    }
    unawaited(_loadAndStoreArtboard(source));
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
      if (localFile.existsSync() &&
          !_riveCryptoService.isEncryptedCachePath(localAssetPath)) {
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

    var forceRefreshCache = false;

    final localAssetPath = mascot.localAssetPath?.trim() ?? '';
    if (localAssetPath.isNotEmpty) {
      final localFile = File(localAssetPath);
      if (await localFile.exists()) {
        final localSource = await _resolveLocalSource(
          mascot.id,
          localAssetPath,
          stateMachine: stateMachine,
          artboard: artboard,
        );
        if (localSource != null) return localSource;
        forceRefreshCache = true;
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
        final localSource = await _resolveLocalSource(
          mascot.id,
          file.path,
          stateMachine: stateMachine,
          artboard: artboard,
        );
        if (localSource != null) return localSource;
        forceRefreshCache = true;
      }
    }

    if (assetRef.isNotEmpty) {
      try {
        final cached = await _mascotCacheService.cacheMascot(
          mascot,
          forceRefresh: forceRefreshCache,
        );
        final localSource = await _resolveLocalSource(
          mascot.id,
          cached.path,
          stateMachine: stateMachine,
          artboard: artboard,
        );
        if (localSource != null) return localSource;
      } catch (error, stackTrace) {
        _reportRiveFallback(
          reason: 'cache_refresh_failed',
          elementId: mascot.id,
          extra: {'force_refresh': forceRefreshCache},
          error: error,
          stackTrace: stackTrace,
        );
        final cachedPath = await _mascotCacheService.getCachedPath(mascot.id);
        if (cachedPath != null) {
          final localSource = await _resolveLocalSource(
            mascot.id,
            cachedPath,
            stateMachine: stateMachine,
            artboard: artboard,
          );
          if (localSource != null) return localSource;
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

  Future<_ResolvedRiveSource?> _resolveLocalSource(
    String elementId,
    String localPath, {
    required String stateMachine,
    required String? artboard,
  }) async {
    if (_riveCryptoService.isEncryptedCachePath(localPath)) {
      try {
        final riveFile = await _riveCryptoService.loadRiveFile(
          localPath,
          elementId,
        );
        return _ResolvedRiveSource.direct(
          localPath,
          riveFile,
          stateMachine: stateMachine,
          artboard: artboard,
        );
      } catch (error, stackTrace) {
        _reportRiveFallback(
          reason: 'encrypted_cache_load_failed',
          elementId: elementId,
          extra: {'path': localPath},
          error: error,
          stackTrace: stackTrace,
        );
        try {
          await File(localPath).delete();
        } catch (_) {
          // Best effort cleanup only.
        }
        return null;
      }
    }

    final file = File(localPath);
    if (!await file.exists()) return null;
    return _ResolvedRiveSource.file(
      file.path,
      stateMachine: stateMachine,
      artboard: artboard,
    );
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
    final availableStateMachines = artboard.animations
        .whereType<StateMachine>()
        .map((machine) => machine.name)
        .toList();

    Log.i.d(
      '[VoiceActivityFace] init artboard=${artboard.name} '
      'requestedStateMachine=$configuredStateMachine '
      'availableStateMachines=${availableStateMachines.join(', ')}',
    );

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
      _reportRiveFallback(
        reason: 'missing_state_machine',
        elementId: widget.mascotConfig?.id ?? 'unknown',
        extra: {
          'state_machine': configuredStateMachine,
          'artboard': artboard.name,
          'available_state_machines': availableStateMachines.join('|'),
        },
      );
      return;
    }

    try {
      final added = artboard.addController(controller);
      if (!added) {
        _reportRiveFallback(
          reason: 'state_machine_attach_failed',
          elementId: widget.mascotConfig?.id ?? 'unknown',
          extra: {
            'state_machine': configuredStateMachine,
            'artboard': artboard.name,
          },
        );
        return;
      }

      // Try to find all available inputs
      _mouthOpenInput = controller.findInput<double>('mouthOpen') as SMINumber?;
      _eyeOpenInput = controller.findInput<double>('eyeOpen') as SMINumber?;
      _blinkInput = controller.findInput<bool>('blink') as SMITrigger?;
      _eyeExpressionInput =
          controller.findInput<double>('eyeExpression') as SMINumber?;
      _headTiltInput = controller.findInput<double>('headTilt') as SMINumber?;
      _headBobInput = controller.findInput<double>('headBob') as SMINumber?;

      // Initialize default values and immediately advance once to catch
      // broken backend state machines before the frame render loop does.
      _setEyeOpen(100.0); // Eyes open
      _setMouthOpen(0.0); // Mouth closed
      _setEyeExpression(1); // Cute expression
      artboard.advance(0);
    } catch (error, stackTrace) {
      artboard.removeController(controller);
      _resetRiveInputs();
      _reportRiveFallback(
        reason: 'state_machine_runtime_failed',
        elementId: widget.mascotConfig?.id ?? 'unknown',
        extra: {
          'state_machine': configuredStateMachine,
          'artboard': artboard.name,
          'available_state_machines': availableStateMachines.join('|'),
        },
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _reportRiveFallback({
    required String reason,
    required String elementId,
    Map<String, Object?> extra = const {},
    Object? error,
    StackTrace? stackTrace,
  }) {
    Log.i.w(
      '[VoiceActivityFace] $reason for element=$elementId${error == null ? '' : ' error=$error'}',
    );
    if (stackTrace != null) {
      Log.i.d(stackTrace.toString());
    }

    final properties = <String, Object>{
      'reason': reason,
      'element_id': elementId,
      for (final entry in extra.entries)
        if (entry.value != null) entry.key: entry.value.toString(),
    };
    unawaited(
      PostHogService.capture('rive_face_fallback', properties: properties),
    );
  }

  Future<void> _loadAndStoreArtboard(_ResolvedRiveSource source) async {
    final requestId = ++_artboardLoadId;

    try {
      final artboard = await _loadArtboard(source);
      if (!mounted || requestId != _artboardLoadId) return;
      setState(() {
        _loadedArtboard = artboard;
      });
    } catch (error, stackTrace) {
      _reportRiveFallback(
        reason: 'artboard_load_failed',
        elementId: widget.mascotConfig?.id ?? 'unknown',
        extra: {
          'source_type': source.type.name,
          'source_path': source.path,
          'state_machine': source.stateMachine,
          'artboard': source.artboard,
        },
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted || requestId != _artboardLoadId) return;
      setState(() {
        _loadedArtboard = null;
      });
    }
  }

  Future<Artboard> _loadArtboard(_ResolvedRiveSource source) async {
    final riveFile = await _loadRiveFile(source);
    final configuredArtboard = source.artboard?.trim() ?? '';
    final availableArtboards = riveFile.artboards.map((a) => a.name).toList();

    Log.i.d(
      '[VoiceActivityFace] loading artboard '
      'requested=${configuredArtboard.isEmpty ? '<main>' : configuredArtboard} '
      'available=${availableArtboards.join(', ')}',
    );

    Artboard? artboard;
    if (configuredArtboard.isNotEmpty) {
      artboard = riveFile.artboardByName(configuredArtboard);
      if (artboard == null) {
        _reportRiveFallback(
          reason: 'missing_artboard',
          elementId: widget.mascotConfig?.id ?? 'unknown',
          extra: {
            'artboard': configuredArtboard,
            'available_artboards': availableArtboards.join('|'),
          },
        );
      }
    }

    final resolvedArtboard = (artboard ?? riveFile.mainArtboard).instance();
    _onRiveInit(resolvedArtboard, source.stateMachine);
    return resolvedArtboard;
  }

  Future<RiveFile> _loadRiveFile(_ResolvedRiveSource source) {
    switch (source.type) {
      case _RiveSourceType.direct:
        return Future.value(source.file!);
      case _RiveSourceType.file:
        return RiveFile.file(source.path!);
      case _RiveSourceType.asset:
        return RiveFile.asset(source.path!);
    }
  }

  Widget _buildRiveWidget(_ResolvedRiveSource source, Artboard artboard) {
    final key = ValueKey(
      '${source.type.name}:${source.cacheKey}:${source.stateMachine}:${source.artboard ?? ''}',
    );
    return Rive(artboard: artboard, key: key, fit: widget.fit);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Debug: Trigger a blink on tap
        _triggerBlink();
      },
      child: _loadedArtboard == null
          ? const SizedBox()
          : _buildRiveWidget(
              _resolvedSource ?? _buildSourceFallback(),
              _loadedArtboard!,
            ),
    );
  }
}

enum _RiveSourceType { asset, file, direct }

class _ResolvedRiveSource {
  const _ResolvedRiveSource.asset(
    String this.path, {
    required this.stateMachine,
    this.artboard,
  }) : type = _RiveSourceType.asset,
       file = null,
       cacheKey = path;

  const _ResolvedRiveSource.file(
    String this.path, {
    required this.stateMachine,
    this.artboard,
  }) : type = _RiveSourceType.file,
       file = null,
       cacheKey = path;

  const _ResolvedRiveSource.direct(
    this.cacheKey,
    this.file, {
    required this.stateMachine,
    this.artboard,
  }) : type = _RiveSourceType.direct,
       path = null;

  final _RiveSourceType type;
  final String? path;
  final RiveFile? file;
  final String cacheKey;
  final String stateMachine;
  final String? artboard;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _ResolvedRiveSource &&
        other.type == type &&
        other.cacheKey == cacheKey &&
        other.stateMachine == stateMachine &&
        other.artboard == artboard;
  }

  @override
  int get hashCode => Object.hash(type, cacheKey, stateMachine, artboard);
}
