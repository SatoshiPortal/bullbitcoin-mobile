import 'package:bull_ui/app_theme.dart';
import 'package:material_ui/material_ui.dart';

/// Red + `bgLong` pattern painted behind the whole `Scaffold` body on
/// the welcome page so the splash visual extends under the dots and
/// Next button strip. Mirrors `OnboardingSplash._BG`.
class WelcomeBgPattern extends StatelessWidget {
  const WelcomeBgPattern({required this.pattern, super.key});

  final ImageProvider pattern;

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
              child: Image(image: pattern, fit: BoxFit.cover),
            ),
          ),
        ),
      ],
    );
  }
}
