import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';
import 'package:antroph_mobile/widgets/app_button.dart';
import 'package:antroph_mobile/features/story/presentation/story_sheet.dart';
import 'package:antroph_mobile/features/story/models/story_models.dart';
import 'package:antroph_mobile/features/story/providers/story_providers.dart';
import 'package:antroph_mobile/core/network/error_formatter.dart';
import 'package:antroph_mobile/features/story/presentation/story_page_shimmer.dart';
import 'package:antroph_mobile/features/story/presentation/collections_page.dart';
import 'package:antroph_mobile/features/story/presentation/collections_action_button.dart';
import 'package:antroph_mobile/widgets/empty_state.dart';

class StoryPage extends ConsumerWidget {
  const StoryPage({super.key});

  static const _bg = Color(0xFF121516);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncHome = ref.watch(storiesHomeSectionsProvider);
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Stack(
          children: [
            asyncHome.when(
              loading: () => const StoryPageShimmer(),
              error: (err, st) {
                final msg = err is ApiError ? err.message : 'Failed to load stories.';
                return _ErrorView(
                  message: msg,
                  onRetry: () => ref.refresh(storiesHomeSectionsProvider.future),
                );
              },
              data: (data) {
                final sections = data.sections;
                if (sections.isEmpty) return const _EmptyView();
                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
                        child: TypographyText(
                          'Story Mode',
                          variant: TypographyVariant.h1,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    for (final section in sections)
                      _SectionSliver(section: section, onTap: (card) => _openStory(context, card)),
                    const SliverToBoxAdapter(child: SizedBox(height: 120)),
                  ],
                );
              },
            ),
            Positioned(
              top: 12,
              right: 16,
              child: CollectionsActionButton(onPressed: () => _openCollections(context)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openStory(BuildContext context, StoryCardDto card) async {
    await showCupertinoModalBottomSheet(
      context: context,
      expand: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StorySheet(
        storyId: card.storyId,
        title: card.title,
        subtitle: card.subtitle,
        imageAsset: card.image,
        users: card.users,
        views: card.views,
      ),
    );
  }

  void _openCollections(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CollectionsPage()));
  }
}

class _SectionSliver extends StatelessWidget {
  const _SectionSliver({required this.section, required this.onTap});

  final StorySectionDto section;
  final Future<void> Function(StoryCardDto) onTap;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 340,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: 8),
            _SideLabel(text: section.title),
            const SizedBox(width: 8),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.only(right: 20),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  final item = section.items[index];
                  return _StoryCard(item: item, onTap: () => onTap(item));
                },
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemCount: section.items.length,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideLabel extends StatelessWidget {
  const _SideLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return RotatedBox(
      quarterTurns: 3,
      child: Opacity(
        opacity: 0.8,
        child: Align(
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.only(left: 40.0),
            child: TypographyText(text, variant: TypographyVariant.body1, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({required this.item, required this.onTap});

  final StoryCardDto item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const cardRadius = 8.0;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 220,
        child: Column(
          children: [
            // Card visual
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1B1E20),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(cardRadius),
                        topRight: Radius.circular(cardRadius),
                      ),
                      child: AspectRatio(aspectRatio: 1.2, child: _StoryImage(image: item.image)),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TypographyText(
                            item.title,
                            variant: TypographyVariant.body1,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 4),
                          TypographyText(
                            item.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            variant: TypographyVariant.body2,
                            color: Colors.white70,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(CupertinoIcons.person_2, size: 14, color: Colors.white60),
                              const SizedBox(width: 6),
                              TypographyText(
                                '${item.users}',
                                variant: TypographyVariant.body2,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 14),
                              const Icon(CupertinoIcons.eye, size: 14, color: Colors.white60),
                              const SizedBox(width: 6),
                              TypographyText(
                                '${item.views}',
                                variant: TypographyVariant.body2,
                                color: Colors.white70,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _StoryImage extends StatelessWidget {
  const _StoryImage({required this.image});
  final String image;
  bool get _isNetwork => image.startsWith('http');

  @override
  Widget build(BuildContext context) {
    if (_isNetwork) {
      return Image.network(
        image,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset('assets/images/default.png', fit: BoxFit.cover);
        },
      );
    }
    // Fallback to asset path from API examples or local assets
    final assetPath = image.isNotEmpty ? image : 'assets/images/default.png';
    return Image.asset(
      assetPath,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset('assets/images/default.png', fit: BoxFit.cover);
      },
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      title: 'No stories available yet',
      description: 'Check back later so you don\'t miss new releases.',
      assetPath: 'assets/images/antroph_happy.png',
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      title: message,
      description: 'Tap below to try again.',
      assetPath: 'assets/images/antroph_surprised.png',
      actionLabel: 'Retry',
      onAction: () => onRetry(),
    );
  }
}
