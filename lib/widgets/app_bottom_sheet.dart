import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Shows a full-height Cupertino-style sheet using [CupertinoSheetRoute].
///
/// [context] - Build context
/// [builder] - Builder function that receives a scroll controller for nested scrolling
/// [enableDrag] - Whether the sheet can be dismissed by dragging
/// [backgroundColor] - Background color of the sheet (defaults to theme surface color)
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext context, ScrollController scrollController) builder,
  bool enableDrag = true,
  Color? backgroundColor,
}) {
  final theme = Theme.of(context);
  final cupertinoTheme = CupertinoTheme.of(context);
  final baseTextStyle =
      (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(decoration: TextDecoration.none);

  return showCupertinoSheet<T>(
    context: context,
    enableDrag: enableDrag,
    pageBuilder: (context) => Theme(
      data: theme,
      child: CupertinoTheme(
        data: cupertinoTheme.copyWith(brightness: theme.brightness),
        child: DefaultTextStyle(
          style: baseTextStyle,
          child: IconTheme(
            data: theme.iconTheme,
            child: _SheetScaffold(
              backgroundColor: backgroundColor,
              builder: builder,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Internal scaffold that styles the sheet surface and fills the available height.
class _SheetScaffold extends StatefulWidget {
  const _SheetScaffold({
    required this.builder,
    this.backgroundColor,
  });

  final Widget Function(BuildContext context, ScrollController scrollController) builder;
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
    final bgColor = widget.backgroundColor ?? Theme.of(context).cardColor;
    final safePadding = MediaQueryData.fromView(View.of(context)).padding;

    return SizedBox.expand(
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: bgColor,
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: safePadding.left,
              right: safePadding.right,
              bottom: safePadding.bottom,
            ),
            child: Column(
              children: [
                const _DragHandle(),
                Expanded(
                  child: widget.builder(context, _scrollController),
                ),
              ],
            ),
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
