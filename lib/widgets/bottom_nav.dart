import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:antroph_mobile/core/responsive/responsive.dart';

enum HomeTab { story, create, hardware, profile }

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
        final double navWidth = (constraints.maxWidth * 0.65).clamp(0, maxWidth);
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    _navItem(
                      context,
                      tab: HomeTab.story,
                      icon: Icons.auto_stories_rounded,
                      activeIcon: Icons.auto_stories_rounded,
                      itemHeight: navHeight - 16,
                    ),
                    _navItem(
                      context,
                      tab: HomeTab.create,
                      icon: Icons.add_circle_outline_rounded,
                      activeIcon: Icons.add_circle_rounded,
                      itemHeight: navHeight - 16,
                    ),
                    _navItem(
                      context,
                      tab: HomeTab.hardware,
                      icon: Icons.memory_outlined,
                      activeIcon: Icons.memory_rounded,
                      itemHeight: navHeight - 16,
                    ),
                    _navItem(
                      context,
                      tab: HomeTab.profile,
                      icon: Icons.person_outline_rounded,
                      activeIcon: Icons.person_rounded,
                      itemHeight: navHeight - 16,
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
    required IconData icon,
    required IconData activeIcon,
    required double itemHeight,
  }) {
    final bool selected = current == tab;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : Colors.black87;
    final unselectedIconColor = isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.4);
    final selectedBgColor = isDark ? Colors.black.withOpacity(0.30) : Colors.white.withOpacity(0.50);

    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 4),
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
            child: Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: selected ? 1.0 : 0.85, end: selected ? 1.0 : 0.85),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: child,
                  );
                },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    selected ? activeIcon : icon,
                    key: ValueKey('$tab-$selected'),
                    size: 26,
                    color: selected ? iconColor : unselectedIconColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
