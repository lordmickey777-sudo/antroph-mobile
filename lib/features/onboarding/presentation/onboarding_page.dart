import 'dart:io' show Platform;

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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Decorative big eye top-left
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Platform.environment.containsKey('FLUTTER_TEST')
                    ? const SizedBox.shrink()
                    : Image.asset(
                        'assets/images/eye_logo.png',
                        height: MediaQuery.of(context).size.height * 0.42,
                        fit: BoxFit.cover,
                        alignment: Alignment.topLeft,
                      ),
              ),
            ),

            // Content
            Column(
              children: [
                const Spacer(flex: 5),
                // PageView dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    final selected = i == _index;
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
                const SizedBox(height: 12),

                // Slides
                Expanded(
                  flex: 11,
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
                            const SizedBox(height: 8),
                            Text(
                              'Chat With Your\nFavourite Ai',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Chat with the smartest AI Future\nExperience power of AI with us',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Colors.white70),
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
                                          duration: const Duration(
                                            milliseconds: 250,
                                          ),
                                          curve: Curves.easeOut,
                                        );
                                      } else {
                                        context.go('/home');
                                      }
                                    },
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
              ],
            ),
          ],
        ),
      ),
    );
  }
}
