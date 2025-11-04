import 'package:flutter/material.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';

enum HomeTab { interact, story, profile }

class BottomNav extends StatelessWidget {
  const BottomNav({super.key, required this.current, required this.onChanged});

  final HomeTab current;
  final ValueChanged<HomeTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Container(
          width: width,
          height: 76,
          decoration: BoxDecoration(
            color: const Color(0xFF2A2D2F),
            borderRadius: BorderRadius.circular(28),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              _buildLeftPill(context),
              const Spacer(),
              _iconButton(
                context,
                iconPath: 'assets/images/tool.png',
                selected: current == HomeTab.story,
                onTap: () => onChanged(HomeTab.story),
              ),
              const SizedBox(width: 16),
              _iconButton(
                context,
                iconPath: 'assets/images/profile.png',
                selected: current == HomeTab.profile,
                onTap: () => onChanged(HomeTab.profile),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLeftPill(BuildContext context) {
    String label;
    String iconPath;
    HomeTab leftTab;
    if (current == HomeTab.profile) {
      label = 'Profile';
      iconPath = 'assets/images/profile.png';
      leftTab = HomeTab.profile;
    } else if (current == HomeTab.story) {
      label = 'Story';
      iconPath = 'assets/images/tool.png';
      leftTab = HomeTab.story;
    } else {
      label = 'Interact';
      iconPath = 'assets/images/chat.png';
      leftTab = HomeTab.interact;
    }

    return GestureDetector(
      onTap: () => onChanged(leftTab),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  iconPath,
                  width: 24,
                  height: 24,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                TypographyText(
                  label,
                  variant: TypographyVariant.body2,
                  color: Colors.white,
                ),
              ],
            ),
          ),
          if (current == HomeTab.interact)
            Positioned(
              left: -4,
              top: -4,
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFF23D18B),
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _iconButton(
    BuildContext context, {
    required String iconPath,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: SizedBox(
        height: 56,
        width: 56,
        child: Center(
          child: Image.asset(
            iconPath,
            width: 24,
            height: 24,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
