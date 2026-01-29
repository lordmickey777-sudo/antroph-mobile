import 'package:flutter/material.dart';
import 'package:shimmer_animation/shimmer_animation.dart';

/// Theme-aware shimmer colors that match the app's design system
class ShimmerColors {
  // Dark mode colors
  static const darkBase = Color(0xFF1B1E20);
  static const darkHighlight = Color(0xFF2D3135);
  static const darkAccent = Color(0xFF3A3F44);

  // Light mode colors
  static const lightBase = Color(0xFFE8E8EA);
  static const lightHighlight = Color(0xFFF5F5F7);
  static const lightAccent = Color(0xFFFFFFFF);

  static Color baseColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBase
        : lightBase;
  }

  static Color highlightColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkHighlight
        : lightHighlight;
  }

  static Color accentColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkAccent
        : lightAccent;
  }
}

/// Beautiful shimmer wrapper using shimmer_animation library
/// Automatically adapts to light and dark mode
class AppShimmer extends StatelessWidget {
  const AppShimmer({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1800),
    this.direction = const ShimmerDirection.fromLTRB(),
    this.enabled = true,
  });

  final Widget child;
  final Duration duration;
  final ShimmerDirection direction;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer(
      duration: duration,
      direction: direction,
      color: isDark
          ? Colors.white.withValues(alpha: 0.15)
          : Colors.white.withValues(alpha: 0.8),
      colorOpacity: isDark ? 0.2 : 0.6,
      enabled: enabled,
      child: child,
    );
  }
}

/// Skeleton box with shimmer effect - the most common placeholder
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.radius = 8,
    this.borderRadius,
  });

  final double? width;
  final double? height;
  final double radius;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: ShimmerColors.baseColor(context),
          borderRadius: borderRadius ?? BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Circular shimmer placeholder - great for avatars
class ShimmerCircle extends StatelessWidget {
  const ShimmerCircle({
    super.key,
    required this.size,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: ShimmerColors.baseColor(context),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Text line placeholder with shimmer
class ShimmerText extends StatelessWidget {
  const ShimmerText({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 4,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: ShimmerColors.baseColor(context),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Multi-line text placeholder
class ShimmerParagraph extends StatelessWidget {
  const ShimmerParagraph({
    super.key,
    this.lines = 3,
    this.lineHeight = 14,
    this.lineSpacing = 10,
    this.lastLineWidth = 0.6,
  });

  final int lines;
  final double lineHeight;
  final double lineSpacing;
  final double lastLineWidth;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(lines, (index) {
        final isLast = index == lines - 1;
        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : lineSpacing),
          child: FractionallySizedBox(
            widthFactor: isLast ? lastLineWidth : 1.0,
            child: ShimmerText(height: lineHeight),
          ),
        );
      }),
    );
  }
}

/// Card placeholder with shimmer - matches app card style
class ShimmerCard extends StatelessWidget {
  const ShimmerCard({
    super.key,
    this.width,
    this.height,
    this.radius = 16,
    this.padding = const EdgeInsets.all(16),
    this.child,
  });

  final double? width;
  final double? height;
  final double radius;
  final EdgeInsets padding;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2223) : Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: child,
    );
  }
}

/// List tile placeholder with avatar, title, and subtitle
class ShimmerListTile extends StatelessWidget {
  const ShimmerListTile({
    super.key,
    this.avatarSize = 48,
    this.hasSubtitle = true,
    this.hasTrailing = false,
    this.titleWidth = 0.6,
    this.subtitleWidth = 0.4,
  });

  final double avatarSize;
  final bool hasSubtitle;
  final bool hasTrailing;
  final double titleWidth;
  final double subtitleWidth;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ShimmerCircle(size: avatarSize),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FractionallySizedBox(
                widthFactor: titleWidth,
                child: const ShimmerText(height: 16),
              ),
              if (hasSubtitle) ...[
                const SizedBox(height: 8),
                FractionallySizedBox(
                  widthFactor: subtitleWidth,
                  child: const ShimmerText(height: 12),
                ),
              ],
            ],
          ),
        ),
        if (hasTrailing) ...[
          const SizedBox(width: 12),
          const ShimmerBox(width: 24, height: 24, radius: 6),
        ],
      ],
    );
  }
}

