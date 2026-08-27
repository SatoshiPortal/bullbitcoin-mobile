import 'package:flutter/material.dart';

class FadingLinearProgress extends StatefulWidget {
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
  State<FadingLinearProgress> createState() => _FadingLinearProgressState();
}

class _FadingLinearProgressState extends State<FadingLinearProgress> {
  late bool _tickerEnabled;

  @override
  void initState() {
    super.initState();
    _tickerEnabled = widget.trigger;
  }

  @override
  void didUpdateWidget(FadingLinearProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger && !oldWidget.trigger) {
      setState(() => _tickerEnabled = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: AnimatedOpacity(
        opacity: widget.trigger ? 1.0 : 0.0,
        duration: widget.duration,
        onEnd: () {
          if (!widget.trigger && _tickerEnabled) {
            setState(() => _tickerEnabled = false);
          }
        },
        child: TickerMode(
          enabled: _tickerEnabled,
          child: LinearProgressIndicator(
            backgroundColor: widget.backgroundColor,
            color: widget.foregroundColor,
          ),
        ),
      ),
    );
  }
}
