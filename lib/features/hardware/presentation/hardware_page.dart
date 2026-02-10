import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:antroph_mobile/core/theme/theme_provider.dart';

class HardwarePage extends StatefulWidget {
  const HardwarePage({super.key});

  @override
  State<HardwarePage> createState() => _HardwarePageState();
}

class _HardwarePageState extends State<HardwarePage> {
  static const _kMiddlePage = 50; // large offset for infinite scroll
  late final PageController _pageController;
  double _currentPage = _kMiddlePage + 1.0;

  static const _items = [
    _CarouselItem('assets/images/hw1.png', 'Brio Penguin'),
    _CarouselItem('assets/images/hw2.png', 'Aura Table top'),
    _CarouselItem('assets/images/hw3.png', 'Brio Guinea pig'),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 0.72,
      initialPage: _kMiddlePage + 1, // start on middle real item
    );
    _pageController.addListener(() {
      setState(() => _currentPage = _pageController.page ?? (_kMiddlePage + 1.0));
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return Scaffold(
      body: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + 40),
          // 3D Carousel
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.50,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _kMiddlePage * 2, // virtually infinite
              clipBehavior: Clip.none,
              itemBuilder: (context, index) {
                final realIndex = index % _items.length;
                final delta = index - _currentPage;
                return _buildCarouselCard(delta, _items[realIndex], isDark);
              },
            ),
          ),
          const SizedBox(height: 24),
          // Title & subtitle with fade transition
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
        ],
      ),
    );
  }

  Widget _buildCarouselCard(double delta, _CarouselItem item, bool isDark) {
    // Clamp delta so the max rotation is bounded
    final clampedDelta = delta.clamp(-1.5, 1.5);

    // Rotation angle: center = 0, sides rotate up to ~15 degrees
    final rotationY = clampedDelta * (math.pi / 22);

    // Scale: center = 1.05 (pop), sides shrink slightly
    final scale = 1.05 - (clampedDelta.abs() * 0.12);

    // Opacity: center = 1.0, sides slightly dimmed
    final opacity = (1.0 - clampedDelta.abs() * 0.2).clamp(0.6, 1.0);

    // Lateral translation for depth spacing
    final translateX = clampedDelta * 14;

    final transform = Matrix4.identity()
      ..setEntry(3, 2, 0.001) // perspective
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
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
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
