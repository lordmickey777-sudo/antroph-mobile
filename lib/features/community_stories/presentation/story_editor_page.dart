import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:antroph_mobile/core/responsive/responsive.dart';
import 'package:antroph_mobile/widgets/app_input.dart';
import 'package:antroph_mobile/widgets/app_dropdown.dart';
import 'package:antroph_mobile/widgets/shimmer.dart';

import 'package:antroph_mobile/widgets/typography_text.dart';
import 'package:antroph_mobile/widgets/toast.dart';

import '../models/community_story_model.dart';
import '../providers/community_stories_providers.dart';
import '../widgets/voice_form_input.dart';

/// Edit page for pending or rejected community stories.
class StoryEditorPage extends ConsumerStatefulWidget {
  const StoryEditorPage({super.key, required this.storyId});

  final String storyId;

  @override
  ConsumerState<StoryEditorPage> createState() => _StoryEditorPageState();
}

class _StoryEditorPageState extends ConsumerState<StoryEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _contextCtrl;
  bool _saving = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _descCtrl = TextEditingController();
    _contextCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _contextCtrl.dispose();
    super.dispose();
  }

  void _populateFrom(CommunityStoryDto story) {
    if (_initialized) return;
    _initialized = true;
    _titleCtrl.text = story.title;
    _descCtrl.text = story.description ?? '';
    _contextCtrl.text = story.context ?? '';
    _tone = story.tone ?? 'neutral';
    _targetLength = story.targetLength ?? 10;
    _themes = List<String>.from(story.themes);
    _characters = List<String>.from(story.characters);
    _tags = List<String>.from(story.tags);
  }

  String _tone = 'neutral';
  int _targetLength = 10;
  List<String> _themes = [];
  List<String> _characters = [];
  List<String> _tags = [];

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    try {
      final repo = ref.read(communityStoriesRepositoryProvider);
      await repo.updateStory(
        widget.storyId,
        CommunityStoryUpdateDto(
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          context: _contextCtrl.text.trim(),
          tone: _tone,
          targetLength: _targetLength,
          themes: _themes,
          characters: _characters,
          tags: _tags,
        ),
      );
      ref.invalidate(communityStoryDetailProvider(widget.storyId));
      ref.invalidate(myStoriesProvider);
      if (mounted) {
        showToast(context, 'Story updated', success: true);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showToast(context, e.toString(), success: false);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asyncStory = ref.watch(communityStoryDetailProvider(widget.storyId));
    final horizontalPadding = AppPadding.horizontal.of(context);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF141718)
          : const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: TypographyText(
          'Edit Story',
          variant: TypographyVariant.h4,
          color: isDark ? Colors.white : Colors.black,
        ),
        leading: IconButton(
          icon: Icon(
            CupertinoIcons.back,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: asyncStory.when(
        loading: () => const _StoryEditorPageShimmer(),
        error: (err, _) => Center(
          child: Text(
            'Failed to load story',
            style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
          ),
        ),
        data: (story) {
          _populateFrom(story);
          return Form(
            key: _formKey,
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 16,
              ),
              children: [
                _label('Title', isDark),
                const SizedBox(height: 6),
                AppInput(
                  controller: _titleCtrl,
                  hint: 'Story title',
                  icon: Icons.title_rounded,
                  trailing: VoiceFormInput(controller: _titleCtrl),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 20),
                _label('Description', isDark),
                const SizedBox(height: 6),
                AppInput(
                  controller: _descCtrl,
                  hint: 'Brief description',
                  icon: Icons.short_text_rounded,
                  maxLines: 3,
                  trailing: VoiceFormInput(controller: _descCtrl),
                ),
                const SizedBox(height: 20),
                _label('Context', isDark),
                const SizedBox(height: 6),
                AppInput(
                  controller: _contextCtrl,
                  hint: 'Story scenario and setting...',
                  icon: Icons.landscape_rounded,
                  maxLines: 5,
                  trailing: VoiceFormInput(controller: _contextCtrl),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 20),
                AppDropdown(
                  label: 'Tone',
                  value: _tone,
                  options: const {
                    'neutral': 'Neutral',
                    'light': 'Light',
                    'dark': 'Dark',
                    'humorous': 'Humorous',
                    'serious': 'Serious',
                    'adventurous': 'Adventurous',
                    'mysterious': 'Mysterious',
                  },
                  onChanged: (v) {
                    if (v != null) setState(() => _tone = v);
                  },
                ),
                const SizedBox(height: 20),
                AppDropdown(
                  label: 'Target Length (turns)',
                  value: _targetLength.toString(),
                  options: const {
                    '5': '5 turns',
                    '10': '10 turns',
                    '15': '15 turns',
                    '20': '20 turns',
                    '30': '30 turns',
                    '50': '50 turns',
                  },
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _targetLength = int.parse(v));
                    }
                  },
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save Changes'),
                  ),
                ),
                const SizedBox(height: 120),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _label(String text, bool isDark) {
    return TypographyText(
      text,
      variant: TypographyVariant.body2,
      color: isDark
          ? Colors.white.withValues(alpha: 0.6)
          : Colors.black.withValues(alpha: 0.5),
    );
  }
}

class _StoryEditorPageShimmer extends StatelessWidget {
  const _StoryEditorPageShimmer();

  @override
  Widget build(BuildContext context) {
    return ShimmerLoadingPage(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          ShimmerText(width: 120, height: 14),
          SizedBox(height: 6),
          ShimmerInput(height: 56),
          SizedBox(height: 20),
          ShimmerText(width: 140, height: 14),
          SizedBox(height: 6),
          ShimmerInput(height: 108),
          SizedBox(height: 20),
          ShimmerText(width: 120, height: 14),
          SizedBox(height: 6),
          ShimmerInput(height: 140),
          SizedBox(height: 20),
          ShimmerInput(height: 56),
          SizedBox(height: 20),
          ShimmerInput(height: 56),
          SizedBox(height: 32),
          ShimmerButton(height: 56, radius: 14),
        ],
      ),
    );
  }
}
