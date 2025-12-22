import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

/// Drives a Rive face state machine input (eyeOpen) based on voice activity.
/// Requires an external RMS level stream from the active voice pipeline.
class VoiceActivityFace extends StatefulWidget {
  const VoiceActivityFace({
    super.key,
    this.assetPath = 'assets/antroph_face.riv',
    this.stateMachineName = 'FaceSM',
    this.eyeOpenInputName = 'eyeOpen',
    this.threshold = 0.02,
    this.silenceDelay = const Duration(milliseconds: 300),
    required this.levelStream,
    this.fit = BoxFit.contain,
  });

  final String assetPath;
  final String stateMachineName;
  final String eyeOpenInputName;

  /// RMS threshold above which we consider "speaking".
  final double threshold;

  /// How long to wait after falling below threshold before closing eyes.
  final Duration silenceDelay;

  /// External audio level stream (0..1-ish RMS). Prefer this if your main
  /// voice controller already computes levels.
  final Stream<double> levelStream;

  final BoxFit fit;

  @override
  State<VoiceActivityFace> createState() => _VoiceActivityFaceState();
}

class _VoiceActivityFaceState extends State<VoiceActivityFace> {
  StreamSubscription<double>? _levelSubscription;

  Timer? _silenceTimer;

  /// Rive input
  SMIBool? _eyeOpenInput;

  /// Desired eye state (kept even before Rive loads)
  bool _targetEyeOpen = false;

  @override
  void initState() {
    super.initState();
    _subscribeToLevelStream(widget.levelStream);
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

    _levelSubscription?.cancel();
    _levelSubscription = null;

    super.dispose();
  }

  void _subscribeToLevelStream(Stream<double> stream) {
    _levelSubscription = stream.listen(
      _handleAudioLevel,
      onDone: () => _setEyeOpen(false),
      onError: (_) => _setEyeOpen(false),
      cancelOnError: false,
    );
  }

  void _handleAudioLevel(double rms) {
    if (rms >= widget.threshold) {
      _silenceTimer?.cancel();
      _silenceTimer = null;
      _setEyeOpen(true);
    } else {
      _scheduleClose();
    }
  }

  void _scheduleClose() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(widget.silenceDelay, () {
      _setEyeOpen(false);
    });
  }

  /// IMPORTANT: Do NOT call setState here.
  /// Setting Rive inputs does not require rebuilding widgets.
  void _setEyeOpen(bool value) {
    _targetEyeOpen = value;

    final input = _eyeOpenInput;
    if (input == null) return;
    if (input.value == value) return;

    input.value = value;
  }

  void _onRiveInit(Artboard artboard) {
    final controller =
        StateMachineController.fromArtboard(artboard, widget.stateMachineName);
    if (controller == null) {
      // If this happens, your state machine name is wrong or not exported.
      return;
    }

    artboard.addController(controller);

    final input = controller.findInput<bool>(widget.eyeOpenInputName);
    if (input is SMIBool) {
      _eyeOpenInput = input;

      // Apply whatever the current target is (might have been updated before init).
      input.value = _targetEyeOpen;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _setEyeOpen(!(_eyeOpenInput?.value ?? false)),
      child: RiveAnimation.asset(
        widget.assetPath,
        onInit: _onRiveInit,
        fit: widget.fit,
      ),
    );
  }
}
