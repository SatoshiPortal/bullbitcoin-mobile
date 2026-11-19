import 'package:bull_ui/src/buttons/bull_button.dart';
import 'package:bull_ui/src/data_display/bull_text.dart';
import 'package:bull_ui/src/layout/gap.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_typography.dart';
import 'package:material_ui/material_ui.dart';

/// A load failure with a way to try again: the error [message] above a retry
/// button. Promoted from the app's `BBErrorRetry`.
///
/// The kit has no localisation, so [message] and [retryLabel] come translated
/// from the caller. A null [onRetry] disables the button, e.g. while a retry is
/// already running.
class BullErrorState extends StatelessWidget {
  const BullErrorState({
    super.key,
    required this.message,
    required this.onRetry,
    required this.retryLabel,
  });

  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BullText(
          message,
          textAlign: TextAlign.center,
          role: BullTextRole.body,
          color: colors.error,
        ),
        const Gap(8),
        BullButton.secondary(
          size: BullButtonSize.small,
          label: retryLabel,
          compact: true,
          onPressed: (onRetry == null) ? null : () => onRetry?.call(),
        ),
      ],
    );
  }
}
