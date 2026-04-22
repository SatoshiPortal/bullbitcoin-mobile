import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class WizardPage extends StatelessWidget {
  const WizardPage({super.key, required this.image, required this.child});

  final String image;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SvgPicture.asset(
            image,
            height: 180,
            fit: BoxFit.contain,
            placeholderBuilder: (_) => const SizedBox(height: 180),
          ),
          const SizedBox(height: 32),
          child,
        ],
      ),
    );
  }
}
