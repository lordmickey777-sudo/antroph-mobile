import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';
import 'package:antroph_mobile/widgets/bottom_nav.dart';
import 'package:antroph_mobile/features/profile/presentation/profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  HomeTab _tab = HomeTab.interact;

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
            if (_tab == HomeTab.interact) _InteractContent(size: size),
            if (_tab == HomeTab.profile) const ProfilePage(),

            // Bottom rounded navigation panel
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: size.width * 0.07),
                child: BottomNav(
                  current: _tab,
                  onChanged: (tab) async {
                    if (tab == HomeTab.story) {
                      setState(() => _tab = HomeTab.story);
                      await _openStorySheet(context);
                      if (mounted && _tab == HomeTab.story) {
                        setState(() => _tab = HomeTab.interact);
                      }
                      return;
                    }
                    setState(() => _tab = tab);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openStorySheet(BuildContext context) async {
    await Navigator.of(context).push(
      CupertinoSheetRoute(
        builder: (context) => CupertinoPageScaffold(
          backgroundColor: _panel,
          child: const SafeArea(
            top: false,
            child: SizedBox.expand(), // empty full-height sheet
          ),
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
        borderRadius: BorderRadius.circular(50),
      ),
      child: TypographyText(
        label,
        variant: TypographyVariant.body2,
        color: Colors.white,
      ),
    );
  }
}

class _InteractContent extends StatelessWidget {
  const _InteractContent({required this.size});
  final Size size;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        _TopChips(),
        SizedBox(height: size.height * 0.06),
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
                width: size.width * 0.55,
                height: size.width * 0.55,
              ),
          ),
        ),
        const SizedBox(height: 28),
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
        SizedBox(height: size.height * 0.15),
      ],
    );
  }
}
