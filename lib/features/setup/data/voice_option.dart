class VoiceOption {
  final String voiceId;
  final String displayName;
  final String? description;
  final String? gender;
  final String? style;
  final String? previewAudioUrl;
  final bool isActive;

  const VoiceOption({
    required this.voiceId,
    required this.displayName,
    this.description,
    this.gender,
    this.style,
    this.previewAudioUrl,
    this.isActive = true,
  });

  factory VoiceOption.fromJson(Map<String, dynamic> json) {
    return VoiceOption(
      voiceId: (json['voice_id'] ?? '').toString(),
      displayName: (json['display_name'] ?? '').toString(),
      description: json['description']?.toString(),
      gender: json['gender']?.toString(),
      style: json['style']?.toString(),
      previewAudioUrl: json['preview_audio_url']?.toString(),
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class VoiceListResult {
  final List<VoiceOption> voices;
  final String selectedVoice;

  const VoiceListResult({required this.voices, required this.selectedVoice});

  factory VoiceListResult.fromJson(Map<String, dynamic> json) {
    final rawVoices = json['voices'];
    final parsed = <VoiceOption>[];
    if (rawVoices is Iterable) {
      for (final item in rawVoices) {
        if (item is Map<String, dynamic>) {
          parsed.add(VoiceOption.fromJson(item));
        }
      }
    }
    return VoiceListResult(
      voices: parsed,
      selectedVoice: (json['selected_voice'] ?? '').toString(),
    );
  }
}
