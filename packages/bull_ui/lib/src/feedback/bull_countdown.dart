import 'dart:async';

import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:flutter/material.dart';

/// A `m:ss` countdown to a [DateTime] that fires [onTimeout] when it elapses —
/// duplicated from `core/widgets/timers/countdown.dart`.
///
/// Remaining time is recomputed against the wall clock each tick (not by
/// subtracting a second), so it stays accurate across app pause/resume.
class BullCountdown extends StatefulWidget {
  const BullCountdown({
    super.key,
    required this.until,
    required this.onTimeout,
    this.textStyle,
  });

  /// The UTC deadline to count down to.
  final DateTime until;

  /// Called once when the deadline is reached (or already passed on mount).
  final VoidCallback onTimeout;

  /// Optional style override; defaults to the brand-red emphasis label.
  final TextStyle? textStyle;

  @override
  BullCountdownState createState() => BullCountdownState();
}

/// State for [BullCountdown]; public to mirror the original's API.
class BullCountdownState extends State<BullCountdown> {
  late Duration remainingTime;
  // Nullable (not `late`) so an early return on an already-passed deadline
  // still leaves a safe value for `dispose()` to cancel.
  Timer? timer;

  @override
  void initState() {
    super.initState();
    remainingTime = _calculateRemainingTime();
    if (remainingTime.isNegative) {
      remainingTime = Duration.zero;
      // Deadline already passed: fire the callback and skip the timer.
      widget.onTimeout();
      return;
    }
    timer = Timer.periodic(const Duration(seconds: 1), _updateTimer);
  }

  @override
  void didUpdateWidget(BullCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.until != widget.until) {
      timer?.cancel();
      remainingTime = _calculateRemainingTime();

      if (remainingTime.isNegative) {
        remainingTime = Duration.zero;
        widget.onTimeout();
        return;
      }

      timer = Timer.periodic(const Duration(seconds: 1), _updateTimer);
    }
  }

  Duration _calculateRemainingTime() {
    return widget.until.difference(DateTime.now().toUtc());
  }

  void _updateTimer(Timer timer) {
    if (remainingTime.inSeconds <= 0) {
      widget.onTimeout();
      timer.cancel();
      return;
    }

    setState(() {
      remainingTime = _calculateRemainingTime();
    });
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
          Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: colors.primary,
          ),
    );
  }
}
