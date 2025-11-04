import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _index = 0;

  // Slide content configuration
  static const _slides = [
    (
      title: 'Chat With Your\nFavourite Ai',
      subtitle:
          'Chat with the smartest AI Future\nExperience power of AI with us',
      kind: 'eye',
      asset: 'assets/images/t_logo.png',
    ),
    (
      title: 'Chat With Your\nFavourite Ai',
      subtitle:
          'Chat with the smartest AI Future\nExperience power of AI with us',
      kind: 'eye',
      asset: 'assets/images/t_logo.png',
    ),
    (
      title: 'Your Sweet\nCompanion',
      subtitle: 'Have crazy fun with the smartest AI powered\nTablebot',
      kind: 'image',
      asset: 'assets/images/onboarding_3.png',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PageView.builder(
          controller: _controller,
          itemCount: 3,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (context, i) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 24),
                  _buildTopVisual(context, i),
                  const SizedBox(height: 16),

                  // Page indicators under the image
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (d) {
                      final selected = d == _index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        width: selected ? 10 : 6,
                        height: selected ? 10 : 6,
                        decoration: BoxDecoration(
                          color: selected ? Colors.white : Colors.white24,
                          shape: BoxShape.circle,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    _slides[i].title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _slides[i].subtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                  ),
                  const Spacer(),

                  // Primary button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 64,
                        width: 260,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2A2D2F),
                            foregroundColor: Colors.white,
                            shape: const StadiumBorder(),
                          ),
                          onPressed: () {
                            if (_index < 2) {
                              _controller.nextPage(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOut,
                              );
                            } else {
                              context.go('/home');
                            }
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: const BoxDecoration(
                                  color: Colors.black,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.smart_toy_outlined,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(_index < 2 ? 'Next' : 'Start'),
                              const SizedBox(width: 12),
                              const Icon(Icons.double_arrow),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopVisual(BuildContext context, int index) {
    final slide = _slides[index];
    if (slide.kind == 'image') {
      return Column(
        children: [
          Container(
            width: 340,
            height: 430,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x222C2F31), Color(0x002C2F31)],
              ),
            ),
            alignment: Alignment.center,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Image.asset(
                slide.asset,
                width: 300,
                height: 380,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      );
    }
    return Image.asset(
      'assets/images/eye_logo.png',
      height: MediaQuery.of(context).size.height * 0.42,
      fit: BoxFit.cover,
      alignment: Alignment.topLeft,
    );
  }
}
