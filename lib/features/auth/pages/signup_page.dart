import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:antroph_mobile/core/onboarding/app_setup_route_service.dart';
import 'package:antroph_mobile/core/responsive/responsive.dart';
import 'package:antroph_mobile/widgets/shimmer.dart';
import '../../../widgets/typography_text.dart';
import '../widgets/auth_input.dart';
import '../../../core/auth/state/auth_state.dart';
import '../../../core/auth/repository/auth_repository.dart';
import '../../../widgets/toast.dart';
import '../widgets/social_sign_in_buttons.dart';

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

  void _onPasswordChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  bool get _hasMinLength => _passwordCtrl.text.length >= 8;
  bool get _hasUppercase => RegExp(r'[A-Z]').hasMatch(_passwordCtrl.text);
  bool get _hasLowercase => RegExp(r'[a-z]').hasMatch(_passwordCtrl.text);
  bool get _hasDigit => RegExp(r'\d').hasMatch(_passwordCtrl.text);

  @override
  void initState() {
    super.initState();
    _passwordCtrl.addListener(_onPasswordChanged);
  }

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

  void _openWebPage(BuildContext context, String title, String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _WebViewPage(title: title, url: url),
      ),
    );
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

  Future<void> _handleAuthenticatedUser() async {
    final nextRoute = await AppSetupRouteService.resolveAuthenticatedRoute();
    if (!mounted) return;
    context.go(nextRoute);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    ref.listen(authControllerProvider, (previous, next) {
      final nextError = next.error?.toString();
      final previousError = previous?.error?.toString();
      if (next.hasError &&
          mounted &&
          nextError != null &&
          nextError != previousError) {
        showToast(context, nextError);
      }
      final user = next.value;
      final prevUser = previous?.value;
      if (mounted && user != null && user != prevUser) {
        showToast(context, 'Account created.', success: true);
        _handleAuthenticatedUser();
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
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                36,
                horizontalPadding,
                24,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TypographyText(
                      'Create Account',
                      variant: TypographyVariant.h2,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    const SizedBox(height: 36),
                    AuthInput(
                      controller: _nameCtrl,
                      hint: 'Full Name',
                      icon: Icons.person_outline,
                    ),
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
                      onToggleObscure: () =>
                          setState(() => _obscure = !_obscure),
                      validator: _validatePassword,
                    ),
                    const SizedBox(height: 12),
                    _PasswordPolicyChecklist(
                      hasMinLength: _hasMinLength,
                      hasUppercase: _hasUppercase,
                      hasLowercase: _hasLowercase,
                      hasDigit: _hasDigit,
                    ),
                    const SizedBox(height: 28),
                    AuthButton(
                      label: 'Register',
                      onTap: _submit,
                      loading: loading,
                    ),
                    const SizedBox(height: 20),
                    const OrDivider(),
                    const SizedBox(height: 20),
                    const SocialSignInButtons(),
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
                          onTap: () {
                            if (widget.onSwitchLogin != null) {
                              widget.onSwitchLogin!();
                            } else {
                              // Fallback to routing when not embedded in _AuthGated
                              context.go('/auth/login');
                            }
                          },
                          child: const TypographyText(
                            'Sign In',
                            variant: TypographyVariant.body2,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () => _openWebPage(
                            context,
                            'Privacy Policy',
                            'https://www.antroph.com/privacy/',
                          ),
                          child: const TypographyText(
                            'Privacy Policy',
                            variant: TypographyVariant.body2,
                            color: Colors.white54,
                          ),
                        ),
                        const TypographyText(
                          '  •  ',
                          variant: TypographyVariant.body2,
                          color: Colors.white38,
                        ),
                        GestureDetector(
                          onTap: () => _openWebPage(
                            context,
                            'Terms of Service',
                            'https://www.antroph.com/terms/',
                          ),
                          child: const TypographyText(
                            'Terms of Service',
                            variant: TypographyVariant.body2,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
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
    _passwordCtrl.removeListener(_onPasswordChanged);
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }
}

class _PasswordPolicyChecklist extends StatelessWidget {
  const _PasswordPolicyChecklist({
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
    final policies = <MapEntry<String, bool>>[
      MapEntry('8+ chars', hasMinLength),
      MapEntry('Uppercase', hasUppercase),
      MapEntry('Lowercase', hasLowercase),
      MapEntry('Number', hasDigit),
    ];

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final policy in policies)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),

            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  policy.value ? Icons.check : Icons.circle_outlined,
                  size: 11,
                  color: policy.value ? Colors.greenAccent : Colors.white38,
                ),
                const SizedBox(width: 4),
                TypographyText(
                  policy.key,
                  variant: TypographyVariant.body2,
                  fontSize: 11,
                  color: policy.value ? Colors.white : Colors.white70,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _WebViewPage extends StatefulWidget {
  const _WebViewPage({required this.title, required this.url});

  final String title;
  final String url;

  @override
  State<_WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<_WebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF101214))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => setState(() => _isLoading = false),
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101214),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101214),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.title),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Positioned.fill(
              child: ShimmerWebViewPlaceholder(
                backgroundColor: Color(0xFF101214),
              ),
            ),
        ],
      ),
    );
  }
}
