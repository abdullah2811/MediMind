import 'package:flutter/material.dart';

class MediMindLogo extends StatelessWidget {
  const MediMindLogo({super.key, required this.size, this.borderRadius = 8});

  static const assetPath = 'assets/images/medimind_logo.png';

  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'MediMind logo',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.asset(
          assetPath,
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}
