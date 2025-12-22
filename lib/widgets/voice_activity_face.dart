import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rive/rive.dart';

/// Drives a Rive face state machine input (eyeOpen) based on voice activity.
///
/// - If [levelStream] is provided: uses it (recommended, avoids opening mic twice).
/// - Otherwise: opens its own mic recorder and computes RMS from PCM16 bytes.
class VoiceActivityFace extends StatefulWidget {
  const VoiceActivityFace({
    super.key,
    this.assetPath = 'assets/antroph_face.riv',
    this.stateMachineName = 'FaceSM',
    this.eyeOpenInputName = 'eyeOpen',
    this.threshold = 0.02,
    this.silenceDelay = const Duration(milliseconds: 300),
    this.sampleRate = 16000,
    this.levelStream,
    this.fit = BoxFit.contain,
  });

  final String assetPath;
  final String stateMachineName;
  final String eyeOpenInputName;

  /// RMS threshold above which we consider "speaking".
  final double threshold;

  /// How long to wait after falling below threshold before closing eyes.
  final Duration silenceDelay;

  final int sampleRate;

  /// External audio level stream (0..1-ish RMS). Prefer this if your main
  /// voice controller already computes levels.
  final Stream<double>? levelStream;

  final BoxFit fit;

  @override
  State<VoiceActivityFace> createState() => _VoiceActivityFaceState();
}

class _VoiceActivityFaceState extends State<VoiceActivityFace> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();

  StreamController<Uint8List>? _micStreamController;
  StreamSubscription<Uint8List>? _micStreamSubscription;
  StreamSubscription<double>? _levelSubscription;

  Timer? _silenceTimer;

  /// Rive input
  SMIBool? _eyeOpenInput;

  /// Desired eye state (kept even before Rive loads)
  bool _targetEyeOpen = false;

  bool _recorderOpened = false;
  bool _startingRecorder = false;

  @override
  void initState() {
    super.initState();

    // Recommended mode: use an externally computed level stream.
    if (widget.levelStream != null) {
      _subscribeToLevelStream(widget.levelStream!);
    } else {
      unawaited(_initRecorder());
    }
  }

  @override
  void didUpdateWidget(covariant VoiceActivityFace oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.levelStream != widget.levelStream) {
      _levelSubscription?.cancel();
      _levelSubscription = null;

      _silenceTimer?.cancel();
      _silenceTimer = null;

      // If we now have a levelStream, stop recorder (if running) and use it.
      if (widget.levelStream != null) {
        unawaited(_stopRecorder());
        _subscribeToLevelStream(widget.levelStream!);
      } else {
        // Otherwise switch back to internal recorder.
        unawaited(_initRecorder());
      }
    }
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _silenceTimer = null;

    _micStreamSubscription?.cancel();
    _micStreamSubscription = null;

    _micStreamController?.close();
    _micStreamController = null;

    _levelSubscription?.cancel();
    _levelSubscription = null;

    unawaited(_stopRecorder());

    super.dispose();
  }

  Future<void> _initRecorder() async {
    // Prevent double-starts if widget rebuilds quickly.
    if (_startingRecorder || _recorderOpened) return;
    _startingRecorder = true;

    try {
      final permission = await Permission.microphone.request();
      if (!permission.isGranted) return;

      await _recorder.openRecorder();
      _recorderOpened = true;

      if (!mounted) return;

      await _startListening();
    } catch (_) {
      // swallow: permission denied / device busy / etc.
    } finally {
      _startingRecorder = false;
    }
  }

  Future<void> _startListening() async {
    if (!_recorderOpened) return;

    await _micStreamSubscription?.cancel();
    await _micStreamController?.close();

    _micStreamController = StreamController<Uint8List>();
    _micStreamSubscription = _micStreamController!.stream.listen(
      _handleMicChunk,
      onDone: () => _setEyeOpen(false),
      onError: (_) => _setEyeOpen(false),
      cancelOnError: false,
    );

    // This matches your API signature (expects StreamSink<Uint8List>).
    await _recorder.startRecorder(
      toStream: _micStreamController!.sink,
      codec: Codec.pcm16,
      numChannels: 1,
      sampleRate: widget.sampleRate,
      // bitRate is not needed for PCM16; leaving it out avoids oddities across platforms.
    );
  }

  Future<void> _stopRecorder() async {
    // Stop stream subscriptions first
    try {
      await _micStreamSubscription?.cancel();
    } catch (_) {}
    _micStreamSubscription = null;

    try {
      await _micStreamController?.close();
    } catch (_) {}
    _micStreamController = null;

    // Stop/close recorder
    try {
      await _recorder.stopRecorder();
    } catch (_) {}

    if (_recorderOpened) {
      try {
        await _recorder.closeRecorder();
      } catch (_) {}
      _recorderOpened = false;
    }
  }

  void _handleMicChunk(Uint8List bytes) {
    if (bytes.isEmpty) return;
    final rms = _computeRms(bytes);
    _handleAudioLevel(rms);
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

  double _computeRms(Uint8List buffer) {
    final sampleCount = buffer.lengthInBytes ~/ 2; // PCM16 => 2 bytes per sample
    if (sampleCount <= 0) return 0.0;

    final samples = buffer.buffer.asInt16List(buffer.offsetInBytes, sampleCount);

    double sumSquares = 0.0;
    for (final s in samples) {
      final normalized = s / 32768.0;
      sumSquares += normalized * normalized;
    }
    return math.sqrt(sumSquares / samples.length);
  }

  void _onRiveInit(Artboard artboard) {
    final controller = StateMachineController.fromArtboard(artboard, widget.stateMachineName);
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
      child: RiveAnimation.asset(widget.assetPath, onInit: _onRiveInit, fit: widget.fit),
    );
  }
}
