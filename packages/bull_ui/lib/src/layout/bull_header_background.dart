import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// The patterned backdrop of a balance header: the middle of [image] from
/// its bottom edge, darkened, under a black fade from the top.
class BullHeaderBackground extends StatelessWidget {
  const BullHeaderBackground(this.image, {super.key});

  final ImageProvider image;

  @override
  Widget build(BuildContext context) {
    final shade = context.appColors.homeHeaderBackground;
    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          alignment: Alignment.bottomCenter,
          child: ClipRect(
            child: Align(
              alignment: Alignment.bottomCenter,
              widthFactor: 0.8,
              child: Image(image: image),
            ),
          ),
        ),
        ColoredBox(color: shade.withValues(alpha: 0.3)),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [shade, shade.withValues(alpha: 0)],
              stops: const [0, 0.7],
            ),
          ),
        ),
      ],
    );
  }
}
