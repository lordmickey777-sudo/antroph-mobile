import 'package:speech_to_text/speech_to_text.dart';

class SpeechInputService {
  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;

  Future<bool> initialize() async {
    if (_initialized) return true;
    _initialized = await _speech.initialize(
      onError: (error) => _initialized = false,
    );
    return _initialized;
  }

  bool get isAvailable => _initialized;
  bool get isListening => _speech.isListening;

  /// Start listening and call [onResult] with the transcribed text.
  Future<void> startListening({
    required void Function(String text, bool isFinal) onResult,
    String localeId = 'en_US',
  }) async {
    if (!_initialized) {
      final ok = await initialize();
      if (!ok) return;
    }
    await _speech.listen(
      onResult: (result) {
        onResult(result.recognizedWords, result.finalResult);
      },
      localeId: localeId,
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        cancelOnError: true,
        partialResults: true,
      ),
    );
  }

  Future<void> stopListening() async {
    await _speech.stop();
  }

  void dispose() {
    _speech.cancel();
  }
}
