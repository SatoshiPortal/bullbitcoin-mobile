import 'dart:async';
import 'package:flutter/material.dart';
import 'package:bull_ui/bull_ui.dart' show BullSnackBar;

class MultiTapTrigger extends StatefulWidget {
  final int requiredTaps;
  final VoidCallback onRequiredTaps;
  final Duration maxTimeBetweenTaps;
  final Widget child;
  final String? tapsReachedMessage;
  final Color? tapsReachedMessageBackgroundColor;
  final Color? tapsReachedMessageTextColor;

  const MultiTapTrigger({
    super.key,
    this.requiredTaps = 7,
    required this.onRequiredTaps,
    this.maxTimeBetweenTaps = const Duration(seconds: 2),
    this.tapsReachedMessage,
    this.tapsReachedMessageBackgroundColor,
    this.tapsReachedMessageTextColor,
    required this.child,
  });

  @override
  State<MultiTapTrigger> createState() => _MultiTapTriggerState();
}

class _MultiTapTriggerState extends State<MultiTapTrigger> {
  int _tapCount = 0;
  Timer? _resetTimer;

  void _onTap() {
    _resetTimer?.cancel();
    _resetTimer = Timer(widget.maxTimeBetweenTaps, () {
      setState(() {
        _tapCount = 0;
      });
    });

    setState(() {
      _tapCount++;
    });

    if (_tapCount >= widget.requiredTaps) {
      _resetTimer?.cancel();
      widget.onRequiredTaps();
      if (widget.tapsReachedMessage != null) {
        _showSnackBar(context, widget.tapsReachedMessage!);
      }
      setState(() {
        _tapCount = 0;
      });
    }
  }

  // A plain message, so the toast's own theme colours apply to the text.
  void _showSnackBar(BuildContext context, String message) {
    BullSnackBar.show(context, message: message);
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      behavior: .opaque,
      child: widget.child,
    );
  }
}
