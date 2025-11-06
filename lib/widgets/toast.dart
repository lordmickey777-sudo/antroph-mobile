import 'package:flutter/material.dart';

void showToast(BuildContext context, String message, {bool success = false}) {
  final theme = Theme.of(context);
  final bg = success ? const Color(0xFF1E3A2F) : const Color(0xFF3A1E1E);
  final fg = Colors.white;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: bg,
        content: Text(message, style: theme.textTheme.bodyMedium?.copyWith(color: fg)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
}
