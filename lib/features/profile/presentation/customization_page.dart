import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:antroph_mobile/core/responsive/responsive.dart';
import 'package:antroph_mobile/core/theme/theme_provider.dart';
import 'package:antroph_mobile/features/setup/data/voices_repository.dart';
import 'package:just_audio/just_audio.dart';

import 'package:antroph_mobile/widgets/app_button.dart';
import 'package:antroph_mobile/widgets/app_dropdown.dart';
import 'package:antroph_mobile/widgets/app_input.dart';
import 'package:antroph_mobile/widgets/shimmer.dart';
import 'package:antroph_mobile/widgets/toast.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';

import '../models/ai_settings.dart';
import '../providers/customization_controller.dart';
import '../../../core/network/error_formatter.dart';

const Map<String, String> _defaultLanguageOptions = {
  'en': 'English',
  'af': 'Afrikaans',
  'ar': 'Arabic',
  'az': 'Azerbaijani',
  'be': 'Belarusian',
  'bg': 'Bulgarian',
  'bs': 'Bosnian',
  'ca': 'Catalan',
  'cs': 'Czech',
  'cy': 'Welsh',
  'da': 'Danish',
  'de': 'German',
  'el': 'Greek',
  'es': 'Spanish',
  'et': 'Estonian',
  'fa': 'Persian (Farsi)',
  'fi': 'Finnish',
  'fr': 'French',
  'gl': 'Galician',
  'he': 'Hebrew',
  'hi': 'Hindi',
  'hr': 'Croatian',
  'hu': 'Hungarian',
  'hy': 'Armenian',
  'id': 'Indonesian',
  'is': 'Icelandic',
  'it': 'Italian',
  'ja': 'Japanese',
  'kk': 'Kazakh',
  'kn': 'Kannada',
  'ko': 'Korean',
  'lt': 'Lithuanian',
  'lv': 'Latvian',
  'mi': 'Maori',
  'mk': 'Macedonian',
  'mr': 'Marathi',
  'ms': 'Malay',
  'ne': 'Nepali',
  'nl': 'Dutch',
  'no': 'Norwegian',
  'pl': 'Polish',
  'pt': 'Portuguese',
  'ro': 'Romanian',
  'ru': 'Russian',
  'sk': 'Slovak',
  'sl': 'Slovenian',
  'sr': 'Serbian',
  'sv': 'Swedish',
  'sw': 'Swahili',
  'ta': 'Tamil',
  'th': 'Thai',
  'tl': 'Filipino',
  'tr': 'Turkish',
  'uk': 'Ukrainian',
  'ur': 'Urdu',
  'vi': 'Vietnamese',
  'zh': 'Chinese',
};

const List<String> _personalityTypeKeys = [
  'friendly_guide',
  'wise_storyteller',
  'playful_companion',
  'curious_explorer',
];

const Map<String, String> _personalityTypeOptions = {
  'friendly_guide': 'Friendly guide',
  'wise_storyteller': 'Wise storyteller',
  'playful_companion': 'Playful companion',
  'curious_explorer': 'Curious explorer',
};

const Map<String, String> _toneOptions = {
  'formal': 'Formal',
  'casual': 'Casual',
  'playful': 'Playful',
};

const Map<String, String> _verbosityOptions = {
  'concise': 'Concise',
  'moderate': 'Moderate',
  'detailed': 'Detailed',
};

const Map<String, String> _languageComplexityOptions = {
  'age_appropriate': 'Age appropriate',
  'simple': 'Simple',
  'advanced': 'Advanced',
};

const Map<String, String> _ttsVoiceOptions = {
  'alloy': 'Alloy',
  'cedar': 'Atlas',
  'ballad': 'Ballad',
  'coral': 'Echo',
  'marin': 'Luna',
  'ash': 'Milo',
  'shimmer': 'Nova',
  'echo': 'Resonance',
  'sage': 'Sage',
  'verse': 'Verse',
};

const Map<String, String> _filterLevelOptions = {
  'strict': 'Strict',
  'moderate': 'Moderate',
  'minimal': 'Minimal',
};

