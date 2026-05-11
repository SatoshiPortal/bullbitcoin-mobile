import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:flutter/widgets.dart';

class StackedPage extends StatelessWidget {
  const StackedPage({
    super.key,
    required this.child,
    required this.bottomChild,
  });

  final Widget child;
  final Widget bottomChild;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.only(
              bottom: 32,
              top: 8,
              left: 16,
              right: 16,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  context.appColors.onSecondary.withValues(alpha: 0.0),
                  context.appColors.onSecondary,
                ],
                stops: const [0.0, 0.3],
              ),
            ),
            child: bottomChild,
          ),
        ),
      ],
    );
  }
}
