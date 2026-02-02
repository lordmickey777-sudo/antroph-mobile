import 'package:flutter/material.dart';

import 'package:antroph_mobile/core/responsive/responsive.dart';
import 'package:antroph_mobile/core/theme/theme_provider.dart';
import 'package:antroph_mobile/widgets/shimmer.dart';

/// A complete shimmer layout for the Story page that mirrors the real UI.
/// Keep shimmer logic out of the view/page files.
class StoryPageShimmer extends StatelessWidget {
  const StoryPageShimmer({
    super.key,
    this.sections = 2,
    this.cardsPerSection = 4,
    this.featuredCards = 2,
  });
  final int sections;
  final int cardsPerSection;
  final int featuredCards;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: _StoryHeaderShimmer(),
          ),
        ),
        SliverToBoxAdapter(
          child: _FeaturedStoriesShimmer(cards: featuredCards),
        ),
        for (int s = 0; s < sections; s++)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 220,
              child: _StorySectionShimmer(cards: cardsPerSection),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }
}

class _StoryHeaderShimmer extends StatelessWidget {
  const _StoryHeaderShimmer();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Row(
        children: const [
          ShimmerCircle(size: 34),
          SizedBox(width: 8),
          ShimmerText(width: 120, height: 22),
        ],
      ),
    );
  }
}

class _FeaturedStoriesShimmer extends StatefulWidget {
  const _FeaturedStoriesShimmer({required this.cards});
  final int cards;

  @override
  State<_FeaturedStoriesShimmer> createState() => _FeaturedStoriesShimmerState();
}

class _FeaturedStoriesShimmerState extends State<_FeaturedStoriesShimmer> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = AppPadding.large.of(context);
    final cardCount = widget.cards <= 0 ? 1 : widget.cards;
    final indicatorCount = cardCount > 4 ? 4 : cardCount;

    return Column(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.width * 1.1,
          child: PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            itemCount: cardCount,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding * 0.1),
                child: const _FeaturedStoryCardShimmer(),
              );
            },
          ),
        ),
        if (cardCount > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(indicatorCount, (index) {
                final isActive = index == 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: isActive
                      ? const _AccentShimmerBox(width: 24, height: 8, radius: 8)
                      : const ShimmerBox(width: 8, height: 8, radius: 8),
                );
              }),
            ),
          ),
      ],
    );
  }
}

class _FeaturedStoryCardShimmer extends StatelessWidget {
  const _FeaturedStoryCardShimmer();

  @override
  Widget build(BuildContext context) {
    const cardRadius = 24.0;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(color: context.dividerColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(cardRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ShimmerBox(radius: 0),
            Positioned(
              left: 20,
              right: 20,
              bottom: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _AccentShimmerBox(width: 180, height: 18, radius: 5),
                  SizedBox(height: 8),
                  _AccentShimmerBox(width: 220, height: 12, radius: 4),
                  SizedBox(height: 6),
                  _AccentShimmerBox(width: 160, height: 12, radius: 4),
                  SizedBox(height: 16),
                  _AccentShimmerBox(width: 120, height: 36, radius: 999),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StorySectionShimmer extends StatelessWidget {
  const _StorySectionShimmer({required this.cards});
  final int cards;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 8),
        const SideLabelShimmer(),
        const SizedBox(width: 8),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(right: 10),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) => const StoryCardShimmer(),
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemCount: cards,
          ),
        ),
      ],
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
        child: RotatedBox(
          quarterTurns: 3,
          child: Opacity(
            opacity: 0.8,
            child: Padding(
              padding: const EdgeInsets.only(left: 90),
              child: _AccentShimmerBox(
                width: 80,
                height: 12,
                radius: 4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class StoryCardShimmer extends StatelessWidget {
  const StoryCardShimmer({super.key, this.width = 125});
  final double width;

  @override
  Widget build(BuildContext context) {
    const cardRadius = 16.0;
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(cardRadius),
              border: Border.all(color: context.dividerColor),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(cardRadius),
              child: AspectRatio(
                aspectRatio: 0.8,
                child: Stack(
                  fit: StackFit.expand,
                  children: const [
                    ShimmerBox(radius: 0),
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: _AccentShimmerCircle(size: 30),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const FractionallySizedBox(
            widthFactor: 0.8,
            child: _AccentShimmerBox(height: 10, radius: 4),
          ),
        ],
      ),
    );
  }
}

class _AccentShimmerBox extends StatelessWidget {
  const _AccentShimmerBox({
    this.width,
    this.height,
    this.radius = 8,
  });

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: ShimmerColors.accentColor(context),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class _AccentShimmerCircle extends StatelessWidget {
  const _AccentShimmerCircle({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: ShimmerColors.accentColor(context),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
