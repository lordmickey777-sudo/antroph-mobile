import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';

/// Interface for streaming PCM audio chunks.
abstract class AudioChunkPlayer {
  Future<void> addChunk(
    Uint8List bytes, {
    int sampleRate,
    int bufferSize,
    bool interleaved,
    VoidCallback? onFinished,
  });

  Future<void> stop({bool notifyFinished = true});
  Future<void> pause();
  Future<void> resume();
  Future<void> dispose();
}

AudioChunkPlayer createAudioChunkPlayer() {
  if (Platform.isAndroid) return AndroidAudioTrackPlayer();
  if (Platform.isIOS) return IOSAudioTrackPlayer();
  return PcmAudioPlayer();
}

/// Streams PCM16 audio into a FlutterSoundPlayer (used on non-Android).
class PcmAudioPlayer implements AudioChunkPlayer {
  FlutterSoundPlayer _player = FlutterSoundPlayer();
  Future<void>? _startFuture;
  bool _stopped = true;
  VoidCallback? _onFinished;
  bool _finishedNotified = false;

  bool get isPlaying => _player.isPlaying;

  @override
  Future<void> addChunk(
    Uint8List bytes, {
    int sampleRate = 16000,
    int bufferSize = 4096,
    bool interleaved = true,
    VoidCallback? onFinished,
  }) async {
    _onFinished ??= onFinished;
    try {
      _startFuture ??= _start(
        sampleRate: sampleRate,
        bufferSize: bufferSize,
        interleaved: interleaved,
      );
      await _startFuture;
    } catch (_) {
      // Reset the player and retry once if start failed (common on Android).
      await _resetPlayer();
      _startFuture = _start(
        sampleRate: sampleRate,
        bufferSize: bufferSize,
        interleaved: interleaved,
      );
      await _startFuture;
    }
    _player.uint8ListSink?.add(bytes);
  }

  @override
  Future<void> stop({bool notifyFinished = true}) async {
    if (_stopped) return;
    await _resetPlayer();
    if (notifyFinished) {
      _notifyFinished();
    }
  }

  @override
  Future<void> pause() async {
    if (_stopped) return;
    await _player.pausePlayer();
  }

  @override
  Future<void> resume() async {
    if (_stopped) return;
    await _player.resumePlayer();
  }

  @override
  Future<void> dispose() => stop();

  Future<void> _start({
    required int sampleRate,
    required int bufferSize,
    required bool interleaved,
  }) async {
    _finishedNotified = false;
    try {
      await _player.openPlayer();
      await _player.startPlayerFromStream(
        codec: Codec.pcm16,
        numChannels: 1,
        sampleRate: sampleRate,
        bufferSize: bufferSize,
        interleaved: interleaved,
      );
      _stopped = false;
    } catch (_) {
      _stopped = true;
      rethrow;
    }
  }

  Future<void> _resetPlayer() async {
    try {
      await _player.uint8ListSink?.close();
    } catch (_) {}
    try {
      await _player.stopPlayer();
    } catch (_) {}
    try {
      await _player.closePlayer();
    } catch (_) {}
    _player = FlutterSoundPlayer();
    _startFuture = null;
    _stopped = true;
    _finishedNotified = false;
  }

  void _notifyFinished() {
    if (_finishedNotified) return;
    _finishedNotified = true;
    _onFinished?.call();
    _onFinished = null;
  }
}

/// iOS implementation using native AVAudioEngine with gain boost.
/// Mirrors the Android implementation for consistent loud audio output.
class IOSAudioTrackPlayer implements AudioChunkPlayer {
  static const _channel = MethodChannel('com.antroph.auraapp/pcm_player');
  Future<void>? _startFuture;
  bool _stopped = true;
  VoidCallback? _onFinished;
  bool _finishedNotified = false;

  @override
  Future<void> addChunk(
    Uint8List bytes, {
    int sampleRate = 16000,
    int bufferSize = 4096,
    bool interleaved = true, // ignored, mono only
    VoidCallback? onFinished,
  }) async {
    _onFinished ??= onFinished;
    try {
      _startFuture ??= _start(sampleRate: sampleRate, bufferSize: bufferSize);
      await _startFuture;
    } catch (_) {
      await _reset();
      _startFuture = _start(sampleRate: sampleRate, bufferSize: bufferSize);
      await _startFuture;
    }

    try {
      await _channel.invokeMethod<void>('write', {'bytes': bytes});
    } catch (_) {
      await _reset();
      rethrow;
    }
  }

