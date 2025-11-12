import 'package:flutter/material.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';
import 'package:antroph_mobile/widgets/toast.dart';
import 'package:antroph_mobile/widgets/app_button.dart';

class SubscriptionPage extends StatelessWidget {
  const SubscriptionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription'),
        leading: const BackButton(),
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        children: [
          _planCard(context),
          const SizedBox(height: 24),
          SizedBox(
            height: 56,
            child: AppButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1F2223),
                foregroundColor: Colors.white,
              ),
              onPressed: () => showToast(context, 'Subscription flow coming soon'),
              child: const Text('Subscribe'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _planCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1F22),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2D2F),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const TypographyText(
                'Most Popular',
                variant: TypographyVariant.body2,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const TypographyText('Monthly', variant: TypographyVariant.h2, color: Colors.white),
          const SizedBox(height: 8),
          const TypographyText('68', variant: TypographyVariant.h2, color: Colors.white),
          const SizedBox(height: 16),
          _feature('Unlimited conversations'),
          _feature('Backup your stories'),
          _feature('Daily Firmware Updates'),
          _feature('5 Story combo'),
        ],
      ),
    );
  }

  Widget _feature(String text) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF222427),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF23D18B)),
          const SizedBox(width: 12),
          Expanded(
            child: TypographyText(text, variant: TypographyVariant.body1, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
