import 'package:bb_mobile/features/settings/ui/widgets/superuser_tap_unlocker.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:gif/gif.dart';

class TopBarBullLogo extends StatelessWidget {
  const TopBarBullLogo({
    super.key,
    this.playAnimation = false,
    this.onTap,
    this.enableSuperuserTapUnlocker = false,
  });

  final bool playAnimation;
  final VoidCallback? onTap;
  final bool enableSuperuserTapUnlocker;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return enableSuperuserTapUnlocker
        ? SuperuserTapUnlocker(
          tapsReachedMessageBackgroundColor: theme.colorScheme.primary,
          child: _BullLogo(onTap: onTap, playAnimation: playAnimation),
        )
        : _BullLogo(onTap: onTap, playAnimation: playAnimation);
  }
}

class _BullLogo extends StatelessWidget {
  const _BullLogo({this.onTap, this.playAnimation = false});

  final VoidCallback? onTap;
  final bool playAnimation;

  @override
  Widget build(BuildContext context) {
    if (!playAnimation) {
      return InkWell(
        onTap: onTap,
        child: Image.asset(
          Assets.logos.bbLogoSmall.path,
          width: 40,
          height: 40,
        ),
      ); //.animate(delay: 300.ms).fadeIn();
    }

    return Gif(
      image: AssetImage(Assets.animations.bbSync.path),
      autostart: Autostart.loop,
      height: 32,
      width: 32,
    );
  }
}
