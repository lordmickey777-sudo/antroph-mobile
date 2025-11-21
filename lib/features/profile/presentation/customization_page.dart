import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:antroph_mobile/widgets/app_button.dart';
import 'package:antroph_mobile/widgets/app_dropdown.dart';
import 'package:antroph_mobile/widgets/app_input.dart';
import 'package:antroph_mobile/widgets/toast.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';

import '../models/ai_settings.dart';
import '../providers/customization_controller.dart';
import '../../../core/network/error_formatter.dart';

const Map<String, String> _defaultLanguageOptions = {
  'en': 'English',
  'fr': 'French',
  'es': 'Spanish',
  'de': 'German',
  'it': 'Italian',
};

const List<String> _personalityTypeKeys = [
  'friendly_guide',
  'storyteller',
  'mentor',
  'playful_pal',
];

const Map<String, String> _personalityTypeOptions = {
  'friendly_guide': 'Friendly guide',
  'storyteller': 'Storyteller',
  'mentor': 'Mentor',
  'playful_pal': 'Playful pal',
};

const Map<String, String> _toneOptions = {
  'casual': 'Casual',
  'warm': 'Warm',
  'confident': 'Confident',
  'soothing': 'Soothing',
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
  'nova': 'Nova',
  'ember': 'Ember',
  'aurora': 'Aurora',
};

const Map<String, String> _filterLevelOptions = {
  'lenient': 'Lenient',
  'moderate': 'Moderate',
  'strict': 'Strict',
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

  AiSettings? _boundSettings;

  @override
  void dispose() {
    _companionNameController.dispose();
    _allowedTopicsController.dispose();
    _blockedTopicsController.dispose();
    _approvalController.dispose();
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
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
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
            TypographyText('Unable to load settings', color: Colors.white70),
            const SizedBox(height: 12),
            TypographyText(message, color: Colors.white54),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => ref.refresh(customizationControllerProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
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
  }

  Widget _buildForm(CustomizationController controller) {
    final safeBottom = MediaQuery.of(context).viewPadding.bottom;
    const bottomSpacing = 96.0;
    final listBottomPadding = bottomSpacing + safeBottom;
    return Stack(
      children: [
        Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(24, 12, 24, listBottomPadding),
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
                validator: (value) => value != null && value.trim().isNotEmpty
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
        Positioned(
          left: 24,
          right: 24,
          bottom: 16 + safeBottom,
          child: SafeArea(
            top: false,
            child: Material(
              elevation: 12,
              borderRadius: BorderRadius.circular(40),
              color: Colors.transparent,
              child: SizedBox(
                height: 56,
                width: double.infinity,
                child: AppButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: controller.isSaving
                      ? null
                      : () => _handleSave(controller),
                  child: controller.isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.black,
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
    final actionContext = context;
    FocusScope.of(actionContext).unfocus();
    try {
      await controller.saveSettings(_buildPayload());
      if (!mounted) return;
      showToast(actionContext, 'Preferences saved', success: true);
    } on ApiError catch (apiError) {
      if (!mounted) return;
      showToast(actionContext, apiError.message);
    } catch (e) {
      if (!mounted) return;
      showToast(actionContext, e.toString());
    }
  }

  Widget _buildPersonalitySlider() {
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
              color: Colors.white70,
              variant: TypographyVariant.body2,
            ),
            TypographyText(
              selectedLabel,
              color: Colors.white,
              variant: TypographyVariant.body2,
            ),
          ],
        ),
        const SizedBox(height: 6),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            thumbColor: Colors.white,
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white24,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2223),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                TypographyText(
                  'Parental controls',
                  color: Colors.white,
                  variant: TypographyVariant.body1,
                ),
                SizedBox(height: 4),
                TypographyText(
                  'Restrict topics and approval flows',
                  color: Colors.white70,
                  variant: TypographyVariant.body2,
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _parentalEnabled,
            activeColor: Colors.greenAccent,
            onChanged: (value) => setState(() => _parentalEnabled = value),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TypographyText(
          'Max age rating',
          color: Colors.white70,
          variant: TypographyVariant.body2,
        ),
        const SizedBox(height: 6),
        TypographyText(
          '${_maxAgeRating.round()}+',
          color: Colors.white,
          variant: TypographyVariant.body1,
        ),
        const SizedBox(height: 6),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            thumbColor: Colors.white,
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white24,
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
      color: Colors.white,
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
