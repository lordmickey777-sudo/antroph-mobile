import 'package:flutter/material.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';
import 'package:flutter/services.dart';
import 'package:antroph_mobile/widgets/app_input.dart';

/// Deprecated: Use [AppInput] from `lib/widgets/app_input.dart` instead.
/// Kept temporarily for backwards compatibility; will be removed after migration.
class AuthInput extends StatelessWidget {
  const AuthInput({
    super.key,
    required this.controller,
    required this.hint,
    this.icon,
    this.obscure = false,
    this.onToggleObscure,
    this.keyboardType,
    this.validator,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return AppInput(
      controller: controller,
      hint: hint,
      icon: icon,
      obscure: obscure,
      onToggleObscure: onToggleObscure,
      keyboardType: keyboardType,
      validator: validator,
      readOnly: readOnly,
    );
  }
}

class AuthButton extends StatelessWidget {
  const AuthButton({super.key, required this.label, required this.onTap, this.loading = false});
  final String label;
  final VoidCallback onTap;
  final bool loading;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Material(
        color: const Color(0xFF1F2223),
        borderRadius: BorderRadius.circular(40),
        child: InkWell(
          onTap: loading
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  onTap();
                },
          borderRadius: BorderRadius.circular(40),
          child: Center(
            child: loading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : TypographyText(
                    label,
                    variant: TypographyVariant.body1,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
          ),
        ),
      ),
    );
  }
}
