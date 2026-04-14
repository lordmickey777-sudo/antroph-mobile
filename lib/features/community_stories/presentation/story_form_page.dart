import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:antroph_mobile/core/responsive/responsive.dart';
import 'package:antroph_mobile/core/theme/theme_provider.dart';
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
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: TypographyText(
          'New Story',
          variant: TypographyVariant.h4,
          color: context.primaryTextColor,
        ),
        leading: IconButton(
          icon: Icon(CupertinoIcons.back, color: context.primaryTextColor),
          onPressed: () {
            notifier.reset();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 16,
          ),
          children: [
            // Section 1: Story Details
            _FormSection(
              title: 'Story Details',
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: AppInput(
                    controller: _titleCtrl,
                    hint: 'Give your story a name',
                    icon: Icons.title_rounded,
                    trailing: VoiceFormInput(
                      controller: _titleCtrl,
                      onResult: (text) => notifier.updateTitle(text),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Title is required'
                        : null,
                    onChanged: (v) => notifier.updateTitle(v),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: AppInput(
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
                ),
              ],
            ),

            const SizedBox(height: 28),

            // Section 2: Story World
            _FormSection(
              title: 'Story World',
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: AppInput(
                    controller: _contextCtrl,
                    hint:
                        'Describe the story scenario and setting for the AI...',
                    icon: Icons.landscape_rounded,
                    maxLines: 5,
                    trailing: VoiceFormInput(
                      controller: _contextCtrl,
                      onResult: (text) => notifier.updateContext(text),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Context is required'
                        : null,
                    onChanged: (v) => notifier.updateContext(v),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: AppDropdown(
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
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppDropdown(
                          label: 'Length',
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
                            if (v != null) {
                              notifier.updateTargetLength(int.parse(v));
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // Section 3: Characters & Elements
            _FormSection(
              title: 'Characters & Elements',
              children: [
                _ChipInputField(
                  label: 'Themes',
                  controller: _themeInputCtrl,
                  chips: creation.themes,
                  onAdd: (v) => notifier.updateThemes([...creation.themes, v]),
                  onRemove: (v) => notifier.updateThemes(
                    creation.themes.where((t) => t != v).toList(),
                  ),
                ),
                _ChipInputField(
                  label: 'Characters',
                  controller: _charInputCtrl,
                  chips: creation.characters,
                  onAdd: (v) =>
                      notifier.updateCharacters([...creation.characters, v]),
                  onRemove: (v) => notifier.updateCharacters(
                    creation.characters.where((c) => c != v).toList(),
                  ),
                ),
                _ChipInputField(
                  label: 'Tags',
                  controller: _tagInputCtrl,
                  chips: creation.tags,
                  onAdd: (v) => notifier.updateTags([...creation.tags, v]),
                  onRemove: (v) => notifier.updateTags(
                    creation.tags.where((t) => t != v).toList(),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // Section 4: Cover & Mascot
            _FormSection(
              title: 'Cover & Mascot',
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _CoverImagePicker(
                          imageFile: creation.coverImage,
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
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MascotSelector(
                          selectedName: creation.selectedRiveElement?.name,
                          selectedThumbnail:
                              creation.selectedRiveElement?.effectiveThumbnail,
                          onTap: () => showRiveElementPicker(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Submit button
            SmoothClipRRect(
              smoothness: 0.6,
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
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
                    backgroundColor: context.actionButtonBackground,
                    foregroundColor: context.actionButtonForeground,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: const StadiumBorder(),
                  ),
                  child: creation.isSubmitting
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.actionButtonForeground,
                          ),
                        )
                      : const Text('Create Story'),
                ),
              ),
            ),

            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable section container (iOS Settings-style grouped card)
// ---------------------------------------------------------------------------

class _FormSection extends StatelessWidget {
  const _FormSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              color: context.secondaryTextColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ),
        // Grouped container
        SmoothClipRRect(
          smoothness: 0.6,
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor, width: 0.5),
          child: Container(
            width: double.infinity,
            color: context.cardBackground,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i < children.length - 1)
                    Divider(
                      height: 0.5,
                      thickness: 0.5,
                      color: context.dividerColor,
                      indent: 20,
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Chip input field for use inside _FormSection
// ---------------------------------------------------------------------------

class _ChipInputField extends StatelessWidget {
  const _ChipInputField({
    required this.label,
    required this.controller,
    required this.chips,
    required this.onAdd,
    required this.onRemove,
  });

  final String label;
  final TextEditingController controller;
  final List<String> chips;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chipBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    final chipTextColor = isDark ? Colors.white : Colors.black87;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: context.secondaryTextColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
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
                      label: Text(
                        chip,
                        style: TextStyle(color: chipTextColor, fontSize: 13),
                      ),
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
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mascot selector (compact version for side-by-side layout)
// ---------------------------------------------------------------------------

class _MascotSelector extends StatelessWidget {
  const _MascotSelector({
    required this.selectedName,
    required this.selectedThumbnail,
    required this.onTap,
  });

  final String? selectedName;
  final String? selectedThumbnail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);
    final hintColor = context.tertiaryTextColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selectedThumbnail != null && selectedThumbnail!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    selectedThumbnail!,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.smart_toy_rounded,
                      color: hintColor,
                      size: 28,
                    ),
                  ),
                )
              else
                Icon(Icons.smart_toy_rounded, color: hintColor, size: 28),
              const SizedBox(height: 8),
              Text(
                selectedName ?? 'Choose mascot',
                style: TextStyle(
                  color: selectedName != null
                      ? context.primaryTextColor
                      : hintColor,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cover image picker (compact version for side-by-side layout)
// ---------------------------------------------------------------------------

class _CoverImagePicker extends StatelessWidget {
  const _CoverImagePicker({
    required this.imageFile,
    required this.onPick,
    required this.onRemove,
  });

  final File? imageFile;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);
    final hintColor = context.tertiaryTextColor;

    if (imageFile != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.file(
              imageFile!,
              width: double.infinity,
              height: 120,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: AppCircleIconButton(
              icon: CupertinoIcons.xmark,
              onPressed: onRemove,
              size: 28,
              iconSize: 12,
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
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_photo_alternate_outlined,
                color: hintColor,
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                'Add cover',
                style: TextStyle(color: hintColor, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
