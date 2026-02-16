import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:antroph_mobile/features/home/presentation/chat_page.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';

import '../models/rive_element_model.dart';
import '../providers/community_stories_providers.dart';
import 'my_stories_page.dart';

/// Wraps [ChatPage] in preview mode so the user can voice-test their story
/// before it goes through moderation.
class StoryPreviewPage extends ConsumerWidget {
  const StoryPreviewPage({
    super.key,
    required this.storyId,
    required this.storyTitle,
    this.riveElement,
  });

  final String storyId;
  final String storyTitle;
  final RiveElementDto? riveElement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bannerBg = isDark
        ? const Color(0xFF1B2530)
        : const Color(0xFFE8F0FE);
    final bannerText = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      body: Column(
        children: [
          // Preview banner
          SafeArea(
            bottom: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: bannerBg,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(
                      CupertinoIcons.back,
                      color: bannerText,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.preview_rounded,
                    color: bannerText.withValues(alpha: 0.7),
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TypographyText(
                      'Preview: $storyTitle',
                      variant: TypographyVariant.body2,
                      color: bannerText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      ref.invalidate(myStoriesProvider);
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => const MyStoriesPage(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.black.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.book,
                            color: bannerText,
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'My Stories',
                            style: TextStyle(
                              color: bannerText,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.black.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Done',
                        style: TextStyle(
                          color: bannerText,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Chat page for voice preview
          Expanded(
            child: ChatPage(
              storyId: storyId,
              storyTitle: storyTitle,
              mascotConfig: riveElement?.toMascotConfig(),
            ),
          ),
        ],
      ),
    );
  }
}
