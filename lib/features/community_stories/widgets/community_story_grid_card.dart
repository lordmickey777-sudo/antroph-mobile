import 'package:flutter/material.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:antroph_mobile/core/theme/theme_provider.dart';

import '../models/community_story_model.dart';
import 'moderation_status_badge.dart';

/// Pinterest-style vertical card for displaying a community story in a grid.
/// Cover image fills the card with title overlaid at the bottom.
class CommunityStoryGridCard extends StatelessWidget {
  static const String placeholderAsset = 'assets/images/default.png';

  const CommunityStoryGridCard({
    super.key,
    required this.story,
    this.onTap,
    this.onLongPress,
  });

  final CommunityStoryDto story;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  String? _resolveImageUrl() {
    if (story.coverImageUrl != null && story.coverImageUrl!.isNotEmpty) {
      return story.coverImageUrl;
    }
    final thumb = story.riveElement?.thumbnailUrl;
    if (thumb != null && thumb.isNotEmpty && thumb.startsWith('http')) {
      return thumb;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: SmoothClipRRect(
        smoothness: 0.6,
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: 0.5),
        child: Container(
          color: context.cardBackground,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Cover image
              _buildCoverImage(context),

              // Gradient overlay at bottom
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 90,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                ),
              ),

              // Status badge — top right
              if (story.moderationStatus != 'published')
                Positioned(
                  top: 8,
                  right: 8,
                  child: ModerationStatusBadge(status: story.moderationStatus),
                ),

              // Title + date — bottom
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      story.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(story.createdAt),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverImage(BuildContext context) {
    final imageUrl = _resolveImageUrl();

    if (imageUrl != null) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Image.asset(
      placeholderAsset,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const ColoredBox(
        color: Color(0xFFD4D4D8),
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
