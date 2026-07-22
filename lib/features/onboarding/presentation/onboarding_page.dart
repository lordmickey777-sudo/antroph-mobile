import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:antroph_mobile/core/auth/state/auth_state.dart';
import 'package:antroph_mobile/core/onboarding/app_setup_route_service.dart';
import 'package:antroph_mobile/core/responsive/responsive.dart';
import 'package:antroph_mobile/core/theme/theme_provider.dart';
import 'package:antroph_mobile/widgets/app_button.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _controller = PageController();
  int _index = 0;

  // Slide content configuration
  static const _slides = [
    (
      title: 'Enter Stories\nThat Talk Back',
      subtitle:
          'Step into an interactive story world where every session feels playful, personal, and alive.',
      asset: 'assets/images/onboarding_2.png',
    ),
    (
      title: 'Create Your\nExperience',
      subtitle:
          'Pick the interests and voice that shape Aura before you land in your story home.',
      asset: 'assets/images/onboarding_3.png',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final user = ref.read(authControllerProvider).value;
    if (!mounted) return;

    if (user == null) {
      context.go('/auth/login');
      return;
    }

    context.go(AppSetupRouteService.personalizationRoute);
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = AppPadding.form.of(context);
    // Always use dark theme for onboarding screens regardless of app theme
    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: ContentWidth.form),
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 24),
                      _buildTopVisual(context, i),
                      const SizedBox(height: 20),

                      // Page indicators under the image
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_slides.length, (d) {
                          final selected = d == _index;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            width: selected ? 16 : 10,
                            height: selected ? 16 : 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: selected
                                  ? Colors.transparent
                                  : Colors.white24,
                              border: selected
                                  ? Border.all(color: Colors.white, width: 0.7)
                                  : null,
                            ),
                            child: selected
                                ? Center(
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  )
                                : null,
                          );
                        }),
                      ),
                      const SizedBox(height: 16),

                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                        ),
                        child: TypographyText(
                          _slides[i].title,
                          variant: TypographyVariant.h2,
                          textAlign: TextAlign.center,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      // const SizedBox(height: 12),
                      // Padding(
                      //   padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                      //   child: TypographyText(
                      //     _slides[i].subtitle,
                      //     variant: TypographyVariant.body2,
                      //     textAlign: TextAlign.center,
                      //     color: Colors.white70,
                      //   ),
                      // ),
                      const Spacer(),

                      // Primary button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 58,
                            width: 168,
                            child: AppButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: context.actionButtonBackground,
                                foregroundColor: context.actionButtonForeground,
                                shape: const StadiumBorder(),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                              ),
                              onPressed: () async {
                                if (_index < _slides.length - 1) {
                                  _controller.nextPage(
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeOut,
                                  );
                                } else {
                                  await _completeOnboarding();
                                }
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: context.actionButtonForeground,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.auto_awesome,
                                      size: 22,
                                      color: context.actionButtonBackground,
                                    ),
                                  ),
                                  Expanded(
                                    child: Center(
                                      child: TypographyText(
                                        _index < _slides.length - 1
                                            ? 'Next'
                                            : 'Continue',
                                        variant: TypographyVariant.body1,
                                        color: context.actionButtonForeground,
                                      ),
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.only(right: 10.0),
                                    child: Icon(Icons.double_arrow, size: 18),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopVisual(BuildContext context, int index) {
    final slide = _slides[index];
    return Image.asset(
      slide.asset,
      width: double.infinity,
      fit: BoxFit.fitWidth,
    );
  }
}
