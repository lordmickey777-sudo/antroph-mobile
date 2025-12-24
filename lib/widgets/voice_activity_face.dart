import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

/// Drives a Rive face animation based on voice activity with expressive features.
/// Controls mouth movement, eye expressions, and head movements for lifelike animation.
class VoiceActivityFace extends StatefulWidget {
  const VoiceActivityFace({
    super.key,
    this.assetPath = 'assets/antroph_face.riv',
    this.stateMachineName = 'State Machine 1',
    this.threshold = 0.02,
    this.silenceDelay = const Duration(milliseconds: 300),
    required this.levelStream,
    this.fit = BoxFit.contain,
  });

  final String assetPath;
  final String stateMachineName;

  /// RMS threshold above which we consider "speaking".
  final double threshold;

  /// How long to wait after falling below threshold before closing mouth.
  final Duration silenceDelay;

  /// External audio level stream (0..1-ish RMS).
  final Stream<double> levelStream;

  final BoxFit fit;

  @override
  State<VoiceActivityFace> createState() => _VoiceActivityFaceState();
}

class _VoiceActivityFaceState extends State<VoiceActivityFace> {
  StreamSubscription<double>? _levelSubscription;
  Timer? _silenceTimer;
  Timer? _idleAnimationTimer;
  Timer? _smoothingTimer;

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

  @override
  void initState() {
    super.initState();
    _subscribeToLevelStream(widget.levelStream);
    _startIdleAnimations();
    _startSmoothingLoop();
  }

  @override
  void didUpdateWidget(covariant VoiceActivityFace oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.levelStream != widget.levelStream) {
      _levelSubscription?.cancel();
      _levelSubscription = null;

      _silenceTimer?.cancel();
      _silenceTimer = null;
      _subscribeToLevelStream(widget.levelStream);
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
      final variation = _random.nextDouble() * 15 - 7.5; // ±7.5
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

    _smoothingTimer = Timer.periodic(Duration(milliseconds: 1000 ~/ fps), (timer) {
      if (!mounted) return;

      // Smooth mouth movement
      _currentMouthValue += (_targetMouthValue - _currentMouthValue) * easingSpeed;
      if ((_currentMouthValue - _targetMouthValue).abs() < 0.5) {
        _currentMouthValue = _targetMouthValue;
      }
      _setMouthOpen(_currentMouthValue);
    });
  }

  /// Idle animations: random blinks, subtle expressions
  void _startIdleAnimations() {
    _idleAnimationTimer = Timer.periodic(const Duration(milliseconds: 2500), (timer) {
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

  void _onRiveInit(Artboard artboard) {
    final controller = StateMachineController.fromArtboard(
      artboard,
      widget.stateMachineName,
    );

    if (controller == null) {
      debugPrint('⚠️ State machine "${widget.stateMachineName}" not found in Rive file');
      return;
    }

    artboard.addController(controller);

    // Try to find all available inputs
    _mouthOpenInput = controller.findInput<double>('mouthOpen') as SMINumber?;
    _eyeOpenInput = controller.findInput<double>('eyeOpen') as SMINumber?;
    _blinkInput = controller.findInput<bool>('blink') as SMITrigger?;
    _eyeExpressionInput = controller.findInput<double>('eyeExpression') as SMINumber?;
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Debug: Trigger a blink on tap
        _triggerBlink();
      },
      child: RiveAnimation.asset(
        widget.assetPath,
        onInit: _onRiveInit,
        fit: widget.fit,
      ),
    );
  }
}
