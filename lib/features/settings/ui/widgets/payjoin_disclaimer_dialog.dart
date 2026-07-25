import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/settings/data/payjoin_disclaimer_datasource.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';

/// The payjoin disclaimer pop-up (product decision 2026-07-25): shown ONCE,
/// automatically, the first time the user turns payjoin on — from either the
/// settings screen or the receive-screen toggle — and afterwards only on
/// demand via the "Payjoin disclaimer" row on the payjoin settings screen.
abstract final class PayjoinDisclaimerDialog {
  /// Shows the disclaimer unconditionally (the settings-row entry point).
  static Future<void> show(BuildContext context) {
    return BullDialog.show<void>(
      context: context,
      builder: (dialogContext) => _PayjoinDisclaimerBody(dialogContext),
    );
  }

  /// Shows the disclaimer only if it has never been shown before, and marks
  /// it shown. Call after the user turns payjoin ON.
  static Future<void> showIfNeverShown(BuildContext context) async {
    final datasource = locator<PayjoinDisclaimerDatasource>();
    if (await datasource.readDisclaimerShown()) return;
    await datasource.writeDisclaimerShown();
    if (!context.mounted) return;
    await show(context);
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
