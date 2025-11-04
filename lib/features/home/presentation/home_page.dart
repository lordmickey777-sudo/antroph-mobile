import 'package:flutter/material.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const TypographyText('Antroph', variant: TypographyVariant.h3),
      ),
      body: const Center(
        child: TypographyText(
          'Welcome to Antroph',
          variant: TypographyVariant.body1,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
