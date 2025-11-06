import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';

class StorySheet extends StatelessWidget {
  const StorySheet({super.key});

  static const _panel = Color(0xFF2A2D2F);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottom = MediaQuery.of(context).padding.bottom;

    return CupertinoPageScaffold(
      backgroundColor: _panel,
      child: SafeArea(
        top: false,
        bottom: false,
        child: CustomScrollView(
          // Hand control to the modal sheet so drag-to-dismiss
          // only kicks in when the scroll is at the top.
          controller: ModalScrollController.of(context),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _GrabHandle(),
                    const SizedBox(height: 16),
                    _HeroCard(size: size),
                    const SizedBox(height: 20),
                    const TypographyText(
                      'Bonjour! are you ready to have a fun experience learning french with me? Beware, you might just become an expert 🧐',
                      variant: TypographyVariant.body1,
                      color: Colors.white,
                      height: 1.35,
                    ),
                    const SizedBox(height: 16),
                    const TypographyText(
                      "Great interaction experience and you learn easily cause we'll have lots of conversations. I can tune it to how you like it too.",
                      variant: TypographyVariant.body1,
                      color: Colors.white70,
                      height: 1.35,
                    ),
                    SizedBox(height: bottom + 120), // space for floating nav overlay
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GrabHandle extends StatelessWidget {
  const _GrabHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 5,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(50),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.size});

  final Size size;

  @override
  Widget build(BuildContext context) {
    final cardRadius = 28.0;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(cardRadius),
        child: Stack(
          children: [
            // Background image
            AspectRatio(
              aspectRatio: 1.0,
              child: Image.asset('assets/images/avatar.png', fit: BoxFit.cover),
            ),

            // Top subtle inner glass border
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(cardRadius),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
                ),
              ),
            ),

            // Bottom gradient for legibility
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 160,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0x99000000), Color(0xCC000000)],
                  ),
                ),
              ),
            ),

            // Content
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TypographyText(
                    'Learn French',
                    variant: TypographyVariant.h2,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 6),
                  const TypographyText(
                    'Let Maurie teach you french',
                    variant: TypographyVariant.body2,
                    color: Colors.white70,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _GlassButton(
                        label: 'Play',
                        icon: CupertinoIcons.play_fill,
                        onPressed: () {
                          // TODO: hook into story start action
                        },
                      ),
                      const SizedBox(width: 12),
                      _PrimaryPillButton(
                        label: 'Leave story',
                        // Pop using the root navigator to reliably close the sheet even with nested navigators
                        onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
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

class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.label, required this.icon, this.onPressed});

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: TextButton.icon(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            backgroundColor: Colors.white.withValues(alpha: 0.18),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.30)),
            ),
          ),
          onPressed: onPressed,
          icon: const Icon(CupertinoIcons.play_fill, color: Colors.black),
          label: const TypographyText(
            'Play',
            variant: TypographyVariant.body2,
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _PrimaryPillButton extends StatelessWidget {
  const _PrimaryPillButton({required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: const Color(0xFFFF6B7D),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      onPressed: onPressed,
      child: const TypographyText(
        'Leave story',
        variant: TypographyVariant.body2,
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
