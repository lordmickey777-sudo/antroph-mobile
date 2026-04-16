import 'package:flutter/material.dart';

class PremiumStar extends StatelessWidget {
  const PremiumStar({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.star_rounded, color: const Color(0xFFFFD54A), size: size);
  }
}
