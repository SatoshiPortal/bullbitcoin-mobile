import 'dart:async';

import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:flutter/material.dart';

/// A `m:ss` countdown to a [DateTime], stopping at `0:00`.
///
/// Display only: it reports nothing when the deadline passes. Whatever must
/// happen at the deadline belongs to the state that owns it, not to a widget
/// that can fire early, late, or again on every remount.
///
/// Remaining time is recomputed against the wall clock each tick (not by
/// subtracting a second), so it stays accurate across app pause/resume.
class BullCountdown extends StatefulWidget {
  const BullCountdown({super.key, required this.until, this.textStyle});

  /// The UTC deadline to count down to.
  final DateTime until;

  /// Optional style override; defaults to the brand-red emphasis label.
  final TextStyle? textStyle;

  @override
  BullCountdownState createState() => BullCountdownState();
}

/// State for [BullCountdown]; public to mirror the original's API.
class BullCountdownState extends State<BullCountdown> {
  late Duration remainingTime;
  // Null once the deadline is reached: there is nothing left to tick.
  Timer? timer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(BullCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.until != widget.until) _start();
  }

  void _start() {
    timer?.cancel();
    timer = null;
    remainingTime = _calculateRemainingTime();
    if (remainingTime > Duration.zero) {
      timer = Timer.periodic(const Duration(seconds: 1), _updateTimer);
    }
  }

  Duration _calculateRemainingTime() {
    final remaining = widget.until.difference(DateTime.now().toUtc());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  void _updateTimer(Timer timer) {
    setState(() {
      remainingTime = _calculateRemainingTime();
    });
    if (remainingTime == Duration.zero) {
      timer.cancel();
      this.timer = null;
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return Text(
      '${remainingTime.inMinutes}:'
      '${(remainingTime.inSeconds % 60).toString().padLeft(2, '0')}',
      style:
          widget.textStyle ??
          Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: colors.primary,
          ),
    );
  }
}
