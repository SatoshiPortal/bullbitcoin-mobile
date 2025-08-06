import 'dart:async';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';

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

  void _showSnackBar(BuildContext context, String message) {
    final theme = Theme.of(context);
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: BBText(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: widget.tapsReachedMessageTextColor ?? Colors.white,
          ),
        ),
        duration: const Duration(seconds: 2),
        backgroundColor:
            widget.tapsReachedMessageBackgroundColor?.withAlpha(204) ??
            theme.colorScheme.onSurface.withAlpha(204),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
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
      behavior: HitTestBehavior.opaque,
      child: widget.child,
    );
  }
}
