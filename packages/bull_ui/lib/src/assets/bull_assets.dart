import 'package:flutter/widgets.dart';

/// Typed asset providers owned by the Bull UI package.
abstract final class BullAssets {
  static const animations = BullAnimationAssets._();
}

final class BullAnimationAssets {
  const BullAnimationAssets._();

  final AssetImage cubesLoading = const AssetImage(
    'assets/animations/cubes_loading.gif',
    package: 'bull_ui',
  );
  final AssetImage successTick = const AssetImage(
    'assets/animations/success_tick.gif',
    package: 'bull_ui',
  );
}
