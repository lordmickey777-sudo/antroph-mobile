import 'package:flutter/material.dart';
import 'package:antroph_mobile/core/responsive/responsive.dart';
import 'package:antroph_mobile/core/theme/theme_provider.dart';

/// A reusable, app-wide text input styled like the login fields.
///
/// Features:
/// - Leading icon
/// - Obscure text with visibility toggle
/// - Validation, read-only, keyboard type
/// - onChanged callback
/// - Multiline support (bio, etc.)
class AppInput extends StatelessWidget {
  const AppInput({
    super.key,
    required this.controller,
    required this.hint,
    this.icon,
    this.obscure = false,
    this.onToggleObscure,
    this.keyboardType,
    this.validator,
    this.readOnly = false,
    this.onChanged,
    this.maxLines = 1,
    this.trailing,
  });

  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool readOnly;
  final void Function(String)? onChanged;
  final int maxLines;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isMultiline = (maxLines != 1);
    final radius = BorderRadius.circular(isMultiline ? 16 : 40);
    final textColor = context.primaryTextColor;
    final hintColor = context.tertiaryTextColor;
    final iconColor = context.secondaryTextColor;

    final input = TextFormField(
      controller: controller,
      style: TextStyle(color: textColor, fontSize: 15),
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      readOnly: readOnly,
      onChanged: onChanged,
      maxLines: maxLines,
      decoration: InputDecoration(
        isCollapsed: true,
        border: InputBorder.none,
        hintText: hint,
        hintStyle: TextStyle(color: hintColor, fontSize: 15),
        contentPadding: const EdgeInsets.symmetric(vertical: 4),
      ),
    );

    final minHeight = AppSizing.inputHeight.of(context);
    return Container(
      constraints: isMultiline ? null : BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(color: context.inputBackground, borderRadius: radius),
      child: Row(
        crossAxisAlignment: isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Padding(
              padding: EdgeInsets.only(top: isMultiline ? 14 : 0),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: isMultiline ? 14 : 0),
              child: input,
            ),
          ),
          if (onToggleObscure != null)
            GestureDetector(
              onTap: onToggleObscure,
              child: Padding(
                padding: EdgeInsets.only(top: isMultiline ? 12 : 0),
                child: Icon(
                  obscure ? Icons.visibility_off : Icons.visibility,
                  color: iconColor,
                  size: 22,
                ),
              ),
            ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Padding(
              padding: EdgeInsets.only(top: isMultiline ? 12 : 0),
              child: trailing!,
            ),
          ],
        ],
      ),
    );
  }
}
