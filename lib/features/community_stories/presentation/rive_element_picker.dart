import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:antroph_mobile/core/theme/theme_provider.dart';
import 'package:antroph_mobile/widgets/app_bottom_sheet.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';

import '../models/rive_element_model.dart';
import '../providers/community_stories_providers.dart';
import '../providers/story_creation_provider.dart';

/// Opens a bottom sheet to pick a Rive element (mascot).
Future<void> showRiveElementPicker(BuildContext context) {
  return showAppBottomSheet(
    context: context,
    builder: (context, scrollController) => _RiveElementPickerContent(
      scrollController: scrollController,
    ),
  );
}

class _RiveElementPickerContent extends ConsumerStatefulWidget {
  const _RiveElementPickerContent({required this.scrollController});

  final ScrollController scrollController;

  @override
  ConsumerState<_RiveElementPickerContent> createState() =>
      _RiveElementPickerContentState();
}

class _RiveElementPickerContentState
    extends ConsumerState<_RiveElementPickerContent> {
  String? _selectedCategory;

  static const _categories = <String?, String>{
    null: 'All',
    'character': 'Character',
    'narrator': 'Narrator',
    'companion': 'Companion',
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = context.primaryTextColor;
    final asyncElements = ref.watch(riveElementsProvider(_selectedCategory));
    final currentSelection =
        ref.watch(storyCreationProvider.select((s) => s.selectedRiveElement));

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TypographyText(
                'Choose Mascot',
                variant: TypographyVariant.h4,
                color: textColor,
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    color: textColor,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Category filter chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _categories.entries.map((entry) {
                final isSelected = _selectedCategory == entry.key;
                final chipBg = isSelected
                    ? (isDark ? Colors.white : Colors.black)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06));
                final chipFg = isSelected
                    ? (isDark ? Colors.black : Colors.white)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.7)
                        : Colors.black.withValues(alpha: 0.6));

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedCategory = entry.key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: chipBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        entry.value,
                        style: TextStyle(
                          color: chipFg,
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Grid
        Expanded(
          child: asyncElements.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Text(
                'Failed to load mascots',
                style: TextStyle(color: context.secondaryTextColor),
              ),
            ),
            data: (elements) {
              if (elements.isEmpty) {
                return Center(
                  child: Text(
                    'No mascots available',
                    style: TextStyle(color: context.secondaryTextColor),
                  ),
                );
              }

              return GridView.builder(
                controller: widget.scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                itemCount: elements.length,
                itemBuilder: (context, index) {
                  final element = elements[index];
                  final isSelected = currentSelection?.id == element.id;
                  return _ElementCard(
                    element: element,
                    isSelected: isSelected,
                    isDark: isDark,
                    onTap: () {
                      ref
                          .read(storyCreationProvider.notifier)
                          .selectRiveElement(element);
                      Navigator.of(context).maybePop();
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ElementCard extends StatelessWidget {
  const _ElementCard({
    required this.element,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  final RiveElementDto element;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white;
    final borderColor = isSelected
        ? (isDark ? Colors.white : Colors.black)
        : (isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.06));
    final textColor = context.primaryTextColor;
    final subtitleColor = context.secondaryTextColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  if (element.effectiveThumbnail.isNotEmpty)
                    Positioned.fill(
                      child: Image.network(
                        element.effectiveThumbnail,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _Placeholder(isDark: isDark),
                      ),
                    )
                  else
                    _Placeholder(isDark: isDark),
                  if (isSelected)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white : Colors.black,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          color: isDark ? Colors.black : Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    element.name,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    element.category,
                    style: TextStyle(color: subtitleColor, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isDark
          ? Colors.white.withValues(alpha: 0.04)
          : Colors.black.withValues(alpha: 0.04),
      child: Center(
        child: Icon(
          Icons.smart_toy_rounded,
          size: 36,
          color: isDark
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.black.withValues(alpha: 0.12),
        ),
      ),
    );
  }
}
