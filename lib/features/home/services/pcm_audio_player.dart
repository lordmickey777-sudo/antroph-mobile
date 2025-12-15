import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
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

  Future<void> stop();
  Future<void> dispose();
}

AudioChunkPlayer createAudioChunkPlayer() {
  if (Platform.isAndroid) return AndroidAudioTrackPlayer();
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
  Future<void> stop() async {
    if (_stopped) return;
    await _resetPlayer();
    _notifyFinished();
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
      await _channel.invokeMethod<void>('write', {
        'bytes': bytes,
      });
    } catch (_) {
      await _reset();
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    if (_stopped) return;
    await _reset();
    _notifyFinished();
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
