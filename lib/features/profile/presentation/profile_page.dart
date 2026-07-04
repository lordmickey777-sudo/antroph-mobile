import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:antroph_mobile/core/responsive/responsive.dart';
import 'package:antroph_mobile/core/auth/utils/auth_guard.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';
import 'package:antroph_mobile/widgets/toast.dart';
import 'package:antroph_mobile/core/auth/state/auth_state.dart';
import 'package:antroph_mobile/features/profile/providers/profile_controller.dart';
import 'package:antroph_mobile/widgets/scroll_fade_gradient.dart';
import 'package:antroph_mobile/widgets/shimmer.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF141718)
          : const Color(0xFFF5F5F7),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: ContentWidth.content),
          child: ScrollFadeGradient(
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: SafeArea(
                      bottom: false,
                      child: Row(
                        children: [
                          Image.asset(
                            'assets/images/app_logo.png',
                            width: 38,
                            height: 38,
                          ),
                          const SizedBox(width: 2),
                          TypographyText(
                            'Profile',
                            variant: TypographyVariant.h3,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Column(
                    children: const [
                      SizedBox(height: 8),
                      _ProfileHeader(),
                      SizedBox(height: 30),
                      _ProfileMenu(),
                      SizedBox(height: 40),
                      _BuildNumber(),
                      SizedBox(height: 140),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.white70 : Colors.black54;

    final auth = ref.watch(authControllerProvider).value;
    final isGuest = auth == null;
    final profile = ref.watch(profileControllerProvider).value;
    final email = auth?.email ?? '';
    final displayName = isGuest
        ? 'Guest'
        : (profile?.displayName ??
              auth.displayName ??
              email.trim().split('@').first);
    final avatarUrl = isGuest ? null : profile?.avatarUrl;
    final avatarSize = AppSizing.avatarLarge.of(context);
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: isGuest
                  ? () async {
                      final result = await showAuthGuardSheet(
                        context,
                        ref,
                        actionDescription: 'Access your profile',
                      );
                      if (result == AuthGuardResult.loginSuccessful &&
                          context.mounted) {
                        context.pushNamed('edit-profile');
                      }
                    }
                  : () => context.pushNamed('edit-profile'),
              child: ClipOval(
                child: avatarUrl != null && avatarUrl.isNotEmpty
                    ? Image.network(
                        avatarUrl,
                        width: avatarSize,
                        height: avatarSize,
                        fit: BoxFit.cover,
                      )
                    : Image.asset(
                        'assets/images/avatar.png',
                        width: avatarSize,
                        height: avatarSize,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            if (!isGuest)
              Positioned(
                right: 9,
                bottom: 9,
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
        TypographyText(
          displayName,
          variant: TypographyVariant.h2,
          color: textColor,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        if (isGuest)
          GestureDetector(
            onTap: () => showAuthGuardSheet(
              context,
              ref,
              actionDescription: 'Access your profile',
            ),
            child: TypographyText(
              'Tap to login',
              variant: TypographyVariant.body2,
              color: secondaryTextColor,
            ),
          )
        else
          TypographyText(
            email,
            variant: TypographyVariant.body2,
            color: secondaryTextColor,
          ),
        const SizedBox(height: 12),
        if (!isGuest) _ProfileNudge(),
      ],
    );
  }
}

class _ProfileMenu extends ConsumerStatefulWidget {
  const _ProfileMenu();

  @override
  ConsumerState<_ProfileMenu> createState() => _ProfileMenuState();
}

class _ProfileMenuState extends ConsumerState<_ProfileMenu> {
  bool _isLoggingOut = false;

  @override
  Widget build(BuildContext context) {
    final isGuest = ref.watch(authControllerProvider).value == null;

    // Build menu items dynamically based on auth state
    final items = [
      (Icons.person_outline, 'Profile', true),
      (Icons.settings_outlined, 'Customization', true),
      (Icons.auto_awesome_outlined, 'Story mood', true),
      (Icons.qr_code_scanner, 'Scan', true),
      (Icons.lock_outline, 'Security', true),
      (Icons.help_outline, 'Support', true),
      (Icons.privacy_tip_outlined, 'Privacy Policy', true),
      (Icons.description_outlined, 'Terms of Service', true),
      if (!isGuest) (Icons.delete_outline, 'Delete account', false),
      (
        isGuest ? Icons.login : Icons.logout,
        isGuest ? 'Login' : 'Logout',
        false,
      ),
    ];

    // Actions that require authentication
    const authRequiredActions = {
      'Profile',
      'Customization',
      'Story mood',
      'Scan',
      'Security',
    };

    // final isDarkMode = ref.watch(themeModeProvider) == ThemeMode.dark;

    return Stack(
      children: [
        AbsorbPointer(
          absorbing: _isLoggingOut,
          child: Column(
            children: [
              // Theme toggle row
              // _ThemeToggleRow(
              //   isDarkMode: isDarkMode,
              //   onToggle: () => ref.read(themeModeProvider.notifier).toggleTheme(),
              // ),
              for (int i = 0; i < items.length; i++) ...[
                InkWell(
                  onTap: () async {
                    final title = items[i].$2;

                    // Check if action requires auth and user is guest
                    if (isGuest && authRequiredActions.contains(title)) {
                      final result = await showAuthGuardSheet(
                        context,
                        ref,
                        actionDescription: 'Access $title',
                      );
                      if (!context.mounted) return;
                      if (result != AuthGuardResult.authenticated &&
                          result != AuthGuardResult.loginSuccessful) {
                        return;
                      }
                    }

                    switch (title) {
                      case 'Profile':
                        context.pushNamed('edit-profile');
                        break;
                      case 'Customization':
                        context.pushNamed('customization');
                        break;
                      case 'Story mood':
                        context.pushNamed('setup-interests');
                        break;
                      case 'Scan':
                        context.pushNamed('scan');
                        break;
                      case 'Security':
                        showToast(context, 'Security coming soon');
                        break;
                      case 'Support':
                        context.pushNamed('support');
                        break;
                      case 'Privacy Policy':
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const _WebViewPage(
                              title: 'Privacy Policy',
                              url: 'https://www.antroph.com/privacy/',
                            ),
                          ),
                        );
                        break;
                      case 'Terms of Service':
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const _WebViewPage(
                              title: 'Terms of Service',
                              url: 'https://www.antroph.com/terms/',
                            ),
                          ),
                        );
                        break;
                      case 'Delete account':
                        final confirmed =
                            await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: const Color(0xFF1B1D1F),
                                title: const Text(
                                  'Delete account',
                                  style: TextStyle(color: Colors.white),
                                ),
                                content: const Text(
                                  'This will deactivate your account and schedule deletion. Continue?',
                                  style: TextStyle(color: Colors.white70),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(true),
                                    child: const Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.redAccent),
                                    ),
                                  ),
                                ],
                              ),
                            ) ??
                            false;
                        if (!confirmed) return;
                        try {
                          final msg = await ref
                              .read(profileControllerProvider.notifier)
                              .deleteAccount();
                          if (context.mounted) {
                            showToast(
                              context,
                              msg.isNotEmpty ? msg : 'Account deleted',
                              success: true,
                            );
                            context.go('/home');
                          }
                        } catch (e) {
                          if (context.mounted) {
                            showToast(context, e.toString());
                          }
                        }
                        break;
                      case 'Login':
                        await showAuthGuardSheet(
                          context,
                          ref,
                          actionDescription: 'Login to your account',
                        );
                        break;
                      case 'Logout':
                        if (_isLoggingOut) return;
                        setState(() => _isLoggingOut = true);
                        final controller = ref.read(
                          authControllerProvider.notifier,
                        );
                        try {
                          await controller.logout();
                          if (context.mounted) {
                            showToast(
                              context,
                              'Logged out successfully',
                              success: true,
                            );
                            await Future<void>.delayed(
                              const Duration(milliseconds: 650),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            showToast(context, e.toString());
                          }
                        } finally {
                          if (context.mounted) {
                            context.go('/');
                          }
                        }
                        break;
                      default:
                        showToast(context, '$title coming soon');
                    }
                  },
                  child: _ProfileMenuItem(
                    icon: items[i].$1,
                    title: items[i].$2,
                    showChevron: items[i].$3,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (_isLoggingOut)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.08),
              child: const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.6),
                ),
              ),
            ),
          ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final iconColor = isDark ? Colors.white : Colors.black87;
    final chevronColor = isDark ? Colors.white70 : Colors.black54;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 26),
          const SizedBox(width: 18),
          Expanded(
            child: TypographyText(
              title,
              variant: TypographyVariant.body1,
              color: textColor,
            ),
          ),
          if (showChevron) Icon(Icons.chevron_right, color: chevronColor),
        ],
      ),
    );
  }
}

