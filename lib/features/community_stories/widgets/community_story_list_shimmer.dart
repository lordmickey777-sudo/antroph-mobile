import 'package:flutter/material.dart';
import 'package:antroph_mobile/core/theme/theme_provider.dart';
import 'package:antroph_mobile/widgets/shimmer.dart';

class CommunityStoryListShimmer extends StatelessWidget {
  const CommunityStoryListShimmer({
    super.key,
    this.cards = 4,
    this.showStatus = false,
  });

  final int cards;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    return ShimmerLoadingPage(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: cards,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (_, __) =>
            CommunityStoryCardShimmer(showStatus: showStatus),
      ),
    );
  }
}

class CommunityStoryCardShimmer extends StatelessWidget {
  const CommunityStoryCardShimmer({super.key, required this.showStatus});

  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AspectRatio(
            aspectRatio: 16 / 9,
            child: ShimmerBox(
              radius: 0,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showStatus) ...[
                  const ShimmerBox(width: 88, height: 24, radius: 999),
                  const SizedBox(height: 8),
                ],
                const ShimmerText(height: 16),
                const SizedBox(height: 8),
                const FractionallySizedBox(
                  widthFactor: 0.85,
                  child: ShimmerText(height: 13),
                ),
                const SizedBox(height: 4),
                const FractionallySizedBox(
                  widthFactor: 0.62,
                  child: ShimmerText(height: 13),
                ),
                const SizedBox(height: 10),
                Row(
                  children: const [
                    ShimmerCircle(size: 14),
                    SizedBox(width: 6),
                    ShimmerBox(width: 72, height: 12, radius: 4),
                    SizedBox(width: 14),
                    ShimmerCircle(size: 14),
                    SizedBox(width: 6),
                    ShimmerBox(width: 56, height: 12, radius: 4),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
