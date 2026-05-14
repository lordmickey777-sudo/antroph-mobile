import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:video_player/video_player.dart';
import 'package:antroph_mobile/core/theme/theme_provider.dart';
import 'package:antroph_mobile/features/hardware/presentation/waitlist_bottom_sheet.dart';

class HardwarePage extends StatefulWidget {
  const HardwarePage({super.key});

  @override
  State<HardwarePage> createState() => _HardwarePageState();
}

class _HardwarePageState extends State<HardwarePage> with AutomaticKeepAliveClientMixin {
  static const _kMiddlePage = 50; // large offset for infinite scroll
  late final PageController _pageController;
  double _currentPage = _kMiddlePage + 1.0;

  @override
  bool get wantKeepAlive => true;

  static const _items = [
    _CarouselItem('assets/videos/h1.mp4', 'Brio Penguin'),
    _CarouselItem('assets/videos/h2.mp4', 'Aura Table top'),
    _CarouselItem('assets/videos/h3.mp4', 'Brio Guinea pig'),
  ];

  late final List<VideoPlayerController> _videoControllers;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 0.72,
      initialPage: _kMiddlePage + 1, // start on middle real item
    );
    _pageController.addListener(() {
      setState(
        () => _currentPage = _pageController.page ?? (_kMiddlePage + 1.0),
      );
    });

    _videoControllers = _items.map((item) {
      final controller = VideoPlayerController.asset(item.video);
      controller
          .initialize()
          .then((_) {
            controller.setLooping(true);
            controller.setVolume(0);
            controller.play();
            if (mounted) setState(() {});
          })
          .catchError((e) {
            debugPrint('Video init error for ${item.video}: $e');
          });
      return controller;
    }).toList();
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _videoControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = context.isDarkMode;

    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: screenHeight),
          child: Column(
            children: [
              SizedBox(height: MediaQuery.of(context).padding.top + 40),
              // 3D Carousel
              SizedBox(
                height: screenHeight * 0.50,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _kMiddlePage * 2, // virtually infinite
                  clipBehavior: Clip.none,
                  itemBuilder: (context, index) {
                    final realIndex = index % _items.length;
                    final delta = index - _currentPage;
                    return _buildCarouselCard(delta, realIndex, isDark);
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
              const SizedBox(height: 32),
              // Join Waitlist button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => showWaitlistSheet(context),
                    icon: SvgPicture.asset(
                      'assets/icons/hardware.svg',
                      width: 20,
                      height: 20,
                      colorFilter: ColorFilter.mode(
                        isDark ? Colors.black : Colors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                    label: const Text(
                      'Join Waitlist',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCarouselCard(double delta, int realIndex, bool isDark) {
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

    final controller = _videoControllers[realIndex];

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
            child: controller.value.isInitialized
                ? FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: controller.value.size.width,
                      height: controller.value.size.height,
                      child: VideoPlayer(controller),
                    ),
                  )
                : const Center(child: CircularProgressIndicator.adaptive()),
          ),
        ),
      ),
    );
  }
}

class _CarouselItem {
  const _CarouselItem(this.video, this.label);
  final String video;
  final String label;
}
