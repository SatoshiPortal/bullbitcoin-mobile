import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bull_ui/bull_ui.dart';

/// Passive Payjoin privacy disclosure shared by settings and receive.
abstract final class PayjoinDisclaimerDialog {
  static Future<bool> show(BuildContext context) async {
    final accepted = await BullDialog.show<bool>(
      context: context,
      isDismissible: false,
      builder: (dialogContext) =>
          PopScope(canPop: false, child: _PayjoinDisclaimerBody(dialogContext)),
    );
    return accepted ?? false;
  }
}

class _PayjoinDisclaimerBody extends StatelessWidget {
  const _PayjoinDisclaimerBody(this.dialogContext);

  final BuildContext dialogContext;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final textTheme = context.bullType;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.loc.settingsPayjoinDisclaimerTitle,
          style: textTheme.body
              .copyWith(fontWeight: FontWeight.w500)
              .copyWith(color: colors.text),
        ),
        const Gap(8),
        Text(
          context.loc.settingsPayjoinPrivacyGainExplanation,
          style: textTheme.body.copyWith(color: colors.onSurfaceVariant),
        ),
        const Gap(12),
        Text(
          context.loc.settingsPayjoinV1DirectoryLeakExplanation,
          style: textTheme.body.copyWith(color: colors.onSurfaceVariant),
        ),
        const Gap(20),
        BullButton.primary(
          size: BullButtonSize.small,
          label: context.loc.okButton,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    );
  }
}
