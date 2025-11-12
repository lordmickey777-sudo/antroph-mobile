import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../widgets/typography_text.dart';
import '../widgets/auth_input.dart';
import '../../../core/auth/state/auth_state.dart';
import '../../../widgets/toast.dart';
import '../../../core/auth/validation/auth_validators.dart';

/// Two-step forgot password flow:
/// Step 1: Enter email -> request reset code.
/// Step 2: Enter 6-digit code + new password -> reset.
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _requested = false; // Whether code has been requested.
  final _formKey = GlobalKey<FormState>();

  String? _validateEmail(String? v) => AuthValidators.email(v);
  String? _validateCode(String? v) => !_requested ? null : AuthValidators.resetToken(v);
  String? _validatePassword(String? v) {
    if (!_requested) return null; // Only validate after request step.
    return AuthValidators.newPassword(v);
  }

  String? _validateConfirm(String? v) {
    if (!_requested) return null;
    if (v == null || v.isEmpty) return 'Confirm password';
    if (v != _passwordCtrl.text) return 'Passwords do not match';
    return null;
  }

  Future<void> _requestCode() async {
    if (!_formKey.currentState!.validate()) {
      showToast(context, 'Fix form errors');
      return;
    }
    final ctrl = ref.read(authControllerProvider.notifier);
    try {
      final msg = await ctrl.sendResetCode(email: _emailCtrl.text.trim());
      setState(() => _requested = true);
      showToast(context, msg.isNotEmpty ? msg : 'Reset code sent if account exists', success: true);
    } catch (e) {
      showToast(context, e.toString());
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) {
      showToast(context, 'Fix form errors');
      return;
    }
    final ctrl = ref.read(authControllerProvider.notifier);
    try {
      final msg = await ctrl.resetPassword(
        email: _emailCtrl.text.trim(),
        token: _codeCtrl.text.trim(),
        newPassword: _passwordCtrl.text,
      );
      showToast(context, msg.isNotEmpty ? msg : 'Password reset', success: true);
      if (mounted) context.goNamed('login');
    } catch (e) {
      showToast(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref
        .watch(authControllerProvider)
        .isLoading; // Not ideal but reuse spinner style.
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 96, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TypographyText(
                  'Forgot Password',
                  variant: TypographyVariant.h2,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                const SizedBox(height: 8),
                TypographyText(
                  _requested
                      ? 'Enter the 6-digit code and your new password.'
                      : 'Enter your account email to receive a reset code.',
                  variant: TypographyVariant.body2,
                  color: Colors.white70,
                ),
                const SizedBox(height: 36),
                AuthInput(
                  controller: _emailCtrl,
                  hint: 'Email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                  readOnly: _requested, // Lock email after code request.
                ),
                if (_requested) ...[
                  const SizedBox(height: 20),
                  AuthInput(
                    controller: _codeCtrl,
                    hint: '6-digit code',
                    icon: Icons.verified_outlined,
                    keyboardType: TextInputType.number,
                    validator: _validateCode,
                  ),
                  const SizedBox(height: 20),
                  AuthInput(
                    controller: _passwordCtrl,
                    hint: 'New password',
                    icon: Icons.lock_outline,
                    obscure: _obscure,
                    onToggleObscure: () => setState(() => _obscure = !_obscure),
                    validator: _validatePassword,
                  ),
                  const SizedBox(height: 20),
                  AuthInput(
                    controller: _confirmCtrl,
                    hint: 'Confirm password',
                    icon: Icons.lock_outline,
                    obscure: _obscure,
                    onToggleObscure: () => setState(() => _obscure = !_obscure),
                    validator: _validateConfirm,
                  ),
                ],
                const SizedBox(height: 28),
                AuthButton(
                  label: _requested ? 'Reset Password' : 'Send Code',
                  onTap: _requested ? _resetPassword : _requestCode,
                  loading: loading,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const TypographyText(
                      'Remember your password? ',
                      variant: TypographyVariant.body2,
                      color: Colors.white70,
                    ),
                    GestureDetector(
                      onTap: () => context.goNamed('login'),
                      child: const TypographyText(
                        'Sign In',
                        variant: TypographyVariant.body2,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }
}