  @override
  Future<void> stop({bool notifyFinished = true}) async {
    if (_stopped) return;
    await _reset();
    if (notifyFinished) {
      _notifyFinished();
    }
  }

  @override
  Future<void> pause() async {
    if (_stopped) return;
    try {
      await _channel.invokeMethod<void>('pause');
    } on MissingPluginException {
      // Older installed builds do not have native pause/resume yet. Surface
      // the error so the controller does not pretend playback can resume.
      rethrow;
    }
  }

  @override
  Future<void> resume() async {
    if (_stopped) return;
    try {
      await _channel.invokeMethod<void>('resume');
    } on MissingPluginException {
      // Native resume is available after reinstalling a build with the updated
      // platform channel. Surface the error so UI state stays honest.
      rethrow;
    }
  }

  @override
  Future<void> dispose() => stop();

  Future<void> _start({
    required int sampleRate,
    required int bufferSize,
  }) async {
    _finishedNotified = false;
    try {
      await _channel.invokeMethod<void>('start', {
        'sampleRate': sampleRate,
        'bufferSize': bufferSize,
      });
      _stopped = false;
    } catch (_) {
      _stopped = true;
      rethrow;
    }
  }

  Future<void> _reset() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (_) {}
    _startFuture = null;
    _stopped = true;
    _finishedNotified = false;
  }

  void _notifyFinished() {
    if (_finishedNotified) return;
    _finishedNotified = true;
    _onFinished?.call();
    _onFinished = null;
  }
}

/// Android implementation using a lightweight AudioTrack channel to avoid
/// flutter_sound native crashes when querying player state.
class AndroidAudioTrackPlayer implements AudioChunkPlayer {
  static const _channel = MethodChannel('com.antroph.aura/pcm_player');
  Future<void>? _startFuture;
  bool _stopped = true;
  VoidCallback? _onFinished;
  bool _finishedNotified = false;

  @override
  Future<void> addChunk(
    Uint8List bytes, {
    int sampleRate = 16000,
    int bufferSize = 4096,
    bool interleaved = true, // ignored, mono only
    VoidCallback? onFinished,
  }) async {
    _onFinished ??= onFinished;
    try {
      _startFuture ??= _start(sampleRate: sampleRate, bufferSize: bufferSize);
      await _startFuture;
    } catch (_) {
      await _reset();
      _startFuture = _start(sampleRate: sampleRate, bufferSize: bufferSize);
      await _startFuture;
    }

    try {
      await _channel.invokeMethod<void>('write', {'bytes': bytes});
    } catch (_) {
      await _reset();
      rethrow;
    }
  }

  @override
  Future<void> stop({bool notifyFinished = true}) async {
    if (_stopped) return;
    await _reset();
    if (notifyFinished) {
      _notifyFinished();
    }
  }

  @override
  Future<void> pause() async {
    if (_stopped) return;
    try {
      await _channel.invokeMethod<void>('pause');
    } on MissingPluginException {
      // Older installed builds do not have native pause/resume yet. Surface
      // the error so the controller does not pretend playback can resume.
      rethrow;
    }
  }

  @override
  Future<void> resume() async {
    if (_stopped) return;
    try {
      await _channel.invokeMethod<void>('resume');
    } on MissingPluginException {
      // Native resume is available after reinstalling a build with the updated
      // platform channel. Surface the error so UI state stays honest.
      rethrow;
    }
  }

  @override
  Future<void> dispose() => stop();

  Future<void> _start({
    required int sampleRate,
    required int bufferSize,
  }) async {
    _finishedNotified = false;
    try {
      await _channel.invokeMethod<void>('start', {
        'sampleRate': sampleRate,
        'bufferSize': bufferSize,
      });
      _stopped = false;
    } catch (_) {
      _stopped = true;
      rethrow;
    }
  }

  Future<void> _reset() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (_) {}
    _startFuture = null;
    _stopped = true;
    _finishedNotified = false;
  }

  void _notifyFinished() {
    if (_finishedNotified) return;
    _finishedNotified = true;
    _onFinished?.call();
    _onFinished = null;
  }
}
