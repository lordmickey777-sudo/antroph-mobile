import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../widgets/typography_text.dart';
import '../widgets/auth_input.dart';
import '../../../core/auth/state/auth_state.dart';
import '../../../widgets/toast.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key, this.onSwitchSignup});
  final VoidCallback? onSwitchSignup;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  final _formKey = GlobalKey<FormState>();

  String? _validateEmail(String? v) {
    if (v == null || v.isEmpty) return 'Email required';
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v)) return 'Invalid email';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final controller = ref.read(authControllerProvider.notifier);
    await controller.login(email: _emailCtrl.text.trim(), password: _passwordCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    ref.listen(authControllerProvider, (previous, next) {
      if (next.hasError && mounted) {
        final msg = next.error?.toString() ?? 'Unexpected error';
        showToast(context, msg);
      }
      if (next.hasValue && previous?.hasValue == false && mounted) {
        // Optionally show success toast
        // showToast(context, 'Welcome back!', success: true);
      }
    });
    final loading = authState.isLoading;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 96, 24, 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TypographyText(
              'Login Your',
              variant: TypographyVariant.h2,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
            const SizedBox(height: 4),
            const TypographyText(
              'Account',
              variant: TypographyVariant.h2,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
            const SizedBox(height: 36),
            AuthInput(
              controller: _emailCtrl,
              hint: 'Enter Your Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: _validateEmail,
            ),
            const SizedBox(height: 20),
            AuthInput(
              controller: _passwordCtrl,
              hint: 'Password',
              icon: Icons.lock_outline,
              obscure: _obscure,
              onToggleObscure: () => setState(() => _obscure = !_obscure),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TypographyText(
                'Forget Password ?',
                variant: TypographyVariant.body2,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 24),
            AuthButton(label: 'Login', onTap: _submit, loading: loading),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const TypographyText(
                  'Create New Account? ',
                  variant: TypographyVariant.body2,
                  color: Colors.white70,
                ),
                GestureDetector(
                  onTap: widget.onSwitchSignup,
                  child: const TypographyText(
                    'Sign up',
                    variant: TypographyVariant.body2,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (authState.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: TypographyText(
                  'Error: ${authState.error}',
                  variant: TypographyVariant.body2,
                  color: Colors.redAccent,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }
}
