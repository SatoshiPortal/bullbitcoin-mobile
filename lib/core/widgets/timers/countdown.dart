import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:flutter/material.dart';

class Countdown extends StatefulWidget {
  final DateTime until;
  final VoidCallback onTimeout;
  final TextStyle? textStyle;

  const Countdown({
    super.key,
    required this.until,
    required this.onTimeout,
    this.textStyle,
  });

  @override
  _CountdownState createState() => _CountdownState();
}

class _CountdownState extends State<Countdown> {
  late Duration remainingTime;
  late Timer? timer;

  @override
  void initState() {
    super.initState();
    remainingTime = _calculateRemainingTime();
    if (remainingTime.isNegative) {
      remainingTime = Duration.zero;
      // If the deadline has already passed, we directly call the timeout callback
      // and do not start the timer.
      widget.onTimeout();
      return;
    }
    timer = Timer.periodic(const Duration(seconds: 1), _updateTimer);
  }

  @override
  void didUpdateWidget(Countdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.until != widget.until) {
      // Cancel the old timer
      timer?.cancel();

      // Recalculate remaining time with new deadline
      remainingTime = _calculateRemainingTime();

      if (remainingTime.isNegative) {
        remainingTime = Duration.zero;
        widget.onTimeout();
        return;
      }

      // Start a new timer
      timer = Timer.periodic(const Duration(seconds: 1), _updateTimer);
    }
  }

  Duration _calculateRemainingTime() {
    // Calculate the remaining time always from the deadline time and the current time
    // to ensure it updates correctly instead of just subtracting a second each time which
    // could lead to inaccuracies when the app is paused or resumed or other asynchronous events occur.
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
    return Text(
      '${remainingTime.inMinutes}:${(remainingTime.inSeconds % 60).toString().padLeft(2, '0')}',
      style:
          widget.textStyle ??
          context.font.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: context.colour.primary,
          ),
    );
  }
}
