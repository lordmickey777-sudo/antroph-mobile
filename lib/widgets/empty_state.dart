import 'package:flutter/material.dart';

import 'package:antroph_mobile/widgets/typography_text.dart';
import 'package:antroph_mobile/widgets/app_button.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.description,
    this.assetPath = 'assets/images/antroph_smile.png',
    this.actionLabel,
    this.onAction,
    this.margin = const EdgeInsets.symmetric(horizontal: 32),
  });

  final String title;
  final String? description;
  final String assetPath;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: margin,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 100),
          Image.asset(assetPath, height: 80, fit: BoxFit.contain),
          const SizedBox(height: 20),
          TypographyText(
            title,
            variant: TypographyVariant.h3,
            color: isDark ? Colors.white : Colors.black87,
            textAlign: TextAlign.center,
          ),
          if (description != null) ...[
            const SizedBox(height: 12),
            TypographyText(
              description!,
              variant: TypographyVariant.body2,
              color: isDark ? Colors.white70 : Colors.black54,
              textAlign: TextAlign.center,
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            AppButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
