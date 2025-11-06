import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';
import 'package:antroph_mobile/widgets/bottom_nav.dart';
import 'package:antroph_mobile/features/profile/presentation/profile_page.dart';
import 'package:antroph_mobile/features/story/presentation/story_page.dart';
import 'package:antroph_mobile/core/auth/state/auth_state.dart';
import 'package:antroph_mobile/features/auth/pages/login_page.dart';
import 'package:antroph_mobile/features/auth/pages/signup_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  HomeTab _tab = HomeTab.interact;
  late final PageController _pageController;

  static const _bg = Color(0xFF121516);
  // Panel color was used by the inline sheet; kept here for future use if needed.

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Sliding content between tabs using PageView for fluid transitions
            Positioned.fill(
              child: PageView(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (index) {
                  // Sync the active tab when user swipes
                  setState(() {
                    if (index == 0) {
                      _tab = HomeTab.interact;
                    } else if (index == 1) {
                      _tab = HomeTab.story;
                    } else {
                      _tab = HomeTab.profile;
                    }
                  });
                },
                children: [
                  _InteractContent(size: size),
                  _AuthGated(child: const StoryPage()),
                  _AuthGated(child: const ProfilePage()),
                ],
              ),
            ),

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
                    // Animate to the chosen tab with a smooth slide
                    final targetPage = tab == HomeTab.interact ? 0 : (tab == HomeTab.story ? 1 : 2);
                    if (_pageController.hasClients) {
                      _pageController.animateToPage(
                        targetPage,
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                      );
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
}

class _AuthGated extends ConsumerStatefulWidget {
  const _AuthGated({required this.child});
  final Widget child;
  @override
  ConsumerState<_AuthGated> createState() => _AuthGatedState();
}

class _AuthGatedState extends ConsumerState<_AuthGated> {
  bool showLogin = true;

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(authControllerProvider);
    final user = userState.value;
    if (user != null) return widget.child;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: showLogin
          ? LoginPage(
              key: const ValueKey('login'),
              onSwitchSignup: () => setState(() => showLogin = false),
            )
          : SignUpPage(
              key: const ValueKey('signup'),
              onSwitchLogin: () => setState(() => showLogin = true),
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
      child: TypographyText(label, variant: TypographyVariant.body2, color: Colors.white),
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
                BoxShadow(color: Colors.white.withOpacity(0.05), blurRadius: 40, spreadRadius: 8),
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
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
        ),
        SizedBox(height: size.height * 0.15),
      ],
    );
  }
}
