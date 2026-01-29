import 'package:flutter/material.dart';
import 'package:antroph_mobile/core/responsive/responsive.dart';
import 'package:antroph_mobile/widgets/bottom_nav.dart';
import 'package:antroph_mobile/features/profile/presentation/profile_page.dart';
import 'package:antroph_mobile/features/story/presentation/story_page.dart';

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
    // Responsive bottom spacing: larger on tablets
    final bottomPadding = responsive<double>(
      context,
      phone: 16,
      tablet: 20,
      largeTablet: 24,
    );
    final horizontalPadding = AppPadding.horizontal.of(context);

    return Scaffold(
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
                children: const [
                  StoryPage(),
                  ProfilePage(),
                ],
              ),
            ),
            // Bottom rounded navigation panel
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomPadding,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
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

}
