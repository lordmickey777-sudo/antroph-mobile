import 'package:flutter/material.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const _bg = Color(0xFF121516);
  static const _panel = Color(0xFF2A2D2F);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Main content column
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                _TopChips(),
                SizedBox(height: size.height * 0.06),

                // Face image with subtle glow
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.05),
                          blurRadius: 40,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/gif.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Greeting text
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: TypographyText(
                    'Bonjour! Comment ca va?',
                    variant: TypographyVariant.h2,
                    textAlign: TextAlign.center,
                    color: Colors.white,
                  ),
                ),

                const Spacer(),

                // Big circular action button
                Center(
                  child: Container(
                    width: 75,
                    height: 75,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),

                SizedBox(height: size.height * 0.15), // space for bottom panel
              ],
            ),

            // Bottom rounded navigation panel
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Center(
                child: Container(
                  width: size.width * 0.86,
                  height: 76,
                  decoration: BoxDecoration(
                    color: _panel,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: const [
                      _NavItem.selected(
                        iconPath: 'assets/images/chat.png',
                        label: 'Interact',
                      ),
                      Spacer(),
                      _NavItem(iconPath: 'assets/images/tool.png'),
                      SizedBox(width: 16),
                      _NavItem(iconPath: 'assets/images/profile.png'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopChips extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const tags = [
      'Learn French',
      'Practice Gratitude',
      'Be Homelander',
      'Parenting',
      'Workout',
      'Mindfulness',
    ];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: tags.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) => _chip(tags[i]),
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(18),
      ),
      child: TypographyText(
        label,
        variant: TypographyVariant.body2,
        color: Colors.white,
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.iconPath}) : label = null, _selected = false;
  const _NavItem.selected({required this.iconPath, required this.label})
    : _selected = true;

  final String iconPath;
  final String? label;
  final bool _selected;

  @override
  Widget build(BuildContext context) {
    if (_selected) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Image.asset(
                  iconPath,
                  width: 24,
                  height: 24,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                TypographyText(
                  label!,
                  variant: TypographyVariant.body2,
                  color: Colors.white,
                ),
              ],
            ),
          ),
          // green presence dot
          Positioned(
            left: -4,
            top: -4,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFF23D18B),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      );
    }

    return SizedBox(
      height: 56,
      width: 56,
      child: Center(
        child: Image.asset(
          iconPath,
          width: 24,
          height: 24,
          color: Colors.white,
        ),
      ),
    );
  }
}
