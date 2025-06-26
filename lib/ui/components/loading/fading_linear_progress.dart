import 'package:flutter/material.dart';

class FadingLinearProgress extends StatelessWidget {
  const FadingLinearProgress({
    super.key,
    required this.trigger,
    this.height = 1.5,
    this.backgroundColor,
    this.foregroundColor,
    this.duration = const Duration(milliseconds: 1000),
  });

  final bool trigger;
  final double height;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: AnimatedOpacity(
        opacity: trigger ? 1.0 : 0.0,
        duration: duration,
        child: LinearProgressIndicator(
          backgroundColor: backgroundColor,
          color: foregroundColor,
        ),
      ),
    );
  }
}
