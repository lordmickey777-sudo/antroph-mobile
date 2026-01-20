class AiSettings {
  final Personality personality;
  final ParentalControls parentalControls;
  final String ttsVoice;
  final String language;
  final bool autoListenAfterResponse;

  const AiSettings({
    required this.personality,
    required this.parentalControls,
    required this.ttsVoice,
    required this.language,
    this.autoListenAfterResponse = true,
  });

  factory AiSettings.fromJson(Map<String, dynamic> json) {
    return AiSettings(
      personality: Personality.fromJson(
        json['personality'] as Map<String, dynamic>?,
      ),
      parentalControls: ParentalControls.fromJson(
        json['parental_controls'] as Map<String, dynamic>?,
      ),
      ttsVoice: (json['tts_voice'] ?? '').toString(),
      language: (json['language'] ?? '').toString(),
      autoListenAfterResponse: json['auto_listen_after_response'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'personality': personality.toJson(),
    'parental_controls': parentalControls.toJson(),
    'tts_voice': ttsVoice,
    'language': language,
    'auto_listen_after_response': autoListenAfterResponse,
  };
}

class Personality {
  final String personalityType;
  final String tone;
  final String verbosity;
  final String languageComplexity;
  final String companionName;

  const Personality({
    required this.personalityType,
    required this.tone,
    required this.verbosity,
    required this.languageComplexity,
    required this.companionName,
  });

  factory Personality.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const {};
    return Personality(
      personalityType: (data['personality_type'] ?? 'friendly_guide')
          .toString(),
      tone: (data['tone'] ?? 'casual').toString(),
      verbosity: (data['verbosity'] ?? 'moderate').toString(),
      languageComplexity: (data['language_complexity'] ?? 'age_appropriate')
          .toString(),
      companionName: (data['companion_name'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'personality_type': personalityType,
    'tone': tone,
    'verbosity': verbosity,
    'language_complexity': languageComplexity,
    'companion_name': companionName,
  };
}

class ParentalControls {
  final bool enabled;
  final String contentFilterLevel;
  final int maxAgeRating;
  final List<String> allowedTopics;
  final List<String> blockedTopics;
  final List<String> requireApprovalFor;

  const ParentalControls({
    required this.enabled,
    required this.contentFilterLevel,
    required this.maxAgeRating,
    required this.allowedTopics,
    required this.blockedTopics,
    required this.requireApprovalFor,
  });

  factory ParentalControls.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const {};
    return ParentalControls(
      enabled: data['enabled'] as bool? ?? false,
      contentFilterLevel: (data['content_filter_level'] ?? 'moderate')
          .toString(),
      maxAgeRating: _parseInt(data['max_age_rating']),
      allowedTopics: _stringList(data['allowed_topics']),
      blockedTopics: _stringList(data['blocked_topics']),
      requireApprovalFor: _stringList(data['require_approval_for']),
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'content_filter_level': contentFilterLevel,
    'max_age_rating': maxAgeRating,
    'allowed_topics': allowedTopics,
    'blocked_topics': blockedTopics,
    'require_approval_for': requireApprovalFor,
  };

  static int _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  static List<String> _stringList(dynamic value) {
    if (value is Iterable) {
      final topics = <String>[];
      for (final item in value) {
        final entry = item?.toString().trim();
        if (entry != null && entry.isNotEmpty) {
          topics.add(entry);
        }
      }
      return topics;
    }
    return const [];
  }
}
