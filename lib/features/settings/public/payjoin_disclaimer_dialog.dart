import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';

/// Passive Payjoin privacy disclosure shared by settings and receive.
abstract final class PayjoinDisclaimerDialog {
  static Future<void> show(BuildContext context) {
    return BullDialog.show<void>(
      context: context,
      builder: (dialogContext) => _PayjoinDisclaimerBody(dialogContext),
    );
  }
}

class _PayjoinDisclaimerBody extends StatelessWidget {
  const _PayjoinDisclaimerBody(this.dialogContext);

  final BuildContext dialogContext;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.loc.settingsPayjoinDisclaimerTitle,
          style: textTheme.titleMedium?.copyWith(color: colors.text),
        ),
        const Gap(8),
        Text(
          context.loc.settingsPayjoinPrivacyGainExplanation,
          style: textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
        const Gap(12),
        Text(
          context.loc.settingsPayjoinV1DirectoryLeakExplanation,
          style: textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
        const Gap(20),
        BullButton.small(
          label: context.loc.okButton,
          onPressed: () => Navigator.of(dialogContext).pop(),
          bgColor: colors.primary,
          textColor: colors.onPrimary,
        ),
      ],
    );
  }
}
