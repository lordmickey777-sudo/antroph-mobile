import 'package:flutter/material.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';
import 'package:antroph_mobile/widgets/toast.dart';

class CustomizationPage extends StatefulWidget {
  const CustomizationPage({super.key});

  @override
  State<CustomizationPage> createState() => _CustomizationPageState();
}

class _CustomizationPageState extends State<CustomizationPage> {
  double logic = 0.8;
  double vibe = 0.6;
  double love = 0.1;
  double sass = 1.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customization'),
        leading: const BackButton(),
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        children: [
          _slider(
            emoji: '🤔',
            title: 'Logical reasoning',
            value: logic,
            onChanged: (v) => setState(() => logic = v),
            minLabel: 'Genius',
          ),
          const SizedBox(height: 12),
          _slider(
            emoji: '😎',
            title: 'Vibe',
            value: vibe,
            onChanged: (v) => setState(() => vibe = v),
            minLabel: 'Rockstar',
          ),
          const SizedBox(height: 12),
          _slider(
            emoji: '❤️',
            title: 'Love',
            value: love,
            onChanged: (v) => setState(() => love = v),
            minLabel: 'Stone',
          ),
          const SizedBox(height: 12),
          _slider(
            emoji: '🧑🏽‍🏫',
            title: 'Sass',
            value: sass,
            onChanged: (v) => setState(() => sass = v),
            minLabel: 'Gaga',
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1F2223),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                showToast(context, 'Preferences saved', success: true);
              },
              child: const Text('Save changes'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _slider({
    required String emoji,
    required String title,
    required double value,
    required ValueChanged<double> onChanged,
    String? minLabel,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TypographyText(title, variant: TypographyVariant.body1, color: Colors.white),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.white,
                ),
                child: Slider(value: value, onChanged: onChanged),
              ),
              if (minLabel != null)
                TypographyText(minLabel, variant: TypographyVariant.body2, color: Colors.white70),
            ],
          ),
        ),
      ],
    );
  }
}
