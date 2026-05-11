import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';

/// Red + `bgLong` pattern painted behind the whole `Scaffold` body on
/// the welcome page so the splash visual extends under the dots and
/// Next button strip. Mirrors `OnboardingSplash._BG`.
class WelcomeBgPattern extends StatelessWidget {
  const WelcomeBgPattern({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(color: context.appColors.primaryFixed),
        ),
        Positioned.fill(
          child: Opacity(
            opacity: 0.2,
            child: Transform.rotate(
              angle: 3.141,
              child: Image.asset(
                Assets.backgrounds.bgLong.path,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