/// Image placeholder with shimmer - great for thumbnails
class ShimmerImage extends StatelessWidget {
  const ShimmerImage({
    super.key,
    this.width,
    this.height,
    this.radius = 12,
    this.aspectRatio,
  });

  final double? width;
  final double? height;
  final double radius;
  final double? aspectRatio;

  @override
  Widget build(BuildContext context) {
    Widget shimmerContent = AppShimmer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: ShimmerColors.baseColor(context),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );

    if (aspectRatio != null) {
      return AspectRatio(
        aspectRatio: aspectRatio!,
        child: shimmerContent,
      );
    }

    return shimmerContent;
  }
}

/// Button placeholder with shimmer
class ShimmerButton extends StatelessWidget {
  const ShimmerButton({
    super.key,
    this.width,
    this.height = 48,
    this.radius = 12,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ShimmerBox(
      width: width,
      height: height,
      radius: radius,
    );
  }
}

/// Input field placeholder with shimmer
class ShimmerInput extends StatelessWidget {
  const ShimmerInput({
    super.key,
    this.width,
    this.height = 56,
    this.radius = 12,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppShimmer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2223) : const Color(0xFFEEEEF0),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
      ),
    );
  }
}

/// Grid placeholder - useful for grid layouts
class ShimmerGrid extends StatelessWidget {
  const ShimmerGrid({
    super.key,
    this.crossAxisCount = 2,
    this.itemCount = 4,
    this.spacing = 12,
    this.aspectRatio = 1.0,
    this.radius = 12,
  });

  final int crossAxisCount;
  final int itemCount;
  final double spacing;
  final double aspectRatio;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
        childAspectRatio: aspectRatio,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => ShimmerBox(radius: radius),
    );
  }
}

/// Story card shimmer - matches the app's story card layout
class ShimmerStoryCard extends StatelessWidget {
  const ShimmerStoryCard({
    super.key,
    this.width,
    this.height = 200,
  });

  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ShimmerCard(
      width: width,
      height: height,
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ShimmerImage(
              radius: 12,
              width: double.infinity,
            ),
          ),
          const SizedBox(height: 12),
          const FractionallySizedBox(
            widthFactor: 0.7,
            child: ShimmerText(height: 18),
          ),
          const SizedBox(height: 8),
          const FractionallySizedBox(
            widthFactor: 0.5,
            child: ShimmerText(height: 12),
          ),
        ],
      ),
    );
  }
}

/// Profile header shimmer - matches profile layout
class ShimmerProfileHeader extends StatelessWidget {
  const ShimmerProfileHeader({
    super.key,
    this.avatarSize = 80,
  });

  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ShimmerCircle(size: avatarSize),
        const SizedBox(height: 16),
        const ShimmerText(width: 120, height: 20),
        const SizedBox(height: 8),
        const ShimmerText(width: 180, height: 14),
      ],
    );
  }
}

/// Chat message shimmer - matches chat bubble style
class ShimmerChatMessage extends StatelessWidget {
  const ShimmerChatMessage({
    super.key,
    this.isUser = false,
    this.lines = 2,
  });

  final bool isUser;
  final int lines;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser
              ? (isDark ? const Color(0xFF1C2533) : const Color(0xFF007AFF))
              : (isDark ? const Color(0xFF0F1720) : const Color(0xFFE9E9EB)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: ShimmerParagraph(
          lines: lines,
          lineHeight: 12,
          lineSpacing: 8,
        ),
      ),
    );
  }
}

/// Collection card shimmer - matches collections layout
class ShimmerCollectionCard extends StatelessWidget {
  const ShimmerCollectionCard({
    super.key,
    this.height = 120,
  });

  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          ShimmerImage(
            width: double.infinity,
            height: height,
            radius: 0,
          ),
          Positioned(
            left: 16,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerText(width: 100, height: 18),
                SizedBox(height: 4),
                ShimmerText(width: 60, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Navigation item shimmer - matches bottom nav style
class ShimmerNavItem extends StatelessWidget {
  const ShimmerNavItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: const [
        ShimmerBox(width: 24, height: 24, radius: 6),
        SizedBox(height: 4),
        ShimmerText(width: 32, height: 10),
      ],
    );
  }
}

/// Full page loading shimmer wrapper
class ShimmerLoadingPage extends StatelessWidget {
  const ShimmerLoadingPage({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}
