import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:antroph_mobile/widgets/bottom_nav.dart';
import 'package:antroph_mobile/features/profile/presentation/profile_page.dart';
import 'package:antroph_mobile/features/story/presentation/collections_page.dart';
import 'package:antroph_mobile/features/story/presentation/collections_action_button.dart';
import 'package:antroph_mobile/features/story/presentation/story_page.dart';
import 'package:antroph_mobile/core/auth/state/auth_state.dart';
import 'package:antroph_mobile/features/auth/pages/login_page.dart';
import 'package:antroph_mobile/features/auth/pages/signup_page.dart';

const _homeBg = Color(0xFF121516);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  HomeTab _tab = HomeTab.story;
  late final PageController _pageController;

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
      backgroundColor: _homeBg,
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
                      _tab = HomeTab.story;
                    } else {
                      _tab = HomeTab.profile;
                    }
                  });
                },
                children: [
                  _AuthGated(child: const StoryPage()),
                  _AuthGated(child: const ProfilePage()),
                ],
              ),
            ),
            if (_tab != HomeTab.profile)
              Positioned(
                top: 12,
                right: 16,
                child: CollectionsActionButton(
                  onPressed: _openCollections,
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
                    final targetPage = tab == HomeTab.story ? 0 : 1;
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

  void _openCollections() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CollectionsPage()));
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
