import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:antroph_mobile/core/responsive/responsive.dart';
import 'package:antroph_mobile/widgets/app_input.dart';
import 'package:antroph_mobile/widgets/app_dropdown.dart';
import 'package:antroph_mobile/widgets/app_action_button.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';
import 'package:antroph_mobile/widgets/toast.dart';

import '../providers/story_creation_provider.dart';
import '../widgets/voice_form_input.dart';
import 'rive_element_picker.dart';
import 'story_preview_page.dart';

class StoryFormPage extends ConsumerStatefulWidget {
  const StoryFormPage({super.key});

  @override
  ConsumerState<StoryFormPage> createState() => _StoryFormPageState();
}

class _StoryFormPageState extends ConsumerState<StoryFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _contextCtrl;
  late final TextEditingController _tagInputCtrl;
  late final TextEditingController _themeInputCtrl;
  late final TextEditingController _charInputCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _descCtrl = TextEditingController();
    _contextCtrl = TextEditingController();
    _tagInputCtrl = TextEditingController();
    _themeInputCtrl = TextEditingController();
    _charInputCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _contextCtrl.dispose();
    _tagInputCtrl.dispose();
    _themeInputCtrl.dispose();
    _charInputCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final creation = ref.watch(storyCreationProvider);
    final notifier = ref.read(storyCreationProvider.notifier);
    final horizontalPadding = AppPadding.horizontal.of(context);

    // Listen for success
    ref.listen<StoryCreationState>(storyCreationProvider, (prev, next) {
      if (next.createdStory != null && prev?.createdStory == null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => StoryPreviewPage(
              storyId: next.createdStory!.id,
              storyTitle: next.createdStory!.title,
              riveElement: creation.selectedRiveElement,
            ),
          ),
        );
        notifier.reset();
      }
      if (next.error != null && prev?.error == null) {
        showToast(context, next.error!, success: false);
        notifier.clearError();
      }
    });

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF141718) : const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: TypographyText(
          'New Story',
          variant: TypographyVariant.h4,
          color: isDark ? Colors.white : Colors.black,
        ),
        leading: IconButton(
          icon: Icon(CupertinoIcons.back, color: isDark ? Colors.white : Colors.black),
          onPressed: () {
            notifier.reset();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
          children: [
            // Title
            _SectionLabel('Title', isDark: isDark),
            const SizedBox(height: 6),
            AppInput(
              controller: _titleCtrl,
              hint: 'Give your story a name',
              icon: Icons.title_rounded,
              trailing: VoiceFormInput(
                controller: _titleCtrl,
                onResult: (text) => notifier.updateTitle(text),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Title is required' : null,
              onChanged: (v) => notifier.updateTitle(v),
            ),

            const SizedBox(height: 20),

            // Description
            _SectionLabel('Description', isDark: isDark),
            const SizedBox(height: 6),
            AppInput(
              controller: _descCtrl,
              hint: 'Brief description (optional)',
              icon: Icons.short_text_rounded,
              maxLines: 3,
              trailing: VoiceFormInput(
                controller: _descCtrl,
                onResult: (text) => notifier.updateDescription(text),
              ),
              onChanged: (v) => notifier.updateDescription(v),
            ),

            const SizedBox(height: 20),

            // Context
            _SectionLabel('Story Context', isDark: isDark),
            const SizedBox(height: 6),
            AppInput(
              controller: _contextCtrl,
              hint: 'Describe the story scenario and setting for the AI...',
              icon: Icons.landscape_rounded,
              maxLines: 5,
              trailing: VoiceFormInput(
                controller: _contextCtrl,
                onResult: (text) => notifier.updateContext(text),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Context is required' : null,
              onChanged: (v) => notifier.updateContext(v),
            ),

            const SizedBox(height: 20),

            // Tone
            AppDropdown(
              label: 'Tone',
              value: creation.tone,
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
                if (v != null) notifier.updateTone(v);
              },
            ),

            const SizedBox(height: 20),

            // Target Length
            AppDropdown(
              label: 'Target Length (turns)',
              value: creation.targetLength.toString(),
              options: const {
                '5': '5 turns',
                '10': '10 turns',
                '15': '15 turns',
                '20': '20 turns',
                '30': '30 turns',
                '50': '50 turns',
              },
              onChanged: (v) {
                if (v != null) notifier.updateTargetLength(int.parse(v));
              },
            ),

            const SizedBox(height: 20),

            // Themes
            _ChipInputSection(
              label: 'Themes',
              controller: _themeInputCtrl,
              chips: creation.themes,
              onAdd: (v) => notifier.updateThemes([...creation.themes, v]),
              onRemove: (v) =>
                  notifier.updateThemes(creation.themes.where((t) => t != v).toList()),
              isDark: isDark,
            ),

            const SizedBox(height: 20),

            // Characters
            _ChipInputSection(
              label: 'Characters',
              controller: _charInputCtrl,
              chips: creation.characters,
              onAdd: (v) => notifier.updateCharacters([...creation.characters, v]),
              onRemove: (v) =>
                  notifier.updateCharacters(creation.characters.where((c) => c != v).toList()),
              isDark: isDark,
            ),

            const SizedBox(height: 20),

            // Tags
            _ChipInputSection(
              label: 'Tags',
              controller: _tagInputCtrl,
              chips: creation.tags,
              onAdd: (v) => notifier.updateTags([...creation.tags, v]),
              onRemove: (v) =>
                  notifier.updateTags(creation.tags.where((t) => t != v).toList()),
              isDark: isDark,
            ),

            const SizedBox(height: 20),

            // Mascot Selection
            _SectionLabel('Mascot', isDark: isDark),
            const SizedBox(height: 6),
            _MascotSelector(
              selectedName: creation.selectedRiveElement?.name,
              selectedThumbnail: creation.selectedRiveElement?.effectiveThumbnail,
              isDark: isDark,
              onTap: () => showRiveElementPicker(context),
            ),

            const SizedBox(height: 20),

            // Cover Image
            _SectionLabel('Cover Image', isDark: isDark),
            const SizedBox(height: 6),
            _CoverImagePicker(
              imageFile: creation.coverImage,
              isDark: isDark,
              onPick: () async {
                final picker = ImagePicker();
                final picked = await picker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 1200,
                );
                if (picked != null) {
                  notifier.setCoverImage(File(picked.path));
                }
              },
              onRemove: () => notifier.setCoverImage(null),
            ),

            const SizedBox(height: 32),

            // Submit
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: creation.isSubmitting
                    ? null
                    : () {
                        if (_formKey.currentState?.validate() ?? false) {
                          notifier.submit();
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                child: creation.isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create Story'),
              ),
            ),

            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {required this.isDark});

  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return TypographyText(
      text,
      variant: TypographyVariant.body2,
      color: isDark ? Colors.white.withValues(alpha: 0.6) : Colors.black.withValues(alpha: 0.5),
    );
  }
}

