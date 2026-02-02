import 'dart:async';

import 'package:flutter/material.dart';

enum ToastVariant { success, error, info }

OverlayEntry? _toastEntry;
Timer? _toastTimer;

void showToast(
  BuildContext context,
  String message, {
  bool? success,
  ToastVariant? variant,
  Duration duration = const Duration(seconds: 3),
}) {
  final resolvedVariant = success != null
      ? (success ? ToastVariant.success : ToastVariant.error)
      : (variant ?? ToastVariant.error);

  _toastTimer?.cancel();
  _toastTimer = null;
  _toastEntry?.remove();
  _toastEntry = null;

  final overlay = Navigator.maybeOf(context, rootNavigator: true)?.overlay ??
      Overlay.of(context, rootOverlay: true);

  if (overlay == null) {
    final theme = Theme.of(context);
    final fg = Colors.white;
    final bg = _toastBackground(resolvedVariant);
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: bg,
            content: Text(message, style: theme.textTheme.bodyMedium?.copyWith(color: fg)),
            duration: duration,
          ),
        );
    return;
  }

  _toastEntry = OverlayEntry(
    builder: (context) => _ToastOverlay(
      message: message,
      variant: resolvedVariant,
    ),
  );
  overlay.insert(_toastEntry!);

  _toastTimer = Timer(duration, () {
    _toastEntry?.remove();
    _toastEntry = null;
  });
}

Color _toastBackground(ToastVariant variant) {
  switch (variant) {
    case ToastVariant.success:
      return const Color(0xFF1E3A2F);
    case ToastVariant.info:
      return const Color(0xFF1F2224);
    case ToastVariant.error:
      return const Color(0xFF3A1E1E);
  }
}

Color _toastForeground(ToastVariant variant) {
  switch (variant) {
    case ToastVariant.success:
    case ToastVariant.info:
    case ToastVariant.error:
      return Colors.white;
  }
}

class _ToastOverlay extends StatelessWidget {
  const _ToastOverlay({required this.message, required this.variant});

  final String message;
  final ToastVariant variant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = _toastForeground(variant);
    final bg = _toastBackground(variant);

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, (1 - value) * -8),
                  child: child,
                ),
              );
            },
            child: Material(
              color: bg,
              elevation: 6,
              borderRadius: BorderRadius.circular(14),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(color: fg),
                    textAlign: TextAlign.center,
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
