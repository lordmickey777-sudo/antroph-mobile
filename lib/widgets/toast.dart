import 'dart:async';

import 'package:flutter/material.dart';

enum ToastVariant { success, error, info }

OverlayEntry? _toastEntry;
Timer? _toastTimer;

const _toastLogoAsset = 'assets/images/app_logo.png';

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

  final overlay =
      Navigator.maybeOf(context, rootNavigator: true)?.overlay ??
      Overlay.maybeOf(context, rootOverlay: true);

  if (overlay == null) {
    final theme = Theme.of(context);
    final fg = Colors.white;
    final bg = _toastBackground(resolvedVariant);
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: bg,
          content: _ToastContent(
            message: message,
            foreground: fg,
            textStyle: theme.textTheme.bodyMedium,
          ),
          duration: duration,
        ),
      );
    return;
  }

  final entry = OverlayEntry(
    builder: (context) =>
        _ToastOverlay(message: message, variant: resolvedVariant),
  );
  _toastEntry = entry;
  overlay.insert(entry);

  _toastTimer = Timer(duration, () {
    if (_toastEntry != entry) return;
    entry.remove();
    _toastEntry = null;
    _toastTimer = null;
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: _ToastContent(
                    message: message,
                    foreground: fg,
                    textStyle: theme.textTheme.bodyMedium,
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

class _ToastContent extends StatelessWidget {
  const _ToastContent({
    required this.message,
    required this.foreground,
    required this.textStyle,
  });

  final String message;
  final Color foreground;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            _toastLogoAsset,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Icon(Icons.notifications_rounded, color: foreground, size: 16),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            message,
            style: textStyle?.copyWith(color: foreground),
            textAlign: TextAlign.left,
          ),
        ),
      ],
    );
  }
}
