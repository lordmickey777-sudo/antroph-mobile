import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/speech_input_service.dart';

/// A mic icon button for speech-to-text input on form fields.
///
/// Place as the `trailing` widget in [AppInput].
class VoiceFormInput extends ConsumerStatefulWidget {
  const VoiceFormInput({
    super.key,
    required this.controller,
    this.onResult,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onResult;

  @override
  ConsumerState<VoiceFormInput> createState() => _VoiceFormInputState();
}

class _VoiceFormInputState extends ConsumerState<VoiceFormInput> {
  final SpeechInputService _speech = SpeechInputService();
  bool _listening = false;

  @override
  void dispose() {
    _speech.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_listening) {
      await _speech.stopListening();
      setState(() => _listening = false);
      return;
    }

    final ok = await _speech.initialize();
    if (!ok) return;

    setState(() => _listening = true);

    await _speech.startListening(
      onResult: (text, isFinal) {
        widget.controller.text = text;
        widget.controller.selection = TextSelection.fromPosition(
          TextPosition(offset: text.length),
        );
        if (isFinal) {
          setState(() => _listening = false);
          widget.onResult?.call(text);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? Colors.redAccent : Colors.red;
    final inactiveColor = isDark
        ? Colors.white.withValues(alpha: 0.5)
        : Colors.black.withValues(alpha: 0.4);

    return GestureDetector(
      onTap: _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: _listening
              ? activeColor.withValues(alpha: 0.15)
              : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          _listening ? Icons.mic_rounded : Icons.mic_none_rounded,
          color: _listening ? activeColor : inactiveColor,
          size: 22,
        ),
      ),
    );
  }
}
