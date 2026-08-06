import 'package:flutter/material.dart';

enum BullAsyncStatusState { hidden, inProgress, succeeded, fallback }

/// A compact status line for an asynchronous operation.
///
/// The caller owns the business-state mapping and supplies all copy and colours.
class BullAsyncStatus extends StatelessWidget {
  const BullAsyncStatus({
    super.key,
    required this.state,
    required this.inProgressLabel,
    required this.succeededLabel,
    required this.fallbackLabel,
    required this.inProgressColor,
    required this.successColor,
    required this.textStyle,
  });

  final BullAsyncStatusState state;
  final String inProgressLabel;
  final String succeededLabel;
  final String fallbackLabel;
  final Color inProgressColor;
  final Color successColor;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      BullAsyncStatusState.hidden => const SizedBox.shrink(),
      BullAsyncStatusState.inProgress => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: inProgressColor,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            inProgressLabel,
            style: textStyle?.copyWith(color: inProgressColor),
          ),
        ],
      ),
      BullAsyncStatusState.succeeded => Text(
        succeededLabel,
        textAlign: TextAlign.center,
        style: textStyle?.copyWith(color: successColor),
      ),
      BullAsyncStatusState.fallback => Text(
        fallbackLabel,
        textAlign: TextAlign.center,
        style: textStyle,
      ),
    };
  }
}
