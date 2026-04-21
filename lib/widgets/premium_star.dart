import 'package:flutter/material.dart';

class PremiumStar extends StatelessWidget {
  const PremiumStar({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Icon(Icons.star_rounded, color: const Color.fromARGB(255, 255, 206, 44), size: size),
    );
  }
}
