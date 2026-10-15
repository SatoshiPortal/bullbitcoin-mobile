import 'package:bull_ui/src/feedback/bull_shimmer.dart';
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

  const BullAsyncStatus.progress({
    super.key,
    required String label,
    required Color color,
    required this.textStyle,
  }) : state = BullAsyncStatusState.inProgress,
       inProgressLabel = label,
       succeededLabel = '',
       fallbackLabel = '',
       inProgressColor = color,
       successColor = color;

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
      BullAsyncStatusState.inProgress => Semantics(
        liveRegion: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              inProgressLabel,
              textAlign: TextAlign.center,
              style: textStyle?.copyWith(color: inProgressColor),
            ),
            if (!MediaQuery.disableAnimationsOf(context)) ...[
              const SizedBox(height: 8),
              const ExcludeSemantics(
                child: BullShimmerLine(
                  width: 160,
                  height: 4,
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ],
        ),
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
