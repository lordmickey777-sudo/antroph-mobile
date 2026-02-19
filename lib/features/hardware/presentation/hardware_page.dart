import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:antroph_mobile/core/auth/state/auth_state.dart';
import 'package:antroph_mobile/core/theme/theme_provider.dart';
import 'package:antroph_mobile/features/hardware/data/waitlist_repository.dart';

class HardwarePage extends ConsumerStatefulWidget {
  const HardwarePage({super.key});

  @override
  ConsumerState<HardwarePage> createState() => _HardwarePageState();
}

enum _WaitlistState { idle, loading, success, error }

class _HardwarePageState extends ConsumerState<HardwarePage>
    with TickerProviderStateMixin {
  static const _kMiddlePage = 50;
  late final PageController _pageController;
  double _currentPage = _kMiddlePage + 1.0;

  static const _items = [
    _CarouselItem('assets/images/hw1.png', 'Brio Penguin'),
    _CarouselItem('assets/images/hw2.png', 'Aura Table top'),
    _CarouselItem('assets/images/hw3.png', 'Brio Guinea pig'),
  ];

  _WaitlistState _waitlistState = _WaitlistState.idle;

  // Monochrome scan animation
  late final AnimationController _scanCtrl;
  late final Animation<double> _scanAnim;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 0.72,
      initialPage: _kMiddlePage + 1,
    );
    _pageController.addListener(() {
      setState(
          () => _currentPage = _pageController.page ?? (_kMiddlePage + 1.0));
    });

    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _scanAnim = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _scanCtrl, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _joinWaitlist() async {
    final auth = ref.read(authControllerProvider).value;
    if (auth == null) return;

    setState(() => _waitlistState = _WaitlistState.loading);
    HapticFeedback.lightImpact();

    try {
      await WaitlistRepository.I.joinWaitlist(
        email: auth.email,
        name: auth.displayName ?? auth.username,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() => _waitlistState = _WaitlistState.success);
    } on DioException catch (_) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() => _waitlistState = _WaitlistState.error);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _waitlistState = _WaitlistState.idle);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _waitlistState = _WaitlistState.error);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _waitlistState = _WaitlistState.idle);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return Scaffold(
      body: Stack(
        children: [
          // Monochrome scan line overlay
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _scanAnim,
              builder: (context, _) {
                return IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(-1, _scanAnim.value),
                        end: Alignment(1, _scanAnim.value + 0.4),
                        colors: [
                          Colors.transparent,
                          (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.03),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Page content
          Column(
            children: [
              SizedBox(height: MediaQuery.of(context).padding.top + 40),
              // 3D Carousel
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.50,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _kMiddlePage * 2,
                  clipBehavior: Clip.none,
                  itemBuilder: (context, index) {
                    final realIndex = index % _items.length;
                    final delta = index - _currentPage;
                    return _buildCarouselCard(
                        delta, _items[realIndex], isDark);
                  },
                ),
              ),
              const SizedBox(height: 24),
              // Title
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _items[_currentPage.round() % _items.length].label,
                  key: ValueKey(_currentPage.round() % _items.length),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: context.primaryTextColor,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Subtitle
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: Padding(
                  key: ValueKey(_currentPage.round() % _items.length),
                  padding: const EdgeInsets.symmetric(horizontal: 48.0),
                  child: Text(
                    'Our Robots are coming to your location soon',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.5)
                          : Colors.black.withValues(alpha: 0.45),
                      height: 1.4,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              // Waitlist button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48.0),
                child: _buildWaitlistButton(isDark),
              ),
              SizedBox(
                  height: MediaQuery.of(context).padding.bottom + 90),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWaitlistButton(bool isDark) {
    final bg = isDark ? Colors.white : Colors.black;
    final fg = isDark ? Colors.black : Colors.white;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: _buildButtonForState(bg, fg),
    );
  }

  Widget _buildButtonForState(Color bg, Color fg) {
    switch (_waitlistState) {
      case _WaitlistState.success:
        return SizedBox(
          key: const ValueKey('success'),
          width: double.infinity,
          height: 52,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9999),
              color: bg.withValues(alpha: 0.12),
              border: Border.all(color: bg.withValues(alpha: 0.25)),
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, color: bg, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'You\'re on the list',
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: bg,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

      case _WaitlistState.error:
        return SizedBox(
          key: const ValueKey('error'),
          width: double.infinity,
          height: 52,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9999),
              color: Colors.red.withValues(alpha: 0.08),
              border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
            ),
            child: const Center(
              child: Text(
                'Failed — retrying...',
                style: TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        );

      case _WaitlistState.loading:
        return SizedBox(
          key: const ValueKey('loading'),
          width: double.infinity,
          height: 52,
          child: AnimatedBuilder(
            animation: _scanAnim,
            builder: (context, child) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(9999),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9999),
                    color: bg.withValues(alpha: 0.06),
                    border: Border.all(color: bg.withValues(alpha: 0.15)),
                  ),
                  child: Stack(
                    children: [
                      // Sweep gradient across the button
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment(_scanAnim.value * 1.5, 0),
                              end: Alignment(
                                  _scanAnim.value * 1.5 + 0.6, 0),
                              colors: [
                                Colors.transparent,
                                bg.withValues(alpha: 0.08),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      Center(child: child!),
                    ],
                  ),
                ),
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: bg.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'PROCESSING...',
                  style: TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: bg.withValues(alpha: 0.5),
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        );

      case _WaitlistState.idle:
        return SizedBox(
          key: const ValueKey('idle'),
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _joinWaitlist,
            icon: const Icon(Icons.smart_toy_outlined, size: 20),
            label: const Text(
              'Join Waitlist',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: bg,
              foregroundColor: fg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9999),
              ),
            ),
          ),
        );
    }
  }

  Widget _buildCarouselCard(double delta, _CarouselItem item, bool isDark) {
    final clampedDelta = delta.clamp(-1.5, 1.5);
    final rotationY = clampedDelta * (math.pi / 22);
    final scale = 1.05 - (clampedDelta.abs() * 0.12);
    final opacity = (1.0 - clampedDelta.abs() * 0.2).clamp(0.6, 1.0);
    final translateX = clampedDelta * 14;

    final transform = Matrix4.identity()
      ..setEntry(3, 2, 0.001)
      ..translate(translateX, 0.0, 0.0)
      ..rotateY(-rotationY)
      ..scale(scale);

    return Transform(
      transform: transform,
      alignment: Alignment.center,
      child: Opacity(
        opacity: opacity,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: isDark ? const Color(0xFF1F2223) : Colors.white,
            boxShadow: [
              BoxShadow(
                color:
                    Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
                blurRadius: 24,
                offset: const Offset(0, 12),
                spreadRadius: -4,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(item.image, fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }
}

class _CarouselItem {
  const _CarouselItem(this.image, this.label);
  final String image;
  final String label;
}
