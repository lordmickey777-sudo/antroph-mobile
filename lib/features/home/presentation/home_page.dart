import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';
import 'package:antroph_mobile/widgets/bottom_nav.dart';

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
            if (_tab == HomeTab.profile) const _ProfileContent(),

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
          child: SafeArea(
            top: false,
            child: Container(), // empty 100% height sheet
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

class _ProfileContent extends StatelessWidget {
  const _ProfileContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 28),
        // Avatar with online dot
        Stack(
          clipBehavior: Clip.none,
          children: [
            ClipOval(
              child: Image.asset(
                'assets/images/avatar.png',
                width: 116,
                height: 116,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              right: 6,
              bottom: 6,
              child: Container(
                width: 14,
                height: 14,
                decoration: const BoxDecoration(
                  color: Color(0xFF23D18B),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const TypographyText(
          'Otunba Fortune',
          variant: TypographyVariant.h2,
          color: Colors.white,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        TypographyText(
          '4tuneadebiyi@gmail.com',
          variant: TypographyVariant.body2,
          color: Colors.white.withOpacity(0.7),
        ),
        const SizedBox(height: 30),

        // Menu items
        const _ProfileMenuItem(
          icon: Icons.settings_outlined,
          title: 'Customization',
        ),
        const _DividerInset(),
        const _ProfileMenuItem(icon: Icons.lock_outline, title: 'Security'),
        const _DividerInset(),
        const _ProfileMenuItem(icon: Icons.help_outline, title: 'Support'),
        const _DividerInset(),
        const _ProfileMenuItem(
          icon: Icons.attach_money_outlined,
          title: 'Subscription',
        ),
        const _DividerInset(),
        const _ProfileMenuItem(
          icon: Icons.logout,
          title: 'Logout',
          showChevron: false,
        ),

        const Spacer(),
        const SizedBox(height: 110),
      ],
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  const _ProfileMenuItem({
    required this.icon,
    required this.title,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 26),
          const SizedBox(width: 18),
          Expanded(
            child: TypographyText(
              title,
              variant: TypographyVariant.body1,
              color: Colors.white,
            ),
          ),
          if (showChevron)
            const Icon(Icons.chevron_right, color: Colors.white70),
        ],
      ),
    );
  }
}

class _DividerInset extends StatelessWidget {
  const _DividerInset();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(height: 1, color: Colors.white12),
    );
  }
}
