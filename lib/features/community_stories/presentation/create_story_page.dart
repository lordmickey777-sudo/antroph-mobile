import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:antroph_mobile/core/auth/utils/auth_guard.dart';
import 'package:antroph_mobile/core/responsive/responsive.dart';
import 'package:antroph_mobile/core/theme/theme_provider.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';

import 'story_form_page.dart';
import 'my_stories_page.dart';

class CreateStoryPage extends ConsumerWidget {
  const CreateStoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final horizontalPadding = AppPadding.horizontal.of(context);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF141718)
          : const Color(0xFFF5F5F7),
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 8),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    Image.asset(
                      'assets/images/app_logo.png',
                      width: 38,
                      height: 38,
                    ),
                    const SizedBox(width: 2),
                    TypographyText(
                      'Create',
                      variant: TypographyVariant.h3,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  TypographyText(
                    'Bring your story to life',
                    variant: TypographyVariant.body1,
                    color: context.secondaryTextColor,
                  ),
                  const SizedBox(height: 24),
                  _ActionCard(
                    icon: Icons.edit_note_rounded,
                    title: 'New Story',
                    subtitle: 'Create a new community story with AI assistance',
                    onTap: () async {
                      final result = await showAuthGuardSheet(
                        context,
                        ref,
                        actionDescription: 'Create a new story',
                      );
                      if (!context.mounted) return;
                      if (result == AuthGuardResult.authenticated ||
                          result == AuthGuardResult.loginSuccessful) {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const StoryFormPage()),
                        );
                      }
                    },
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),
                  _ActionCard(
                    icon: Icons.library_books_rounded,
                    title: 'My Stories',
                    subtitle: 'View and manage your created stories',
                    onTap: () async {
                      final result = await showAuthGuardSheet(
                        context,
                        ref,
                        actionDescription: 'View your stories',
                      );
                      if (!context.mounted) return;
                      if (result == AuthGuardResult.authenticated ||
                          result == AuthGuardResult.loginSuccessful) {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const MyStoriesPage()),
                        );
                      }
                    },
                    isDark: isDark,
                  ),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.isDark,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.06);
    final iconBgColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.05);
    final iconColor = isDark ? Colors.white : Colors.black87;
    final titleColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.6)
        : Colors.black.withValues(alpha: 0.5);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: subtitleColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: subtitleColor,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
