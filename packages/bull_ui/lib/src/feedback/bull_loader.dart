import 'dart:math' as math;

import 'package:bull_ui/src/theme/bull_icon.dart';
import 'package:bull_ui/src/theme/bull_loader_theme.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:gif/gif.dart';
import 'package:material_ui/material_ui.dart';

/// Decorative loading animation in the style the theme picks; the surrounding
/// screen supplies its label. With reduced motion it shows a still clock
/// instead.
class BullLoader extends StatelessWidget {
  /// Side of the square the loader fills.
  final double size;

  /// Centred on a progress screen.
  const BullLoader.large({super.key}) : size = largeSize;

  /// Inline: a list tile, an app bar.
  const BullLoader.small({super.key}) : size = smallSize;

  static const double largeSize = 128;
  static const double smallSize = 40;

  /// The spinner and the clock never grow past this, however large the box.
  static const double maxIndicatorSize = 64;

  @override
  Widget build(BuildContext context) {
    final style = context.bullLoader.style;
    final indicator = math.min(size, maxIndicatorSize);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: MediaQuery.disableAnimationsOf(context)
              ? Icon(
                  BullIcons.schedule,
                  size: indicator * 2 / 3,
                  color: context.bull.secondary,
                )
              : switch (style) {
                  BullLoaderStyle.cubes => Gif(
                    image: const AssetImage(
                      'assets/cubes_loading.gif',
                      package: 'bull_ui',
                    ),
                    autostart: Autostart.loop,
                    width: size,
                    height: size,
                    fit: BoxFit.contain,
                  ),
                  BullLoaderStyle.spinner => SizedBox.square(
                    dimension: indicator,
                    child: CircularProgressIndicator(
                      color: context.bull.primary,
                      strokeWidth: indicator / 12,
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                },
        ),
      ),
    );
  }
}
