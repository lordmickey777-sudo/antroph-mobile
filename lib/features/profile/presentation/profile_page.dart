import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';
import 'package:antroph_mobile/widgets/toast.dart';
import 'package:antroph_mobile/core/auth/state/auth_state.dart';
import 'package:antroph_mobile/features/profile/providers/profile_controller.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Use a ListView with bottom padding to avoid overflow/clipping.
    return ListView(
      padding: const EdgeInsets.only(bottom: 140),
      children: const [
        SizedBox(height: 28),
        _ProfileHeader(),
        SizedBox(height: 30),
        _ProfileMenu(),
      ],
    );
  }
}

class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider).value;
    final profile = ref.watch(profileControllerProvider).value;
    final email = auth?.email ?? '';
    final displayName = profile?.displayName ?? auth?.displayName ?? email.trim().split('@').first;
    final avatarUrl = profile?.avatarUrl;
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: () => context.pushNamed('edit-profile'),
              child: ClipOval(
                child: avatarUrl != null && avatarUrl.isNotEmpty
                    ? Image.network(avatarUrl, width: 116, height: 116, fit: BoxFit.cover)
                    : Image.asset(
                        'assets/images/avatar.png',
                        width: 116,
                        height: 116,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            Positioned(
              right: 9,
              bottom: 9,
              child: Container(
                width: 14,
                height: 14,
                decoration: const BoxDecoration(color: Color(0xFF23D18B), shape: BoxShape.circle),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TypographyText(
          displayName,
          variant: TypographyVariant.h2,
          color: Colors.white,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        TypographyText(
          email,
          variant: TypographyVariant.body2,
          color: Colors.white.withOpacity(0.7),
        ),
        const SizedBox(height: 12),
        _ProfileNudge(),
      ],
    );
  }
}

class _ProfileMenu extends ConsumerWidget {
  const _ProfileMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const items = [
      (Icons.person_outline, 'Profile', true),
      (Icons.settings_outlined, 'Customization', true),
      (Icons.qr_code_scanner, 'Scan', true),
      (Icons.attach_money_outlined, 'Subscription', true),
      (Icons.lock_outline, 'Security', true),
      (Icons.help_outline, 'Support', true),
      (Icons.logout, 'Logout', false),
    ];

    return Column(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          InkWell(
            onTap: () async {
              final title = items[i].$2;
              switch (title) {
                case 'Profile':
                  context.pushNamed('edit-profile');
                  break;
                case 'Customization':
                  showToast(context, 'Opening customization…');
                  context.pushNamed('customization');
                  break;
                case 'Subscription':
                  showToast(context, 'Opening subscription…');
                  context.pushNamed('subscription');
                  break;
                case 'Scan':
                  showToast(context, 'Opening scanner…');
                  context.pushNamed('scan');
                  break;
                case 'Logout':
                  final controller = ref.read(authControllerProvider.notifier);
                  await controller.logout();
                  if (context.mounted) {
                    showToast(context, 'Logged out', success: true);
                    context.goNamed('login');
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
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  const _ProfileMenuItem({required this.icon, required this.title, this.showChevron = true});

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
            child: TypographyText(title, variant: TypographyVariant.body1, color: Colors.white),
          ),
          if (showChevron) const Icon(Icons.chevron_right, color: Colors.white70),
        ],
      ),
    );
  }
}

class _ProfileNudge extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileControllerProvider).value;
    final missing = ref.read(profileControllerProvider.notifier).missingFields(profile);
    if (missing.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: InkWell(
        onTap: () => context.pushNamed('edit-profile'),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.orangeAccent),
              const SizedBox(width: 10),
              Expanded(
                child: TypographyText(
                  'Complete your profile',

                  // 'Complete your profile: ${missing.join(', ')}',
                  variant: TypographyVariant.body2,
                  color: Colors.white,
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}

// class _DividerInset extends StatelessWidget {
//   const _DividerInset();
//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 20),
//       child: Container(height: 1, color: Colors.white12),
//     );
//   }
// }