String _normalizeOption(Map<String, String> options, String value) {
  if (value.isNotEmpty && options.containsKey(value)) {
    return value;
  }
  return options.keys.first;
}

class CustomizationPage extends ConsumerStatefulWidget {
  const CustomizationPage({super.key});

  @override
  ConsumerState<CustomizationPage> createState() => _CustomizationPageState();
}

class _CustomizationPageState extends ConsumerState<CustomizationPage> {
  final _formKey = GlobalKey<FormState>();
  final _companionNameController = TextEditingController();
  final _allowedTopicsController = TextEditingController();
  final _blockedTopicsController = TextEditingController();
  final _approvalController = TextEditingController();
  final _player = AudioPlayer();
  final _voicesRepository = VoicesRepository();
  Map<String, String> _previewUrls = {};

  String _personalityType = _personalityTypeKeys.first;
  String _tone = _toneOptions.keys.first;
  String _verbosity = _verbosityOptions.keys.first;
  String _languageComplexity = _languageComplexityOptions.keys.first;
  String _ttsVoice = _ttsVoiceOptions.keys.first;
  String _selectedLanguage = _defaultLanguageOptions.keys.first;
  String _contentFilterLevel = _filterLevelOptions.keys.first;
  double _maxAgeRating = 0;
  bool _parentalEnabled = false;
  double _personalitySliderValue = 0;
  bool _autoListenAfterResponse = true;

  AiSettings? _boundSettings;

  @override
  void initState() {
    super.initState();
    _loadVoicePreviews();
  }

  Future<void> _loadVoicePreviews() async {
    try {
      final result = await _voicesRepository.fetchVoices();
      if (!mounted) return;
      final map = <String, String>{};
      for (final v in result.voices) {
        if (v.previewAudioUrl?.isNotEmpty == true) {
          map[v.voiceId] = v.previewAudioUrl!;
        }
      }
      setState(() => _previewUrls = map);
    } catch (_) {
      // Ignore failures
    }
  }

  Future<void> _playVoicePreview(String voiceId) async {
    final url = _previewUrls[voiceId];
    if (url == null || url.isEmpty) return;
    try {
      await _player.stop();
      await _player.setUrl(url);
      await _player.play();
    } catch (_) {
      // Ignore playback errors
    }
  }

