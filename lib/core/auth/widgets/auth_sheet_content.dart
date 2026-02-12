import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:antroph_mobile/core/auth/state/auth_state.dart';
import 'package:antroph_mobile/core/auth/repository/auth_repository.dart';
import 'package:antroph_mobile/core/auth/services/email_storage_service.dart';
import 'package:antroph_mobile/core/auth/utils/auth_guard.dart';
import 'package:antroph_mobile/widgets/app_input.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';
import 'package:antroph_mobile/widgets/toast.dart';
import 'package:antroph_mobile/features/auth/widgets/auth_input.dart';
import 'package:antroph_mobile/features/auth/widgets/social_sign_in_buttons.dart';

/// Content widget for the auth guard sheet.
/// Shows login or signup forms.
class AuthSheetContent extends ConsumerStatefulWidget {
  const AuthSheetContent({super.key, this.actionDescription, required this.scrollController});

  final String? actionDescription;
  final ScrollController scrollController;

  @override
  ConsumerState<AuthSheetContent> createState() => _AuthSheetContentState();
}

class _AuthSheetContentState extends ConsumerState<AuthSheetContent> {
  bool _showLogin = true;

  // Login form controllers
  final _loginEmailCtrl = TextEditingController();
  final _loginPasswordCtrl = TextEditingController();
  bool _loginObscure = true;
  final _loginFormKey = GlobalKey<FormState>();

  // Signup form controllers
  final _signupNameCtrl = TextEditingController();
  final _signupEmailCtrl = TextEditingController();
  final _signupPasswordCtrl = TextEditingController();
  bool _signupObscure = true;
  final _signupFormKey = GlobalKey<FormState>();
  bool _emailExists = false;

  @override
  void initState() {
    super.initState();
    _loadLastEmail();
    _signupPasswordCtrl.addListener(_onPasswordChanged);
  }

  Future<void> _loadLastEmail() async {
    final lastEmail = await EmailStorageService.getLastEmail();
    if (lastEmail != null && lastEmail.isNotEmpty && mounted) {
      setState(() {
        _loginEmailCtrl.text = lastEmail;
      });
    }
  }

  void _onPasswordChanged() {
    if (mounted) setState(() {});
  }

  // Password validation helpers
  bool get _hasMinLength => _signupPasswordCtrl.text.length >= 8;
  bool get _hasUppercase => RegExp(r'[A-Z]').hasMatch(_signupPasswordCtrl.text);
  bool get _hasLowercase => RegExp(r'[a-z]').hasMatch(_signupPasswordCtrl.text);
  bool get _hasDigit => RegExp(r'\d').hasMatch(_signupPasswordCtrl.text);

