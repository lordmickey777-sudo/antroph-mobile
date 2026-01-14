import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';
import 'package:antroph_mobile/widgets/app_button.dart';
import 'package:antroph_mobile/features/story/providers/story_providers.dart';
import 'package:antroph_mobile/features/story/providers/story_session_provider.dart';
import 'package:antroph_mobile/features/home/presentation/chat_page.dart';

class StorySheet extends ConsumerStatefulWidget {
  const StorySheet({
    super.key,
    required this.storyId,
    required this.title,
    required this.subtitle,
    required this.imageAsset,
    this.users,
    this.views,
    this.isAdded = false,
  });

  final String storyId;
  final String title;
  final String subtitle;
  final String imageAsset;
  final int? users;
  final int? views;
  final bool isAdded;

  static const _panel = Color(0xFF121516);

  @override
  ConsumerState<StorySheet> createState() => _StorySheetState();
}

class _StorySheetState extends ConsumerState<StorySheet> {
  late bool _isAdded = widget.isAdded;
  bool _isAddingToPlaylist = false;

  @override
  void didUpdateWidget(covariant StorySheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isAdded != widget.isAdded) {
      _isAdded = widget.isAdded;
    }
  }

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

    return SizedBox(
      height: size.height * 0.7,
      child: CupertinoPageScaffold(
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
                          imageAsset: widget.imageAsset,
                          sessionState: sessionState,
                          isAdded: _isAdded,
                          isAddingToPlaylist: _isAddingToPlaylist,
                          onAddToPlaylist: _handleAddToPlaylist,
                          onPlayPressed: _navigateToChat,
                        ),
                        const SizedBox(height: 20),
                        TypographyText(
                          widget.title,
                          variant: TypographyVariant.h2,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 8),
                        TypographyText(
                          widget.subtitle,
                          variant: TypographyVariant.body1,
                          color: Colors.white70,
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
      ),
    );
  }

  Future<void> _handleAddToPlaylist() async {
    if (_isAddingToPlaylist) return;
    setState(() => _isAddingToPlaylist = true);
    try {
      await ref
          .read(storiesRepositoryProvider)
          .addStoriesToPlaylist(storyIds: [widget.storyId]);
      if (!mounted) return;
      setState(() => _isAdded = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Story added to playlist')),
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add story: $err')),
      );
    } finally {
      if (mounted) {
        setState(() => _isAddingToPlaylist = false);
      }
    }
  }

  void _navigateToChat() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          storyTitle: widget.title.isNotEmpty ? widget.title : 'Chat',
          storyId: widget.storyId,
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
    required this.imageAsset,
    required this.sessionState,
    required this.isAdded,
    required this.isAddingToPlaylist,
    required this.onAddToPlaylist,
    required this.onPlayPressed,
  });

  final Size size;
  final String imageAsset;
  final StorySessionState sessionState;
  final bool isAdded;
  final bool isAddingToPlaylist;
  final VoidCallback onAddToPlaylist;
  final VoidCallback onPlayPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

            // Bottom gradient for button legibility
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 80,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0x99000000)],
                  ),
                ),
              ),
            ),

            // Button only
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: sessionState.isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: CupertinoActivityIndicator(color: Colors.white),
                      ),
                    )
                  : _ActionButton(
                      isAdded: isAdded,
                      isLoading: isAddingToPlaylist,
                      onAddPressed: isAddingToPlaylist ? null : onAddToPlaylist,
                      onPlayPressed: onPlayPressed,
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

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.isAdded,
    required this.isLoading,
    required this.onAddPressed,
    required this.onPlayPressed,
  });

  final bool isAdded;
  final bool isLoading;
  final VoidCallback? onAddPressed;
  final VoidCallback onPlayPressed;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      onPressed: isLoading
          ? null
          : isAdded
              ? onPlayPressed
              : onAddPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        backgroundColor: isAdded
            ? Colors.white
            : const Color.fromARGB(255, 15, 9, 9).withValues(alpha: 0.78),
        foregroundColor: isAdded ? Colors.black : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 0,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CupertinoActivityIndicator(color: Colors.white),
            )
          else if (isAdded)
            Icon(CupertinoIcons.play_fill, size: 18, color: Colors.black)
          else
            const Icon(Icons.playlist_add, size: 18, color: Colors.white),
          const SizedBox(width: 6),
          TypographyText(
            isLoading
                ? 'Adding...'
                : isAdded
                    ? 'Play'
                    : 'My List',
            variant: TypographyVariant.body2,
            color: isAdded ? Colors.black : Colors.white,
          ),
        ],
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
