import 'package:flutter/cupertino.dart' hide CupertinoSheetRoute;
import 'package:flutter/material.dart';

import 'package:antroph_mobile/widgets/cupertino_sheet_route.dart';

/// Shows a Cupertino-style bottom sheet with iOS-like transitions using [CupertinoSheetRoute].
///
/// [context] - Build context
/// [builder] - Builder function that receives a scroll controller for nested scrolling
/// [heightFactor] - Height as a fraction of screen height (0.0 to 1.0), defaults to 0.7
/// [isDismissible] - Whether tapping the barrier dismisses the sheet
/// [backgroundColor] - Background color of the sheet (defaults to theme surface color)
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext context, ScrollController scrollController) builder,
  double heightFactor = 0.7,
  bool isDismissible = true,
  Color? backgroundColor,
}) {
  return Navigator.of(context).push<T>(
    CupertinoSheetRoute<T>(
      dismissible: isDismissible,
      builder: (context) => _SheetScaffold(
        heightFactor: heightFactor,
        backgroundColor: backgroundColor,
        builder: builder,
      ),
    ),
  );
}

/// Internal scaffold that positions the sheet at the bottom of the screen.
class _SheetScaffold extends StatefulWidget {
  const _SheetScaffold({
    required this.builder,
    required this.heightFactor,
    this.backgroundColor,
  });

  final Widget Function(BuildContext context, ScrollController scrollController) builder;
  final double heightFactor;
  final Color? backgroundColor;

  @override
  State<_SheetScaffold> createState() => _SheetScaffoldState();
}

class _SheetScaffoldState extends State<_SheetScaffold> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final bgColor = widget.backgroundColor ?? Theme.of(context).cardColor;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: size.height * widget.heightFactor,
        width: double.infinity,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _DragHandle(),
              Expanded(
                child: widget.builder(context, _scrollController),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Drag handle indicator shown at the top of the sheet
class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Center(
        child: Container(
          width: 44,
          height: 5,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.22) : Colors.black.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(50),
          ),
        ),
      ),
    );
  }
}

/// A simpler variant for action sheets with a list of options.
///
/// Use this for quick action menus like "Remove", "Edit", etc.
Future<T?> showAppActionSheet<T>({
  required BuildContext context,
  required List<AppActionSheetItem> actions,
  String? title,
  bool showCloseButton = true,
}) {
  return showAppBottomSheet<T>(
    context: context,
    heightFactor: 0.35,
    builder: (context, scrollController) => _ActionSheetContent(
      actions: actions,
      title: title,
      showCloseButton: showCloseButton,
      scrollController: scrollController,
    ),
  );
}

/// An action item for the action sheet
class AppActionSheetItem {
  const AppActionSheetItem({
    required this.label,
    required this.onTap,
    this.icon,
    this.isDestructive = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool isDestructive;
}

class _ActionSheetContent extends StatelessWidget {
  const _ActionSheetContent({
    required this.actions,
    required this.scrollController,
    this.title,
    this.showCloseButton = true,
  });

  final List<AppActionSheetItem> actions;
  final String? title;
  final bool showCloseButton;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final iconBgColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);
    final iconColor = isDark ? Colors.white : Colors.black87;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showCloseButton)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (title != null)
                  Text(
                    title!,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else
                  const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      CupertinoIcons.xmark,
                      color: iconColor,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              controller: scrollController,
              itemCount: actions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final action = actions[index];
                return _ActionTile(action: action);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action});

  final AppActionSheetItem action;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = isDark ? Colors.white : Colors.black87;
    final color = action.isDestructive ? Colors.red : defaultColor;
    final tileBgColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).maybePop();
        action.onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: tileBgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            if (action.icon != null) ...[
              Icon(action.icon, color: color, size: 22),
              const SizedBox(width: 12),
            ],
            Text(
              action.label,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
