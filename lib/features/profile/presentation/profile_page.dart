import 'package:flutter/material.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: const [
        SizedBox(height: 28),
        _ProfileHeader(),
        SizedBox(height: 30),
        _ProfileMenu(),
        Spacer(),
        SizedBox(height: 110),
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
      ],
    );
  }
}

class _ProfileMenu extends StatelessWidget {
  const _ProfileMenu();

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.settings_outlined, 'Customization', true),
      (Icons.lock_outline, 'Security', true),
      (Icons.help_outline, 'Support', true),
      (Icons.attach_money_outlined, 'Subscription', true),
      (Icons.logout, 'Logout', false),
    ];

    return Column(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          _ProfileMenuItem(
            icon: items[i].$1,
            title: items[i].$2,
            showChevron: items[i].$3,
          ),
          if (i != items.length - 1) const _DividerInset(),
        ],
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
