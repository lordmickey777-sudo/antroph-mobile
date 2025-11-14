import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';
import 'package:antroph_mobile/widgets/app_button.dart';
import 'package:antroph_mobile/features/story/providers/story_session_provider.dart';

class StorySheet extends ConsumerStatefulWidget {
  const StorySheet({
    super.key,
    required this.storyId,
    required this.title,
    required this.subtitle,
    required this.imageAsset,
    this.users,
    this.views,
  });

  final String storyId;
  final String title;
  final String subtitle;
  final String imageAsset;
  final int? users;
  final int? views;

  static const _panel = Color(0xFF2A2D2F);

  @override
  ConsumerState<StorySheet> createState() => _StorySheetState();
}

class _StorySheetState extends ConsumerState<StorySheet> {
  @override
  void dispose() {
    // Clear session when sheet is closed
    ref.read(storySessionProvider.notifier).clearSession();
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottom = MediaQuery.of(context).padding.bottom;
    final sessionState = ref.watch(storySessionProvider);

    return CupertinoPageScaffold(
      backgroundColor: StorySheet._panel,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          children: [
            CustomScrollView(
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
                        _HeroCard(
                          size: size,
                          storyId: widget.storyId,
                          title: widget.title,
                          subtitle: widget.subtitle,
                          imageAsset: widget.imageAsset,
                          sessionState: sessionState,
                        ),
                        const SizedBox(height: 20),
                        TypographyText(
                          widget.subtitle,
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
            // Error snackbar
            if (sessionState.error != null)
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: _ErrorBanner(
                  message: sessionState.error!,
                  onDismiss: () => ref.read(storySessionProvider.notifier).clearError(),
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

class _HeroCard extends ConsumerWidget {
  const _HeroCard({
    required this.size,
    required this.storyId,
    required this.title,
    required this.subtitle,
    required this.imageAsset,
    required this.sessionState,
  });

  final Size size;
  final String storyId;
  final String title;
  final String subtitle;
  final String imageAsset;
  final StorySessionState sessionState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardRadius = 28.0;
    final session = sessionState.session;
    final hasSession = session != null;
    final isPaused = hasSession && session.isPaused;

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
            // Background image with network/asset handling and fallback
            AspectRatio(aspectRatio: 1.0, child: _HeroImage(image: imageAsset)),

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
                  TypographyText(title, variant: TypographyVariant.h2, color: Colors.white),
                  const SizedBox(height: 6),
                  TypographyText(subtitle, variant: TypographyVariant.body2, color: Colors.white70),
                  const SizedBox(height: 14),
                  if (sessionState.isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: CupertinoActivityIndicator(color: Colors.white),
                      ),
                    )
                  else if (!hasSession)
                    Row(
                      children: [
                        _GlassButton(
                          label: 'Play',
                          icon: CupertinoIcons.play_fill,
                          onPressed: () =>
                              ref.read(storySessionProvider.notifier).startSession(storyId),
                        ),
                        const SizedBox(width: 12),
                        _PrimaryPillButton(
                          label: 'Leave story',
                          // Pop using the root navigator to reliably close the sheet even with nested navigators
                          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                        ),
                      ],
                    )
                  else if (isPaused)
                    Row(
                      children: [
                        _GlassButton(
                          label: 'Resume',
                          icon: CupertinoIcons.play_fill,
                          onPressed: () =>
                              ref.read(storySessionProvider.notifier).playSession(storyId),
                        ),
                        const SizedBox(width: 12),
                        _PrimaryPillButton(
                          label: 'Leave story',
                          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        _GlassButton(
                          label: 'Pause',
                          icon: CupertinoIcons.pause_fill,
                          onPressed: () =>
                              ref.read(storySessionProvider.notifier).pauseSession(storyId),
                        ),
                        const SizedBox(width: 12),
                        _PrimaryPillButton(
                          label: 'Continue',
                          onPressed: () {
                            // TODO: Navigate to story playback screen
                          },
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

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.image});
  final String image;
  bool get _isNetwork => image.startsWith('http');

  @override
  Widget build(BuildContext context) {
    if (_isNetwork) {
      return Image.network(
        image,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            Image.asset('assets/images/default.png', fit: BoxFit.cover),
      );
    }
    final assetPath = image.isNotEmpty ? image : 'assets/images/default.png';
    return Image.asset(
      assetPath,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          Image.asset('assets/images/default.png', fit: BoxFit.cover),
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
        child: AppButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            backgroundColor: Colors.white.withValues(alpha: 0.18),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.30)),
            ),
            elevation: 0,
            shadowColor: Colors.transparent,
          ),
          onPressed: onPressed,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.black),
              const SizedBox(width: 8),
              TypographyText(
                label,
                variant: TypographyVariant.body2,
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ],
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
    return AppButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: const Color(0xFFFF6B7D),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      onPressed: onPressed,
      child: TypographyText(
        label,
        variant: TypographyVariant.body2,
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// Error banner widget
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade800,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.exclamationmark_circle_fill, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TypographyText(message, variant: TypographyVariant.body2, color: Colors.white),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(CupertinoIcons.xmark, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }
}
