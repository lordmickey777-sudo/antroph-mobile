import 'package:flutter/material.dart';
import 'package:antroph_mobile/core/theme/theme_provider.dart';

import '../models/community_story_model.dart';
import 'moderation_status_badge.dart';

/// Reusable card for displaying a community story in lists/grids.
class CommunityStoryCard extends StatelessWidget {
  const CommunityStoryCard({
    super.key,
    required this.story,
    this.onTap,
    this.showStatus = true,
  });

  final CommunityStoryDto story;
  final VoidCallback? onTap;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.06);
    final titleColor = context.primaryTextColor;
    final subtitleColor = context.secondaryTextColor;
    final tertiaryColor = context.tertiaryTextColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            if (story.coverImageUrl != null &&
                story.coverImageUrl!.isNotEmpty)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  story.coverImageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _PlaceholderCover(isDark: isDark),
                ),
              )
            else
              _PlaceholderCover(isDark: isDark),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showStatus) ...[
                    ModerationStatusBadge(status: story.moderationStatus),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    story.title,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (story.description != null &&
                      story.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      story.description!,
                      style: TextStyle(color: subtitleColor, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (story.tone != null) ...[
                        Icon(Icons.mood_rounded, size: 14, color: tertiaryColor),
                        const SizedBox(width: 4),
                        Text(
                          story.tone!,
                          style: TextStyle(color: tertiaryColor, fontSize: 12),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Icon(Icons.calendar_today_rounded, size: 14, color: tertiaryColor),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(story.createdAt),
                        style: TextStyle(color: tertiaryColor, fontSize: 12),
                      ),
                    ],
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

String _formatDate(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}';
}

class _PlaceholderCover extends StatelessWidget {
  const _PlaceholderCover({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.04),
        child: Icon(
          Icons.auto_stories_rounded,
          size: 40,
          color: isDark
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.black.withValues(alpha: 0.12),
        ),
      ),
    );
  }
}
