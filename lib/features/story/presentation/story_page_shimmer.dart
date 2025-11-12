import 'dart:math';

import 'package:flutter/material.dart';
import 'package:antroph_mobile/widgets/shimmer.dart';

/// A complete shimmer layout for the Story page that mirrors the real UI.
/// Keep shimmer logic out of the view/page files.
class StoryPageShimmer extends StatelessWidget {
  const StoryPageShimmer({super.key, this.sections = 2, this.cardsPerSection = 4});
  final int sections;
  final int cardsPerSection;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: ShimmerBox(width: 180, height: 28, radius: 6),
          ),
        ),
        for (int s = 0; s < sections; s++)
          SliverToBoxAdapter(
            child: SizedBox(height: 340, child: _StorySectionShimmer(cards: cardsPerSection)),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }
}

class _StorySectionShimmer extends StatelessWidget {
  const _StorySectionShimmer({required this.cards});
  final int cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Reserve space similar to the label + paddings in the real page
        const sideLabelArea = 28.0 + 8.0 + 8.0; // width + spacers
        final available = max(200.0, constraints.maxWidth - sideLabelArea - 20.0);
        final cardWidth = available.clamp(200.0, 260.0);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: 8),
            const SideLabelShimmer(),
            const SizedBox(width: 8),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.only(right: 20),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) => StoryCardShimmer(width: cardWidth.toDouble()),
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemCount: cards,
              ),
            ),
          ],
        );
      },
    );
  }
}

class SideLabelShimmer extends StatelessWidget {
  const SideLabelShimmer({super.key});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      child: Center(
        child: Transform.rotate(
          angle: -1.5708, // ~ -90 degrees
          child: const ShimmerBox(width: 120, height: 16, radius: 4),
        ),
      ),
    );
  }
}

class StoryCardShimmer extends StatelessWidget {
  const StoryCardShimmer({super.key, this.width = 220});
  final double width;

  @override
  Widget build(BuildContext context) {
    const cardRadius = 20.0;
    return SizedBox(
      width: width,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1B1E20),
              borderRadius: BorderRadius.circular(cardRadius),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: LayoutBuilder(
                builder: (context, c) {
                  final innerW = c.maxWidth - 24; // account for inner horizontal padding below
                  final titleW = innerW * 0.70;
                  final subW = innerW * 0.52;
                  final statW = innerW * 0.22;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                        child: const AspectRatio(aspectRatio: 1.2, child: ShimmerBox()),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerBox(width: titleW, height: 14, radius: 4),
                            const SizedBox(height: 6),
                            ShimmerBox(width: subW, height: 12, radius: 4),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                ShimmerBox(width: statW, height: 12, radius: 4),
                                const SizedBox(width: 14),
                                ShimmerBox(width: statW, height: 12, radius: 4),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
