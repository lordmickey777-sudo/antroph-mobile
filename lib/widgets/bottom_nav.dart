import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:antroph_mobile/core/responsive/responsive.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';

enum HomeTab { story, profile }

class BottomNav extends StatelessWidget {
  const BottomNav({super.key, required this.current, required this.onChanged});

  final HomeTab current;
  final ValueChanged<HomeTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive nav sizing for phone/tablet/iPad
        final maxWidth = AppSizing.navBarMaxWidth.fromConstraints(constraints);
        final double navWidth = (constraints.maxWidth * 0.88).clamp(0, maxWidth);
        final navHeight = AppSizing.navBarHeight.fromConstraints(constraints);
        return Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                width: navWidth,
                height: navHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(50),
                  // Glass morphism: subtle gradient + translucent border + shadow
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [Colors.white.withOpacity(0.10), Colors.white.withOpacity(0.04)]
                        : [Colors.black.withOpacity(0.06), Colors.black.withOpacity(0.02)],
                  ),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.22) : Colors.black.withOpacity(0.15),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.4 : 0.15),
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
                      itemHeight: navHeight - 20,
                    ),
                    _navItem(
                      context,
                      tab: HomeTab.profile,
                      iconPath: 'assets/images/profile.png',
                      label: 'Profile',
                      itemHeight: navHeight - 20,
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
    required double itemHeight,
  }) {
    final bool selected = current == tab;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : Colors.black87;
    final labelColor = isDark ? Colors.white : Colors.black87;
    final selectedBgColor = isDark ? Colors.black.withOpacity(0.30) : Colors.white.withOpacity(0.50);

    return Expanded(
      flex: selected ? 3 : 2,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: EdgeInsets.symmetric(horizontal: selected ? 12 : 0),
        height: itemHeight,
        decoration: BoxDecoration(
          color: selected ? selectedBgColor : Colors.transparent,
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
            overlayColor: WidgetStatePropertyAll(Colors.transparent),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: [
                Image.asset(iconPath, width: 24, height: 24, color: iconColor),
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
                              color: labelColor,
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