  String? _validateEmail(String? v) {
    if (v == null || v.isEmpty) return 'Email required';
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v)) return 'Invalid email';
    return null;
  }

  String? _validateSignupEmail(String? v) {
    if (v == null || v.isEmpty) return 'Email required';
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v)) return 'Invalid email';
    if (_emailExists) return 'Email already registered';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Password required';
    return null;
  }

  String? _validateSignupPassword(String? v) {
    if (v == null || v.isEmpty) return 'Password required';
    if (v.length < 8) return 'Min 8 chars';
    if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Add uppercase';
    if (!RegExp(r'[a-z]').hasMatch(v)) return 'Add lowercase';
    if (!RegExp(r'\d').hasMatch(v)) return 'Add digit';
    return null;
  }

  Future<void> _submitLogin() async {
    if (!_loginFormKey.currentState!.validate()) {
      if (mounted) showToast(context, 'Please fix the form errors');
      return;
    }
    final controller = ref.read(authControllerProvider.notifier);
    await controller.login(email: _loginEmailCtrl.text.trim(), password: _loginPasswordCtrl.text);
  }

  Future<void> _submitSignup() async {
    if (!_signupFormKey.currentState!.validate()) return;

    // Check if email exists
    final repo = AuthRepository();
    try {
      final exists = await repo.checkEmail(_signupEmailCtrl.text.trim());
      if (exists) {
        setState(() => _emailExists = true);
        _signupFormKey.currentState!.validate();
        return;
      }
    } catch (_) {
      // Ignore email check failure; proceed to register
    }
    setState(() => _emailExists = false);

    final controller = ref.read(authControllerProvider.notifier);
    await controller.register(
      email: _signupEmailCtrl.text.trim(),
      password: _signupPasswordCtrl.text,
      displayName: _signupNameCtrl.text.trim().isEmpty ? null : _signupNameCtrl.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    // Listen for auth state changes
    ref.listen(authControllerProvider, (previous, next) {
      if (next.hasError && mounted) {
        final msg = next.error?.toString() ?? 'Unexpected error';
        showToast(context, msg);
      }

      final user = next.value;
      final prevUser = previous?.value;
      if (mounted && user != null && user != prevUser) {
        // Save email and pop with success
        EmailStorageService.saveLastEmail(user.email);
        Navigator.of(context).pop(AuthGuardResult.loginSuccessful);
      }
    });

    final loading = authState.isLoading;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.white54 : Colors.black54;
    final iconBgColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.08);

    return Material(
      color: Colors.transparent,
      child: SingleChildScrollView(
        controller: widget.scrollController,
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with close button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TypographyText(
                        _showLogin ? 'Login to continue' : 'Create account',
                        variant: TypographyVariant.h3,
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                      if (widget.actionDescription != null) ...[
                        const SizedBox(height: 4),
                        TypographyText(
                          widget.actionDescription!,
                          variant: TypographyVariant.body2,
                          color: secondaryTextColor,
                        ),
                      ],
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(AuthGuardResult.dismissed),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: iconBgColor, shape: BoxShape.circle),
                    child: Icon(CupertinoIcons.xmark, color: textColor, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Form content
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _showLogin
                  ? _LoginForm(
                      key: const ValueKey('login'),
                      formKey: _loginFormKey,
                      emailCtrl: _loginEmailCtrl,
                      passwordCtrl: _loginPasswordCtrl,
                      obscure: _loginObscure,
                      onToggleObscure: () => setState(() => _loginObscure = !_loginObscure),
                      onSubmit: _submitLogin,
                      loading: loading,
                      validateEmail: _validateEmail,
                      validatePassword: _validatePassword,
                    )
                  : _SignupForm(
                      key: const ValueKey('signup'),
                      formKey: _signupFormKey,
                      nameCtrl: _signupNameCtrl,
                      emailCtrl: _signupEmailCtrl,
                      passwordCtrl: _signupPasswordCtrl,
                      obscure: _signupObscure,
                      onToggleObscure: () => setState(() => _signupObscure = !_signupObscure),
                      onSubmit: _submitSignup,
                      loading: loading,
                      validateEmail: _validateSignupEmail,
                      validatePassword: _validateSignupPassword,
                      hasMinLength: _hasMinLength,
                      hasUppercase: _hasUppercase,
                      hasLowercase: _hasLowercase,
                      hasDigit: _hasDigit,
                    ),
            ),
            const SizedBox(height: 20),

            // Toggle login/signup
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TypographyText(
                  _showLogin ? 'Create New Account? ' : 'Already Have An Account? ',
                  variant: TypographyVariant.body2,
                  color: secondaryTextColor,
                ),
                GestureDetector(
                  onTap: () => setState(() => _showLogin = !_showLogin),
                  child: TypographyText(
                    _showLogin ? 'Sign up' : 'Sign In',
                    variant: TypographyVariant.body2,
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _signupPasswordCtrl.removeListener(_onPasswordChanged);
    _loginEmailCtrl.dispose();
    _loginPasswordCtrl.dispose();
    _signupNameCtrl.dispose();
    _signupEmailCtrl.dispose();
    _signupPasswordCtrl.dispose();
    super.dispose();
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    super.key,
    required this.formKey,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.obscure,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.loading,
    required this.validateEmail,
    required this.validatePassword,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;
  final bool loading;
  final String? Function(String?) validateEmail;
  final String? Function(String?) validatePassword;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          AppInput(
            controller: emailCtrl,
            hint: 'Enter Your Email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: validateEmail,
          ),
          const SizedBox(height: 16),
          AppInput(
            controller: passwordCtrl,
            hint: 'Password',
            icon: Icons.lock_outline,
            obscure: obscure,
            onToggleObscure: onToggleObscure,
            validator: validatePassword,
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
                GoRouter.of(context).goNamed('forgot-password');
              },
              child: TypographyText(
                'Forgot Password? Reset here',
                variant: TypographyVariant.body2,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.black54,
              ),
            ),
          ),
          const SizedBox(height: 24),
          AuthButton(label: 'Login', onTap: onSubmit, loading: loading),
          const SizedBox(height: 16),
          const OrDivider(),
          const SizedBox(height: 16),
          const SocialSignInButtons(),
        ],
      ),
    );
  }
}

class _SignupForm extends StatelessWidget {
  const _SignupForm({
    super.key,
    required this.formKey,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.obscure,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.loading,
    required this.validateEmail,
    required this.validatePassword,
    required this.hasMinLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasDigit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;
  final bool loading;
  final String? Function(String?) validateEmail;
  final String? Function(String?) validatePassword;
  final bool hasMinLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasDigit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          AppInput(controller: nameCtrl, hint: 'Full Name', icon: Icons.person_outline),
          const SizedBox(height: 16),
          AppInput(
            controller: emailCtrl,
            hint: 'Enter Your Email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: validateEmail,
          ),
          const SizedBox(height: 16),
          AppInput(
            controller: passwordCtrl,
            hint: 'Password',
            icon: Icons.lock_outline,
            obscure: obscure,
            onToggleObscure: onToggleObscure,
            validator: validatePassword,
          ),
          const SizedBox(height: 12),
          _PasswordChecklist(
            hasMinLength: hasMinLength,
            hasUppercase: hasUppercase,
            hasLowercase: hasLowercase,
            hasDigit: hasDigit,
          ),
          const SizedBox(height: 24),
          AuthButton(label: 'Register', onTap: onSubmit, loading: loading),
          const SizedBox(height: 16),
          const OrDivider(),
          const SizedBox(height: 16),
          const SocialSignInButtons(),
        ],
      ),
    );
  }
}

class _PasswordChecklist extends StatelessWidget {
  const _PasswordChecklist({
    required this.hasMinLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasDigit,
  });

  final bool hasMinLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasDigit;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.white70 : Colors.black54;
    final uncheckedColor = isDark ? Colors.white38 : Colors.black26;

    final policies = <MapEntry<String, bool>>[
      MapEntry('At least 8 characters', hasMinLength),
      MapEntry('Contains an uppercase letter', hasUppercase),
      MapEntry('Contains a lowercase letter', hasLowercase),
      MapEntry('Contains a number', hasDigit),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final policy in policies)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Icon(
                  policy.value ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 16,
                  color: policy.value ? Colors.greenAccent : uncheckedColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TypographyText(
                    policy.key,
                    variant: TypographyVariant.body2,
                    color: policy.value ? textColor : secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
