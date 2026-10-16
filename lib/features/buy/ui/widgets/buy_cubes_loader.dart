import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart' show Assets;
import 'package:flutter/material.dart';
import 'package:gif/gif.dart' show Autostart, Gif;

/// Decorative feedback; the surrounding tile or button supplies its label.
class BuyCubesLoader extends StatelessWidget {
  final double size;

  const BuyCubesLoader({super.key, this.size = 36});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: MediaQuery.disableAnimationsOf(context)
            ? Icon(Icons.schedule, color: context.appColors.secondary)
            : Gif(
                image: AssetImage(Assets.animations.cubesLoading.path),
                autostart: Autostart.loop,
                width: size,
                height: size,
                fit: BoxFit.contain,
              ),
      ),
    );
  }
}
