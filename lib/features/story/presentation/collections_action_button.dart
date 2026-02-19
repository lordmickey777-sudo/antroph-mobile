import 'package:flutter/cupertino.dart';
import 'package:antroph_mobile/core/theme/theme_provider.dart';

import 'package:antroph_mobile/widgets/app_action_button.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';

class CollectionsActionButton extends StatelessWidget {
  const CollectionsActionButton({
    super.key,
    required this.onPressed,
    this.onNavigate,
  });

  final VoidCallback onPressed;
  final VoidCallback? onNavigate;

  @override
  Widget build(BuildContext context) {
    final actionBg = context.actionButtonBackground;
    final actionFg = context.actionButtonForeground;

    final button = AppPillButton(
      onPressed: onPressed,
      icon: CupertinoIcons.collections,
      label: 'My collections',
      backgroundColor: actionBg,
      foregroundColor: actionFg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      variant: TypographyVariant.body2,
    );

    if (onNavigate == null) {
      return button;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button,
        const SizedBox(width: 6),
        AppCircleIconButton(
          onPressed: onNavigate,
          icon: CupertinoIcons.arrow_right,
          size: 34,
          iconSize: 18,
          backgroundColor: actionBg.withValues(alpha: 0.2),
          foregroundColor: actionBg,
        ),
      ],
    );
  }
}
