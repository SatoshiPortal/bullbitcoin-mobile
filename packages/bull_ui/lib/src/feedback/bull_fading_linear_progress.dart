import 'package:flutter/material.dart';

/// A thin [LinearProgressIndicator] that fades in/out on [trigger] —
/// duplicated from `core/widgets/loading/fading_linear_progress.dart`.
class BullFadingLinearProgress extends StatefulWidget {
  const BullFadingLinearProgress({
    super.key,
    required this.trigger,
    this.height = 1.5,
    this.backgroundColor,
    this.foregroundColor,
    this.duration = const Duration(milliseconds: 1000),
  });

  /// When true the bar is shown; when false it fades out.
  final bool trigger;

  /// Bar thickness.
  final double height;

  /// Track colour (defaults to the ambient theme).
  final Color? backgroundColor;

  /// Progress colour (defaults to the ambient theme).
  final Color? foregroundColor;

  /// Fade animation duration.
  final Duration duration;

  @override
  State<BullFadingLinearProgress> createState() =>
      _BullFadingLinearProgressState();
}

class _BullFadingLinearProgressState extends State<BullFadingLinearProgress> {
  bool isVisible = false;

  @override
  void initState() {
    super.initState();
    isVisible = widget.trigger;
  }

  @override
  void didUpdateWidget(BullFadingLinearProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger) {
      setState(() {
        isVisible = widget.trigger;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: AnimatedOpacity(
        opacity: isVisible ? 1.0 : 0.0,
        duration: widget.duration,
        child: LinearProgressIndicator(
          backgroundColor: widget.backgroundColor,
          color: widget.foregroundColor,
        ),
      ),
    );
  }
}