class _ProfileNudge extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final chevronColor = isDark ? Colors.white70 : Colors.black54;

    final profileAsync = ref.watch(profileControllerProvider);
    return profileAsync.when(
      loading: () => const _ProfileNudgeShimmer(),
      error: (_, __) => const SizedBox.shrink(),
      data: (profile) {
        if (profile == null) return const SizedBox.shrink();
        // Defensive: treat null/false the same to avoid runtime errors on hot reload.
        if (profile.isCompleted == true) return const SizedBox.shrink();
        final missing = ref
            .read(profileControllerProvider.notifier)
            .missingFields(profile);
        if (missing.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: InkWell(
            onTap: () => context.pushNamed('edit-profile'),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orangeAccent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TypographyText(
                      'Complete your profile',
                      variant: TypographyVariant.body2,
                      color: textColor,
                    ),
                  ),
                  Icon(Icons.chevron_right, color: chevronColor),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProfileNudgeShimmer extends StatelessWidget {
  const _ProfileNudgeShimmer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.4)),
        ),
        child: const Row(
          children: [
            ShimmerCircle(size: 18),
            SizedBox(width: 10),
            Expanded(child: ShimmerText(height: 13)),
            SizedBox(width: 10),
            ShimmerCircle(size: 14),
          ],
        ),
      ),
    );
  }
}

class _BuildNumber extends StatelessWidget {
  const _BuildNumber();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final versionColor = isDark
        ? Colors.white.withValues(alpha: 0.4)
        : Colors.black.withValues(alpha: 0.4);

    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final info = snapshot.data!;
        return Center(
          child: TypographyText(
            'v${info.version} (${info.buildNumber})',
            variant: TypographyVariant.body2,
            color: versionColor,
          ),
        );
      },
    );
  }
}

class _WebViewPage extends StatefulWidget {
  const _WebViewPage({required this.title, required this.url});

  final String title;
  final String url;

  @override
  State<_WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<_WebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF101214))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => setState(() => _isLoading = false),
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101214),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101214),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.title),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Positioned.fill(
              child: ShimmerWebViewPlaceholder(
                backgroundColor: Color(0xFF101214),
              ),
            ),
        ],
      ),
    );
  }
}
