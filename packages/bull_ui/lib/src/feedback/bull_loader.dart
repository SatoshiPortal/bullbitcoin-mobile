import 'dart:math' as math;

import 'package:bull_ui/src/theme/bull_icon.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:gif/gif.dart';
import 'package:material_ui/material_ui.dart';

/// Bull's looping cubes; the surrounding screen supplies its label. With
/// reduced motion it shows a still clock instead.
class BullLoader extends StatelessWidget {
  /// Side of the square the loader fills.
  final double size;

  /// Centred on a progress screen.
  const BullLoader.large({super.key}) : size = largeSize;

  /// Inline: a list tile, an app bar.
  const BullLoader.small({super.key}) : size = smallSize;

  static const double largeSize = 128;
  static const double smallSize = 40;

  /// The still clock never grows past this, however large the box.
  static const double maxClockSize = 64;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: MediaQuery.disableAnimationsOf(context)
              ? Icon(
                  BullIcons.schedule,
                  size: math.min(size, maxClockSize) * 2 / 3,
                  color: context.bull.secondary,
                )
              : Gif(
                  image: const AssetImage(
                    'assets/cubes_loading.gif',
                    package: 'bull_ui',
                  ),
                  autostart: Autostart.loop,
                  width: size,
                  height: size,
                  fit: BoxFit.contain,
                ),
        ),
      ),
    );
  }
}
