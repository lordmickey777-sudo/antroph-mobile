import 'package:antroph_mobile/core/auth/utils/auth_guard.dart';
import 'package:antroph_mobile/core/responsive/responsive.dart';
import 'package:antroph_mobile/core/theme/theme_provider.dart';
import 'package:antroph_mobile/widgets/app_button.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smooth_corner/smooth_corner.dart';

import 'story_form_page.dart';

class StandardStoryGuidePage extends ConsumerWidget {
  const StandardStoryGuidePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final horizontalPadding = AppPadding.horizontal.of(context);

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: TypographyText(
          'How to create stories',
          variant: TypographyVariant.h4,
          color: context.primaryTextColor,
        ),
        leading: IconButton(
          icon: Icon(
            CupertinoIcons.back,
            color: context.primaryTextColor,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          8,
          horizontalPadding,
          32,
        ),
        children: [
          _GuideHero(isDark: isDark),
          const SizedBox(height: 20),
          const _GuideSection(
            step: '1',
            title: 'Start with one clear premise',
            body:
                'Keep the setup simple. Pick one setting, one main goal, and one problem the reader can understand immediately.',
          ),
          const SizedBox(height: 14),
          const _GuideSection(
            step: '2',
            title: 'Use a familiar structure',
            body:
                'A standard story works best when it moves cleanly from opening, to tension, to resolution. Avoid too many branches too early.',
          ),
          const SizedBox(height: 14),
          const _GuideSection(
            step: '3',
            title: 'Keep characters easy to track',
            body:
                'Use two or three important characters with distinct roles. Give each one a clear voice or function in the story.',
          ),
          const SizedBox(height: 14),
          const _GuideSection(
            step: '4',
            title: 'End with a satisfying turn',
            body:
                'Close the story with a decision, reveal, or emotional payoff. Readers should feel that the original problem actually moved forward.',
          ),
          const SizedBox(height: 24),
          _GuideChecklist(isDark: isDark),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              onPressed: () async {
                final result = await showAuthGuardSheet(
                  context,
                  ref,
                  actionDescription: 'Start creating a story',
                );
                if (!context.mounted) return;
                if (result == AuthGuardResult.authenticated ||
                    result == AuthGuardResult.loginSuccessful) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const StoryFormPage()),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(58),
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Start creating',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideHero extends StatelessWidget {
  const _GuideHero({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);

    return SmoothClipRRect(
      smoothness: 0.6,
      borderRadius: BorderRadius.circular(28),
      side: BorderSide(color: borderColor, width: 0.5),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF5B5FEF).withValues(alpha: 0.36),
                    const Color(0xFF1FBFA6).withValues(alpha: 0.24),
                    const Color(0xFF171B23),
                  ]
                : [
                    const Color(0xFF5B5FEF).withValues(alpha: 0.18),
                    const Color(0xFF1FBFA6).withValues(alpha: 0.16),
                    const Color(0xFFFED405).withValues(alpha: 0.18),
                  ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(999),
              ),
              child: TypographyText(
                'Before you write',
                variant: TypographyVariant.body2,
                color: context.primaryTextColor,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 14),
            TypographyText(
              'Standard stories are strongest when the structure is obvious.',
              variant: TypographyVariant.h4,
              color: context.primaryTextColor,
              fontWeight: FontWeight.w700,
              height: 1.18,
            ),
            const SizedBox(height: 10),
            TypographyText(
              'Think in four parts: setup, rising tension, key choice, and payoff. Keep it readable before making it ambitious.',
              variant: TypographyVariant.body2,
              color: context.secondaryTextColor,
              height: 1.4,
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideSection extends StatelessWidget {
  const _GuideSection({
    required this.step,
    required this.title,
    required this.body,
  });

  final String step;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);

    return SmoothClipRRect(
      smoothness: 0.6,
      borderRadius: BorderRadius.circular(24),
      side: BorderSide(color: borderColor, width: 0.5),
      child: Container(
        color: context.cardBackground,
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.10),
                  width: 0.5,
                ),
              ),
              child: Center(
                child: TypographyText(
                  step,
                  variant: TypographyVariant.body2,
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TypographyText(
                    title,
                    variant: TypographyVariant.body1,
                    color: context.primaryTextColor,
                    fontWeight: FontWeight.w700,
                  ),
                  const SizedBox(height: 6),
                  TypographyText(
                    body,
                    variant: TypographyVariant.body2,
                    color: context.secondaryTextColor,
                    height: 1.45,
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

class _GuideChecklist extends StatelessWidget {
  const _GuideChecklist({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);

    return SmoothClipRRect(
      smoothness: 0.6,
      borderRadius: BorderRadius.circular(24),
      side: BorderSide(color: borderColor, width: 0.5),
      child: Container(
        color: context.cardBackground,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            _ChecklistRow(label: 'One strong main idea'),
            SizedBox(height: 10),
            _ChecklistRow(label: 'A clear conflict'),
            SizedBox(height: 10),
            _ChecklistRow(label: 'Simple character roles'),
            SizedBox(height: 10),
            _ChecklistRow(label: 'A definite ending'),
          ],
        ),
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 16,
            color: Colors.black,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TypographyText(
            label,
            variant: TypographyVariant.body2,
            color: context.primaryTextColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
