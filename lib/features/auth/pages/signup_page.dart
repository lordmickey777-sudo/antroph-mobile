import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../widgets/typography_text.dart';
import '../widgets/auth_input.dart';
import '../../../core/auth/state/auth_state.dart';
import '../../../core/auth/repository/auth_repository.dart';
import '../../../widgets/toast.dart';

class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key, this.onSwitchLogin});
  final VoidCallback? onSwitchLogin;
  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  final _formKey = GlobalKey<FormState>();
  bool _emailExists = false;

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Password required';
    if (v.length < 8) return 'Min 8 chars';
    if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Add uppercase';
    if (!RegExp(r'[a-z]').hasMatch(v)) return 'Add lowercase';
    if (!RegExp(r'\d').hasMatch(v)) return 'Add digit';
    return null;
  }

  String? _validateEmail(String? v) {
    if (v == null || v.isEmpty) return 'Email required';
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v)) return 'Invalid email';
    if (_emailExists) return 'Email already registered';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    // optional: check email first
    final repo = AuthRepository();
    try {
      final exists = await repo.checkEmail(_emailCtrl.text.trim());
      if (exists) {
        setState(() => _emailExists = true);
        _formKey.currentState!.validate();
        return;
      }
    } catch (_) {
      // ignore email check failure; proceed to register
    }
    setState(() => _emailExists = false);
    final controller = ref.read(authControllerProvider.notifier);
    await controller.register(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      displayName: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
    );
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
        // showToast(context, 'Account created. Verify your email.', success: true);
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
              'Create your',
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
            AuthInput(controller: _nameCtrl, hint: 'Full Name', icon: Icons.person_outline),
            const SizedBox(height: 20),
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
              validator: _validatePassword,
            ),
            const SizedBox(height: 28),
            AuthButton(label: 'Register', onTap: _submit, loading: loading),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const TypographyText(
                  'Already Have An Account? ',
                  variant: TypographyVariant.body2,
                  color: Colors.white70,
                ),
                GestureDetector(
                  onTap: widget.onSwitchLogin,
                  child: const TypographyText(
                    'Sign In',
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
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }
}
