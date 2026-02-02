import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:antroph_mobile/core/responsive/responsive.dart';
import '../../../widgets/typography_text.dart';
import '../widgets/auth_input.dart';
import 'package:antroph_mobile/widgets/app_input.dart';
import '../../../core/auth/state/auth_state.dart';
import '../../../core/auth/services/email_storage_service.dart';
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
  bool _hasLoadedEmail = false;

  @override
  void initState() {
    super.initState();
    _loadLastEmail();
  }

  /// Load the last successfully used email for prefilling the form
  Future<void> _loadLastEmail() async {
    if (!_hasLoadedEmail) {
      final lastEmail = await EmailStorageService.getLastEmail();
      if (lastEmail != null && lastEmail.isNotEmpty && mounted) {
        setState(() {
          _emailCtrl.text = lastEmail;
          _hasLoadedEmail = true;
        });
      } else {
        _hasLoadedEmail = true;
      }
    }
  }

  String? _validateEmail(String? v) {
    if (v == null || v.isEmpty) return 'Email required';
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v)) return 'Invalid email';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Password required';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      // Form errors can be hard to see with custom inputs; surface a toast.
      if (mounted) {
        showToast(context, 'Please fix the form errors');
      }
      return;
    }
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
      // Navigate when we have a non-null user and it changed from previous
      final user = next.value;
      final prevUser = previous?.value;
      if (mounted && user != null && user != prevUser) {
        // Remember last successful email for next time
        EmailStorageService.saveLastEmail(user.email);
        // showToast(context, 'Welcome back!', success: true);
        context.go('/home');
      }
    });
    final loading = authState.isLoading;
    final horizontalPadding = AppPadding.form.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: ContentWidth.form),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(horizontalPadding, 96, horizontalPadding, 24),
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
                AppInput(
                  controller: _emailCtrl,
                  hint: 'Enter Your Email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                ),
                const SizedBox(height: 20),
                AppInput(
                  controller: _passwordCtrl,
                  hint: 'Password',
                  icon: Icons.lock_outline,
                  obscure: _obscure,
                  onToggleObscure: () => setState(() => _obscure = !_obscure),
                  validator: _validatePassword,
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => context.goNamed('forgot-password'),
                    child: const TypographyText(
                      'Forgot Password ?',
                      variant: TypographyVariant.body2,
                      color: Colors.white70,
                    ),
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
                      onTap: () {
                        if (widget.onSwitchSignup != null) {
                          widget.onSwitchSignup!();
                        } else {
                          // Fallback to routing when not embedded in _AuthGated
                          context.go('/auth/signup');
                        }
                      },
                      child: const TypographyText(
                        'Sign up',
                        variant: TypographyVariant.body2,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                // if (authState.hasError)
                //   Padding(
                //     padding: const EdgeInsets.only(top: 16),
                //     child: TypographyText(
                //       'Error: ${authState.error}',
                //       variant: TypographyVariant.body2,
                //       color: Colors.redAccent,
                //     ),
                //   ),
              ],
                ),
              ),
            ),
          ),
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