class _ChipInputSection extends StatelessWidget {
  const _ChipInputSection({
    required this.label,
    required this.controller,
    required this.chips,
    required this.onAdd,
    required this.onRemove,
    required this.isDark,
  });

  final String label;
  final TextEditingController controller;
  final List<String> chips;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final chipBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    final chipTextColor = isDark ? Colors.white : Colors.black87;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label, isDark: isDark),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: AppInput(
                controller: controller,
                hint: 'Add $label...',
                onChanged: (_) {},
              ),
            ),
            const SizedBox(width: 8),
            AppCircleIconButton(
              icon: Icons.add_rounded,
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  onAdd(text);
                  controller.clear();
                }
              },
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.08),
            ),
          ],
        ),
        if (chips.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: chips
                .map(
                  (chip) => Chip(
                    label: Text(chip, style: TextStyle(color: chipTextColor, fontSize: 13)),
                    backgroundColor: chipBg,
                    deleteIconColor: chipTextColor.withValues(alpha: 0.6),
                    onDeleted: () => onRemove(chip),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide.none,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _MascotSelector extends StatelessWidget {
  const _MascotSelector({
    required this.selectedName,
    required this.selectedThumbnail,
    required this.isDark,
    required this.onTap,
  });

  final String? selectedName;
  final String? selectedThumbnail;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.06);
    final textColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark
        ? Colors.white.withValues(alpha: 0.4)
        : Colors.black.withValues(alpha: 0.35);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            if (selectedThumbnail != null && selectedThumbnail!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  selectedThumbnail!,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.smart_toy_rounded, color: hintColor, size: 24),
                  ),
                ),
              )
            else
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.smart_toy_rounded, color: hintColor, size: 24),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                selectedName ?? 'Choose a mascot (optional)',
                style: TextStyle(
                  color: selectedName != null ? textColor : hintColor,
                  fontSize: 15,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: hintColor, size: 22),
          ],
        ),
      ),
    );
  }
}

class _CoverImagePicker extends StatelessWidget {
  const _CoverImagePicker({
    required this.imageFile,
    required this.isDark,
    required this.onPick,
    required this.onRemove,
  });

  final File? imageFile;
  final bool isDark;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.06);
    final hintColor = isDark
        ? Colors.white.withValues(alpha: 0.4)
        : Colors.black.withValues(alpha: 0.35);

    if (imageFile != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              imageFile!,
              width: double.infinity,
              height: 180,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: AppCircleIconButton(
              icon: CupertinoIcons.xmark,
              onPressed: onRemove,
              size: 30,
              iconSize: 14,
              backgroundColor: Colors.black.withValues(alpha: 0.5),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: onPick,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_photo_alternate_outlined, color: hintColor, size: 32),
              const SizedBox(height: 8),
              Text(
                'Add cover image',
                style: TextStyle(color: hintColor, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
