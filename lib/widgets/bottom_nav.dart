import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';

enum HomeTab { story, profile }

class BottomNav extends StatelessWidget {
  const BottomNav({super.key, required this.current, required this.onChanged});

  final HomeTab current;
  final ValueChanged<HomeTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double navWidth = (constraints.maxWidth * 0.88).clamp(
          0,
          480,
        ); // cap max width for large screens
        return Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                width: navWidth,
                height: 76,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(50),
                  // Glass morphism: subtle gradient + translucent border + shadow
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white.withOpacity(0.10), Colors.white.withOpacity(0.04)],
                  ),
                  border: Border.all(color: Colors.white.withOpacity(0.22), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                      spreadRadius: -4,
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                // Fixed order navigation items: Story | Profile
                // Selected item is highlighted but items do NOT reorder.
                child: Row(
                  children: [
                    _navItem(
                      context,
                      tab: HomeTab.story,
                      iconPath: 'assets/images/tool.png',
                      label: 'Story',
                    ),
                    _navItem(
                      context,
                      tab: HomeTab.profile,
                      iconPath: 'assets/images/profile.png',
                      label: 'Profile',
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _navItem(
    BuildContext context, {
    required HomeTab tab,
    required String iconPath,
    required String label,
  }) {
    final bool selected = current == tab;
    return Expanded(
      flex: selected ? 3 : 2,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: EdgeInsets.symmetric(horizontal: selected ? 12 : 0),
        height: 56,
        decoration: BoxDecoration(
          color: selected ? Colors.black.withOpacity(0.30) : Colors.transparent,
          borderRadius: BorderRadius.circular(50),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(50),
            onTap: () => onChanged(tab),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
            overlayColor: MaterialStatePropertyAll(Colors.transparent),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: [
                Image.asset(iconPath, width: 24, height: 24, color: Colors.white),
                Flexible(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                    child: selected
                        ? Padding(
                            key: ValueKey(label),
                            padding: const EdgeInsets.only(left: 8),
                            child: TypographyText(
                              label,
                              variant: TypographyVariant.body2,
                              color: Colors.white,
                              maxLines: 1,
                              overflow: TextOverflow.fade,
                              softWrap: false,
                            ),
                          )
                        : const SizedBox(width: 0, height: 0, key: ValueKey('empty')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
