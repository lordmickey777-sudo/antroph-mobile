import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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
    final button = AppPillButton(
      onPressed: onPressed,
      icon: CupertinoIcons.collections,
      label: 'My collections',
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
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
          backgroundColor: Colors.white.withOpacity(0.2),
          foregroundColor: Colors.white,
        ),
      ],
    );
  }
}
