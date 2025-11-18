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
import 'package:antroph_mobile/features/home/providers/voice_chat_provider.dart';
import 'package:antroph_mobile/features/home/widgets/expression_widgets.dart';
import 'package:antroph_mobile/features/home/widgets/permission_modal.dart';

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

class _InteractContent extends ConsumerStatefulWidget {
  const _InteractContent({required this.size});
  final Size size;

  @override
  ConsumerState<_InteractContent> createState() => _InteractContentState();
}

class _InteractContentState extends ConsumerState<_InteractContent> {
  @override
  void initState() {
    super.initState();
    // Listen for permission modal state changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual(voiceChatControllerProvider.select((state) => state.permissionDialog), (
        previous,
        next,
      ) {
        if (!mounted || next == PermissionDialogType.none) {
          return;
        }
        _showPermissionDialog(next);
      });
    });
  }

  Future<void> _showPermissionDialog(PermissionDialogType type) async {
    final controller = ref.read(voiceChatControllerProvider.notifier);
    if (type == PermissionDialogType.education) {
      final continueRequest = await MicrophoneEducationDialog.show(context) ?? false;
      controller.handleEducationDialogResult(continueRequest);
    } else if (type == PermissionDialogType.settings) {
      await MicrophonePermissionModal.show(context);
      controller.dismissPermissionDialog();
    }
  }

  @override
  Widget build(BuildContext context) {
    final voiceChatState = ref.watch(voiceChatControllerProvider);
    final voiceChatController = ref.read(voiceChatControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        _TopChips(),
        SizedBox(height: widget.size.height * 0.06),

        // Expression Display with synchronized expressions
        Center(
          child: ExpressionDisplay(
            expression: voiceChatState.currentExpression,
            size: widget.size.width * 0.55,
            showGlow: true,
          ),
        ),

        const SizedBox(height: 28),

        // AI Response or Status Text
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: TypographyText(
              _getStatusText(voiceChatState),
              key: ValueKey(voiceChatState.aiResponse ?? voiceChatState.isRecording),
              variant: TypographyVariant.h2,
              textAlign: TextAlign.center,
              color: Colors.white,
            ),
          ),
        ),

        // Error message display
        if (voiceChatState.errorMessage != null) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      voiceChatState.errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red, size: 18),
                    onPressed: () => voiceChatController.clearError(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),
        ],

        const Spacer(),

        // Recording/Processing indicator
        if (voiceChatState.isRecording)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.red),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fiber_manual_record, color: Colors.red, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Recording...',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          )
        else if (voiceChatState.isProcessing)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Processing...',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 20),

        // Voice Record Button
        Center(
          child: VoiceRecordButton(
            isRecording: voiceChatState.isRecording,
            onPressed: voiceChatState.isProcessing || voiceChatState.isPlaying
                ? null
                : () async {
                    if (voiceChatState.isRecording) {
                      await voiceChatController.stopRecordingAndSend();
                    } else {
                      await voiceChatController.startRecording();
                    }
                  },
            size: 75,
          ),
        ),
        SizedBox(height: widget.size.height * 0.15),
      ],
    );
  }

  String _getStatusText(VoiceChatState state) {
    if (state.isRecording) {
      return 'Listening...';
    } else if (state.isProcessing) {
      return 'Thinking...';
    } else if (state.isPlaying && state.aiResponse != null) {
      return state.aiResponse!;
    } else if (state.aiResponse != null) {
      return state.aiResponse!;
    }
    return 'Bonjour! Comment ça va?';
  }
}
