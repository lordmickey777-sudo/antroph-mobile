import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:antroph_mobile/widgets/app_button.dart';
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
    final button = AppButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        elevation: 0,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(CupertinoIcons.collections, size: 18),
          SizedBox(width: 6),
          TypographyText('My collections', variant: TypographyVariant.body2, color: Colors.black),
        ],
      ),
    );

    if (onNavigate == null) {
      return button;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button,
        const SizedBox(width: 6),
        InkWell(
          onTap: onNavigate,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(CupertinoIcons.arrow_right, size: 18, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
