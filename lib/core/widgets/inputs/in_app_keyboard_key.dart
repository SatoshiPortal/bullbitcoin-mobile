import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:flutter/material.dart';

class InAppKeyboardKey extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final bool suppressAnimation;

  const InAppKeyboardKey({
    super.key,
    required this.child,
    required this.onPressed,
    this.suppressAnimation = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        animationDuration: Duration.zero,
        color: enabled
            ? context.appColors.surface
            : context.appColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          canRequestFocus: false,
          borderRadius: BorderRadius.circular(6),
          splashFactory: suppressAnimation ? NoSplash.splashFactory : null,
          highlightColor: suppressAnimation ? Colors.transparent : null,
          onTap: onPressed,
          child: SizedBox(height: 44, child: Center(child: child)),
        ),
      ),
    );
  }
}
