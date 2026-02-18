import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:glass_kit/glass_kit.dart';

enum HomeTab { story, create, hardware, profile }

extension _HomeTabLabel on HomeTab {
  String get label {
    switch (this) {
      case HomeTab.story:
        return 'Stories';
      case HomeTab.create:
        return 'Create';
      case HomeTab.hardware:
        return 'Hardware';
      case HomeTab.profile:
        return 'Profile';
    }
  }

  String get assetPath {
    switch (this) {
      case HomeTab.story:
        return 'assets/icons/story-com.svg';
      case HomeTab.create:
        return 'assets/icons/create.svg';
      case HomeTab.hardware:
        return 'assets/icons/hardware.svg';
      case HomeTab.profile:
        return 'assets/icons/profile.svg';
    }
  }

  /// Pill width when selected (icon + gap + text + visual padding).
  double get pillWidth {
    switch (this) {
      case HomeTab.story:
        return 124;
      case HomeTab.create:
        return 116;
      case HomeTab.hardware:
        return 132;
      case HomeTab.profile:
        return 118;
    }
  }
}

class BottomNav extends StatelessWidget {
  const BottomNav({super.key, required this.current, required this.onChanged});

  final HomeTab current;
  final ValueChanged<HomeTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _NavGlassItem(
            tab: HomeTab.story,
            selected: current == HomeTab.story,
            onTap: () => onChanged(HomeTab.story),
          ),
          const SizedBox(width: 12),
          _NavGlassItem(
            tab: HomeTab.create,
            selected: current == HomeTab.create,
            onTap: () => onChanged(HomeTab.create),
          ),
          const SizedBox(width: 12),
          _NavGlassItem(
            tab: HomeTab.hardware,
            selected: current == HomeTab.hardware,
            onTap: () => onChanged(HomeTab.hardware),
          ),
          const SizedBox(width: 12),
          _NavGlassItem(
            tab: HomeTab.profile,
            selected: current == HomeTab.profile,
            onTap: () => onChanged(HomeTab.profile),
          ),
        ],
      ),
    );
  }
}

class _NavGlassItem extends StatelessWidget {
  const _NavGlassItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final HomeTab tab;
  final bool selected;
  final VoidCallback onTap;

  static const double _size = 56.0;
  static const double _iconSize = 24.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final iconColor = isDark
        ? Colors.white
        : (selected ? Colors.black87 : Colors.black54);
    final labelColor = isDark ? Colors.white : Colors.black87;

    // Glass fill gradient — more opaque when selected
    final glassFill = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [
              Colors.white.withValues(alpha: selected ? 0.16 : 0.09),
              Colors.white.withValues(alpha: selected ? 0.07 : 0.03),
            ]
          : [
              Colors.white.withValues(alpha: selected ? 0.80 : 0.55),
              Colors.white.withValues(alpha: selected ? 0.60 : 0.35),
            ],
    );

    // Luminous border gradient
    final borderGrad = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [
              Colors.white.withValues(alpha: selected ? 0.30 : 0.14),
              Colors.white.withValues(alpha: selected ? 0.10 : 0.05),
            ]
          : [
              Colors.white.withValues(alpha: selected ? 0.90 : 0.55),
              Colors.white.withValues(alpha: selected ? 0.30 : 0.15),
            ],
    );

    final shadow = [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
        blurRadius: 18,
        offset: const Offset(0, 5),
        spreadRadius: -4,
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.03),
        blurRadius: 5,
        offset: const Offset(0, 2),
      ),
    ];

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: selected ? tab.pillWidth : _size),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        builder: (context, animWidth, _) {
          return GlassContainer.frostedGlass(
            height: _size,
            width: animWidth,
            borderRadius: BorderRadius.circular(_size / 2),
            blur: 20,
            frostedOpacity: 0.10,
            gradient: glassFill,
            borderGradient: borderGrad,
            borderWidth: 1.2,
            boxShadow: shadow,
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  tab.assetPath,
                  width: _iconSize,
                  height: _iconSize,
                  colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                ),
                ClipRect(
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.centerLeft,
                    widthFactor: selected ? 1.0 : 0.0,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        tab.label,
                        style: TextStyle(
                          color: labelColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
