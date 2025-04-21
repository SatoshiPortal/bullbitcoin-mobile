import 'dart:ui';

import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';

class BlurredBottomSheet extends StatelessWidget {
  const BlurredBottomSheet({super.key, required this.child});

  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Align(
            alignment: Alignment.topCenter,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(
                color: context.colour.secondary.withAlpha(25),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: child,
        ),
      ],
    );
  }
}
