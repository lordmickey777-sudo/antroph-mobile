class VoiceOption {
  final String voiceId;
  final String displayName;
  final String? description;
  final String? gender;
  final String? style;
  final String? previewText;
  final String? previewAudioUrl;
  final String? previewAudioStatus;
  final bool isActive;

  const VoiceOption({
    required this.voiceId,
    required this.displayName,
    this.description,
    this.gender,
    this.style,
    this.previewText,
    this.previewAudioUrl,
    this.previewAudioStatus,
    this.isActive = true,
  });

  factory VoiceOption.fromJson(Map<String, dynamic> json) {
    final voiceId = _firstString(json, const <String>[
      'voice_id',
      'voiceId',
      'id',
      'value',
      'key',
    ]);
    final displayName = _firstString(json, const <String>[
      'display_name',
      'displayName',
      'name',
      'label',
      'title',
    ]);
    return VoiceOption(
      voiceId: voiceId,
      displayName: displayName.isNotEmpty ? displayName : voiceId,
      description: json['description']?.toString(),
      gender: json['gender']?.toString(),
      style: json['style']?.toString(),
      previewText: json['preview_text']?.toString(),
      previewAudioUrl: _firstString(json, const <String>[
        'preview_audio_url',
        'previewAudioUrl',
        'preview_url',
        'previewUrl',
        'audio_url',
        'audioUrl',
        'url',
      ]),
      previewAudioStatus: _firstString(json, const <String>[
        'preview_audio_status',
        'previewAudioStatus',
        'audio_status',
        'audioStatus',
        'status',
      ]),
      isActive: _boolValue(json['is_active'] ?? json['isActive']) ?? true,
    );
  }

  static String _firstString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static bool? _boolValue(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().trim().toLowerCase();
    if (text == 'true' || text == '1' || text == 'yes') return true;
    if (text == 'false' || text == '0' || text == 'no') return false;
    return null;
  }
}

class VoiceListResult {
  final List<VoiceOption> voices;
  final String selectedVoice;

  const VoiceListResult({required this.voices, required this.selectedVoice});

  factory VoiceListResult.fromJson(Map<String, dynamic> json) {
    final rawVoices = _rawVoices(json);
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
      selectedVoice: (json['selected_voice'] ?? json['selectedVoice'] ?? '')
          .toString(),
    );
  }

  static Object? _rawVoices(Map<String, dynamic> json) {
    final direct = json['voices'] ?? json['results'];
    if (direct != null) return direct;
    final data = json['data'];
    if (data is Iterable) return data;
    if (data is Map<String, dynamic>) {
      return data['voices'] ?? data['results'] ?? data['items'];
    }
    return null;
  }
}
