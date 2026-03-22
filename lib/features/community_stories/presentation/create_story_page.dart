import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:glass_kit/glass_kit.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:antroph_mobile/core/auth/utils/auth_guard.dart';
import 'package:antroph_mobile/core/responsive/responsive.dart';
import 'package:antroph_mobile/core/theme/theme_provider.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';

import 'story_form_page.dart';
import 'my_stories_page.dart';
import 'standard_story_guide_page.dart';

class CreateStoryPage extends ConsumerWidget {
  const CreateStoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final horizontalPadding = AppPadding.horizontal.of(context);

    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Column(
                  children: [
                    const SizedBox(height: 24),

                    _CreateHeaderBanner(
                      isDark: isDark,
                      onTap: () {
                        Navigator.of(
                          context,
                        ).push(MaterialPageRoute(builder: (_) => const StandardStoryGuidePage()));
                      },
                    ),

                    const SizedBox(height: 28),

                    // Tagline
                    TypographyText(
                      'Bring stories to life',
                      variant: TypographyVariant.h3,
                      color: context.primaryTextColor,
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 40),

                    Row(
                      children: [
                        Expanded(
                          child: _GlassActionCard(
                            accentColor: const Color(0xFF1FBFA6),
                            imageAsset: 'assets/images/btn1.png',
                            title: 'New Story',
                            subtitle: 'Start fresh',
                            isDark: isDark,
                            onTap: () async {
                              final result = await showAuthGuardSheet(
                                context,
                                ref,
                                actionDescription: 'Create a new story',
                              );
                              if (!context.mounted) return;
                              if (result == AuthGuardResult.authenticated ||
                                  result == AuthGuardResult.loginSuccessful) {
                                Navigator.of(
                                  context,
                                ).push(MaterialPageRoute(builder: (_) => const StoryFormPage()));
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _GlassActionCard(
                            accentColor: const Color(0xFFFED405),
                            imageAsset: 'assets/images/btn2.png',
                            title: 'My Stories',
                            subtitle: 'Open drafts',
                            isDark: isDark,
                            onTap: () async {
                              final result = await showAuthGuardSheet(
                                context,
                                ref,
                                actionDescription: 'View your stories',
                              );
                              if (!context.mounted) return;
                              if (result == AuthGuardResult.authenticated ||
                                  result == AuthGuardResult.loginSuccessful) {
                                Navigator.of(
                                  context,
                                ).push(MaterialPageRoute(builder: (_) => const MyStoriesPage()));
                              }
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateHeaderBanner extends StatelessWidget {
  const _CreateHeaderBanner({required this.isDark, required this.onTap});

  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);
    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.26)
        : Colors.black.withValues(alpha: 0.08);
    final badgeColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.56);
    const royalBlue = Color(0xFF5B5FEF);
    const aqua = Color(0xFF1FBFA6);
    const yellow = Color(0xFFFED405);

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: SmoothClipRRect(
        smoothness: 0.6,
        borderRadius: BorderRadius.circular(32),
        side: BorderSide(color: borderColor, width: 0.5),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 164),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      royalBlue.withValues(alpha: 0.48),
                      aqua.withValues(alpha: 0.34),
                      const Color(0xFF151824),
                    ]
                  : [
                      royalBlue.withValues(alpha: 0.28),
                      aqua.withValues(alpha: 0.22),
                      yellow.withValues(alpha: 0.38),
                    ],
            ),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 28,
                offset: const Offset(0, 16),
                spreadRadius: -12,
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -26,
                top: -34,
                child: _BannerGlow(
                  size: 130,
                  colors: isDark
                      ? [yellow.withValues(alpha: 0.34), const Color(0x00FED405)]
                      : [yellow.withValues(alpha: 0.58), const Color(0x00FED405)],
                ),
              ),
              Positioned(
                left: -24,
                bottom: -46,
                child: _BannerGlow(
                  size: 144,
                  colors: isDark
                      ? [aqua.withValues(alpha: 0.30), const Color(0x001FBFA6)]
                      : [royalBlue.withValues(alpha: 0.42), const Color(0x005B5FEF)],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset('assets/images/app_logo.png', width: 24, height: 24),
                          const SizedBox(width: 8),
                          TypographyText(
                            'Guide',
                            variant: TypographyVariant.body2,
                            color: context.primaryTextColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 244),
                      child: TypographyText(
                        'How to create stories',
                        variant: TypographyVariant.h4,
                        color: context.primaryTextColor,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 220),
                          child: TypographyText(
                            'Learn the clean structure before you start writing.',
                            variant: TypographyVariant.body2,
                            color: context.primaryTextColor,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Container(
                            width: 46,
                            height: 46,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.black,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
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
}

class _GlassActionCard extends StatelessWidget {
  const _GlassActionCard({
    required this.accentColor,
    required this.imageAsset,
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.onTap,
  });

  final Color accentColor;
  final String imageAsset;
  final String title;
  final String subtitle;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);
    final surfaceColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.white.withValues(alpha: 0.82);
    final iconBgColor = accentColor.withValues(alpha: isDark ? 0.24 : 0.16);
    final imageBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: SmoothClipRRect(
        smoothness: 0.6,
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: borderColor, width: 0.5),
        child: GlassContainer.frostedGlass(
          height: 226,
          blur: 12,
          frostedOpacity: 0.05,
          color: surfaceColor,
          borderRadius: BorderRadius.circular(24),
          borderWidth: 0,
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 96,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: iconBgColor,
                          border: Border.all(color: imageBorderColor),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      Positioned.fill(child: Image.asset(imageAsset, fit: BoxFit.cover)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  color: context.primaryTextColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(color: context.secondaryTextColor, fontSize: 13, height: 1.25),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_forward_rounded, color: Colors.black, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BannerGlow extends StatelessWidget {
  const _BannerGlow({required this.size, required this.colors});

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: colors),
        ),
      ),
    );
  }
}