  @override
  void dispose() {
    _companionNameController.dispose();
    _allowedTopicsController.dispose();
    _blockedTopicsController.dispose();
    _approvalController.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(customizationControllerProvider);
    final controller = ref.read(customizationControllerProvider.notifier);

    final serverData = state.asData?.value;
    if (serverData != null && _boundSettings != serverData) {
      _boundSettings = serverData;
      _populateFields(serverData);
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Customization'),
        backgroundColor: theme.scaffoldBackgroundColor,
        leading: const BackButton(),
        actions: [
          if (state.asData != null)
            IconButton(
              icon: controller.isResetting
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white70,
                      ),
                    )
                  : const Icon(Icons.restore, color: Colors.white70),
              tooltip: 'Reset to defaults',
              onPressed: controller.isResetting || controller.isSaving
                  ? null
                  : () => _handleReset(controller),
            ),
        ],
      ),
      body: state.when(
        loading: () => const _CustomizationPageShimmer(),
        error: (error, stack) => _buildError(context, error, stack),
        data: (_) => _buildForm(controller),
      ),
    );
  }

  Widget _buildError(BuildContext context, Object error, StackTrace _) {
    final message = error is ApiError ? error.message : error.toString();
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TypographyText(
              'Unable to load settings',
              color: context.secondaryTextColor,
            ),
            const SizedBox(height: 12),
            TypographyText(message, color: context.tertiaryTextColor),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => ref.refresh(customizationControllerProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.actionButtonBackground,
                foregroundColor: context.actionButtonForeground,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  void _populateFields(AiSettings settings) {
    _personalityType = _normalizeOption(
      _personalityTypeOptions,
      settings.personality.personalityType,
    );
    _tone = _normalizeOption(_toneOptions, settings.personality.tone);
    _verbosity = _normalizeOption(
      _verbosityOptions,
      settings.personality.verbosity,
    );
    _languageComplexity = _normalizeOption(
      _languageComplexityOptions,
      settings.personality.languageComplexity,
    );
    _ttsVoice = _normalizeOption(_ttsVoiceOptions, settings.ttsVoice);
    _selectedLanguage = _normalizeOption(
      _defaultLanguageOptions,
      settings.language,
    );
    _contentFilterLevel = _normalizeOption(
      _filterLevelOptions,
      settings.parentalControls.contentFilterLevel,
    );
    _parentalEnabled = settings.parentalControls.enabled;
    _maxAgeRating = settings.parentalControls.maxAgeRating
        .clamp(0, 18)
        .toDouble();
    _companionNameController.text = settings.personality.companionName;
    _allowedTopicsController.text = settings.parentalControls.allowedTopics
        .join(', ');
    _blockedTopicsController.text = settings.parentalControls.blockedTopics
        .join(', ');
    _approvalController.text = settings.parentalControls.requireApprovalFor
        .join(', ');
    _autoListenAfterResponse = settings.autoListenAfterResponse;
  }

  Widget _buildForm(CustomizationController controller) {
    final safeBottom = MediaQuery.of(context).viewPadding.bottom;
    const bottomSpacing = 96.0;
    final listBottomPadding = bottomSpacing + safeBottom;
    final horizontalPadding = AppPadding.form.of(context);
    return Stack(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: ContentWidth.content),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  12,
                  horizontalPadding,
                  listBottomPadding,
                ),
                children: [
                  _sectionTitle('Personality'),
                  const SizedBox(height: 12),
                  _buildPersonalitySlider(),
                  const SizedBox(height: 12),
                  AppDropdown(
                    label: 'Tone',
                    value: _tone,
                    options: _toneOptions,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _tone = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  AppDropdown(
                    label: 'Verbosity',
                    value: _verbosity,
                    options: _verbosityOptions,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _verbosity = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  AppDropdown(
                    label: 'Language complexity',
                    value: _languageComplexity,
                    options: _languageComplexityOptions,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _languageComplexity = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  AppInput(
                    controller: _companionNameController,
                    hint: 'Companion name',
                    icon: Icons.star_outline,
                    validator: (value) =>
                        value != null && value.trim().isNotEmpty
                        ? null
                        : 'Enter a name',
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle('Voice & language'),
                  const SizedBox(height: 12),
                  AppDropdown(
                    label: 'Voice',
                    value: _ttsVoice,
                    options: _ttsVoiceOptions,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _ttsVoice = value);
                      _playVoicePreview(value);
                    },
                  ),
                  const SizedBox(height: 12),
                  AppDropdown(
                    label: 'Language',
                    value: _selectedLanguage,
                    options: _defaultLanguageOptions,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedLanguage = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildAutoListenToggle(),
                  const SizedBox(height: 24),
                  _sectionTitle('Parental controls'),
                  const SizedBox(height: 12),
                  _buildParentalToggle(),
                  const SizedBox(height: 12),
                  AppDropdown(
                    label: 'Filter level',
                    value: _contentFilterLevel,
                    options: _filterLevelOptions,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _contentFilterLevel = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildSlider(),
                  const SizedBox(height: 16),
                  AppInput(
                    controller: _allowedTopicsController,
                    hint: 'Allowed topics (comma separated)',
                    icon: Icons.thumb_up_outlined,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  AppInput(
                    controller: _blockedTopicsController,
                    hint: 'Blocked topics (comma separated)',
                    icon: Icons.block_outlined,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  AppInput(
                    controller: _approvalController,
                    hint: 'Require approval for (comma separated)',
                    icon: Icons.lock_outline,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 16 + safeBottom,
          child: SafeArea(
            top: false,
            child: Material(
              elevation: 12,
              borderRadius: BorderRadius.circular(999),
              color: Colors.transparent,
              child: SizedBox(
                height: 56,
                width: double.infinity,
                child: AppButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.actionButtonBackground,
                    foregroundColor: context.actionButtonForeground,
                  ),
                  onPressed: controller.isSaving
                      ? null
                      : () => _handleSave(controller),
                  child: controller.isSaving
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: context.actionButtonForeground,
                          ),
                        )
                      : const Text('Save changes'),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleSave(CustomizationController controller) async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    try {
      await controller.saveSettings(_buildPayload());
      if (!mounted) return;
      showToast(context, 'Preferences saved', success: true);
    } on ApiError catch (apiError) {
      if (!mounted) return;
      showToast(context, apiError.message);
    } catch (e) {
      if (!mounted) return;
      showToast(context, e.toString());
    }
  }

  Future<void> _handleReset(CustomizationController controller) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text(
          'Reset to defaults?',
          style: TextStyle(color: context.primaryTextColor),
        ),
        content: Text(
          'This will restore all AI settings to their default values.',
          style: TextStyle(color: context.secondaryTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await controller.resetSettings();
      if (!mounted) return;
      showToast(context, 'Settings reset to defaults', success: true);
    } on ApiError catch (apiError) {
      if (!mounted) return;
      showToast(context, apiError.message);
    } catch (e) {
      if (!mounted) return;
      showToast(context, e.toString());
    }
  }

  Widget _buildPersonalitySlider() {
    final isDark = context.isDarkMode;
    final activeColor = isDark ? Colors.white : Colors.black87;
    final inactiveColor = isDark ? Colors.white24 : Colors.black12;
    final overlayColor = activeColor.withValues(alpha: isDark ? 0.14 : 0.08);
    final maxIndex = _personalityTypeKeys.length - 1;
    final boundedMaxIndex = maxIndex >= 0 ? maxIndex : 0;
    final currentIndex = _personalitySliderValue.round().clamp(
      0,
      boundedMaxIndex,
    );
    final selectedKey = _personalityTypeKeys[currentIndex];
    final selectedLabel =
        _personalityTypeOptions[selectedKey] ?? 'Friendly guide';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TypographyText(
              'Personality type',
              color: context.secondaryTextColor,
              variant: TypographyVariant.body2,
            ),
            TypographyText(
              selectedLabel,
              color: context.primaryTextColor,
              variant: TypographyVariant.body2,
            ),
          ],
        ),
        const SizedBox(height: 6),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            thumbColor: activeColor,
            activeTrackColor: activeColor,
            inactiveTrackColor: inactiveColor,
            overlayColor: overlayColor,
          ),
          child: Slider(
            value: _personalitySliderValue,
            min: 0,
            max: boundedMaxIndex.toDouble(),
            divisions: boundedMaxIndex == 0 ? null : boundedMaxIndex,
            label: selectedLabel,
            onChanged: (value) {
              final idx = value.round().clamp(0, boundedMaxIndex);
              setState(() {
                _personalitySliderValue = idx.toDouble();
                _personalityType = _personalityTypeKeys[idx];
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildParentalToggle() {
    final primaryText = context.primaryTextColor;
    final secondaryText = context.secondaryTextColor;
    final isDark = context.isDarkMode;
    final activeThumb = isDark ? Colors.white : Colors.black87;
    final activeTrack = isDark ? Colors.white38 : Colors.black26;
    final inactiveThumb = isDark ? Colors.white30 : Colors.black26;
    final inactiveTrack = isDark ? Colors.white12 : Colors.black12;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: context.cardBackground,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TypographyText(
                  'Parental controls',
                  color: primaryText,
                  variant: TypographyVariant.body1,
                ),
                const SizedBox(height: 4),
                TypographyText(
                  'Restrict topics and approval flows',
                  color: secondaryText,
                  variant: TypographyVariant.body2,
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _parentalEnabled,
            activeColor: activeThumb,
            activeTrackColor: activeTrack,
            inactiveThumbColor: inactiveThumb,
            inactiveTrackColor: inactiveTrack,
            onChanged: (value) => setState(() => _parentalEnabled = value),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoListenToggle() {
    final primaryText = context.primaryTextColor;
    final secondaryText = context.secondaryTextColor;
    final isDark = context.isDarkMode;
    final activeThumb = isDark ? Colors.white : Colors.black87;
    final activeTrack = isDark ? Colors.white38 : Colors.black26;
    final inactiveThumb = isDark ? Colors.white30 : Colors.black26;
    final inactiveTrack = isDark ? Colors.white12 : Colors.black12;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: context.cardBackground,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TypographyText(
                  'Continuous conversation',
                  color: primaryText,
                  variant: TypographyVariant.body1,
                ),
                const SizedBox(height: 4),
                TypographyText(
                  'Auto-listen after AI finishes speaking',
                  color: secondaryText,
                  variant: TypographyVariant.body2,
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _autoListenAfterResponse,
            activeColor: activeThumb,
            activeTrackColor: activeTrack,
            inactiveThumbColor: inactiveThumb,
            inactiveTrackColor: inactiveTrack,
            onChanged: (value) =>
                setState(() => _autoListenAfterResponse = value),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider() {
    final isDark = context.isDarkMode;
    final activeColor = isDark ? Colors.white : Colors.black87;
    final inactiveColor = isDark ? Colors.white24 : Colors.black12;
    final overlayColor = activeColor.withValues(alpha: isDark ? 0.14 : 0.08);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TypographyText(
          'Max age rating',
          color: context.secondaryTextColor,
          variant: TypographyVariant.body2,
        ),
        const SizedBox(height: 6),
        TypographyText(
          '${_maxAgeRating.round()}+',
          color: context.primaryTextColor,
          variant: TypographyVariant.body1,
        ),
        const SizedBox(height: 6),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            thumbColor: activeColor,
            activeTrackColor: activeColor,
            inactiveTrackColor: inactiveColor,
            overlayColor: overlayColor,
          ),
          child: Slider(
            value: _maxAgeRating,
            min: 0,
            max: 18,
            divisions: 18,
            label: '${_maxAgeRating.round()}+',
            onChanged: (value) => setState(() => _maxAgeRating = value),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return TypographyText(
      title,
      variant: TypographyVariant.body1,
      color: context.primaryTextColor,
    );
  }

  AiSettings _buildPayload() {
    final personality = Personality(
      personalityType: _personalityType,
      tone: _tone,
      verbosity: _verbosity,
      languageComplexity: _languageComplexity,
      companionName: _companionNameController.text.trim(),
    );

    final parental = ParentalControls(
      enabled: _parentalEnabled,
      contentFilterLevel: _contentFilterLevel,
      maxAgeRating: _maxAgeRating.round(),
      allowedTopics: _parseTopics(_allowedTopicsController.text),
      blockedTopics: _parseTopics(_blockedTopicsController.text),
      requireApprovalFor: _parseTopics(_approvalController.text),
    );

    return AiSettings(
      personality: personality,
      parentalControls: parental,
      ttsVoice: _ttsVoice,
      language: _selectedLanguage,
      autoListenAfterResponse: _autoListenAfterResponse,
    );
  }

  List<String> _parseTopics(String value) {
    return value
        .split(',')
        .map((topic) => topic.trim())
        .where((topic) => topic.isNotEmpty)
        .toList();
  }
}

class _CustomizationPageShimmer extends StatelessWidget {
  const _CustomizationPageShimmer();

  @override
  Widget build(BuildContext context) {
    return const ShimmerLoadingPage(
      child: SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShimmerText(width: 96, height: 16),
            SizedBox(height: 12),
            ShimmerBox(height: 96, radius: 24),
            SizedBox(height: 12),
            ShimmerInput(height: 56),
            SizedBox(height: 12),
            ShimmerInput(height: 56),
            SizedBox(height: 12),
            ShimmerText(width: 80, height: 16),
            SizedBox(height: 12),
            ShimmerInput(height: 56),
            SizedBox(height: 12),
            ShimmerInput(height: 56),
            SizedBox(height: 12),
            ShimmerBox(height: 96, radius: 24),
            SizedBox(height: 12),
            ShimmerButton(height: 56, radius: 16),
          ],
        ),
      ),
    );
  }
}
