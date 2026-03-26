import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:antroph_mobile/core/consent/ai_consent_service.dart';
import 'package:antroph_mobile/core/responsive/responsive.dart';
import 'package:antroph_mobile/core/theme/theme_provider.dart';
import 'package:antroph_mobile/widgets/app_button.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';

class AiConsentPage extends StatelessWidget {
  const AiConsentPage({super.key});

  void _openPrivacyPolicy(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const _ConsentWebViewPage(
          title: 'Privacy Policy',
          url: 'https://www.antroph.com/privacy/',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = AppPadding.form.of(context);
    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: ContentWidth.form),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 48),
                    const Center(
                      child: Icon(
                        Icons.shield_rounded,
                        size: 56,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const TypographyText(
                      'Your Data & AI',
                      variant: TypographyVariant.h3,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const TypographyText(
                      'Before you start chatting, please review how Aura handles your data.',
                      variant: TypographyVariant.body2,
                      color: Colors.white70,
                    ),
                    const SizedBox(height: 28),
                    _buildSection(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'What data is shared',
                      body:
                          'When you send a message or use voice chat, the text of your message is sent to our servers for processing. No other personal data (such as your name, email, or account details) is included.',
                    ),
                    const SizedBox(height: 20),
                    _buildSection(
                      icon: Icons.business_center_outlined,
                      title: 'Who processes your data',
                      body:
                          'Your messages are processed by OpenAI, a third-party AI service, to generate responses. OpenAI receives only the message content needed to produce a reply.',
                    ),
                    const SizedBox(height: 20),
                    _buildSection(
                      icon: Icons.lock_outline_rounded,
                      title: 'How your data is protected',
                      body:
                          'Your messages are transmitted securely and are not used to train AI models. You can review our full privacy policy for more details.',
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => _openPrivacyPolicy(context),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.open_in_new_rounded,
                            size: 15,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Read our Privacy Policy',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.85),
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 76,
                          width: 200,
                          child: AppButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: context.actionButtonBackground,
                              foregroundColor: context.actionButtonForeground,
                              shape: const StadiumBorder(),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            onPressed: () async {
                              await AiConsentService.acceptConsent();
                              if (context.mounted) {
                                context.go('/home');
                              }
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: context.actionButtonForeground,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.check,
                                    size: 32,
                                    color: context.actionButtonBackground,
                                  ),
                                ),
                                Expanded(
                                  child: Center(
                                    child: TypographyText(
                                      'I Agree',
                                      variant: TypographyVariant.body1,
                                      color: context.actionButtonForeground,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.white54),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TypographyText(
                title,
                variant: TypographyVariant.body2,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              const SizedBox(height: 4),
              TypographyText(
                body,
                variant: TypographyVariant.body2,
                color: Colors.white54,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConsentWebViewPage extends StatefulWidget {
  const _ConsentWebViewPage({required this.title, required this.url});

  final String title;
  final String url;

  @override
  State<_ConsentWebViewPage> createState() => _ConsentWebViewPageState();
}

class _ConsentWebViewPageState extends State<_ConsentWebViewPage> {
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
    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
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
              const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}
