import '../../../generated/l10n/settings_localizations.dart';
import '../domain/wallet_details_failure.dart';
import '../presentation/wallet_details_failure_l10n.dart';

import 'package:bull_ui/bull_ui.dart';

/// Wallet-deletion failure sheet, built on [BullBottomSheet] to match
/// [WalletDeletionConfirmationSheet].
class WalletDeletionFailedSheet extends StatelessWidget {
  const WalletDeletionFailedSheet({super.key, required this.failure});

  final WalletDetailsFailure failure;

  /// Present the sheet via [BullBottomSheet].
  static Future<void> show(
    BuildContext context, {
    required WalletDetailsFailure failure,
  }) {
    return BullBottomSheet.show<void>(
      context: context,
      child: WalletDeletionFailedSheet(failure: failure),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final loc = SettingsLocalizations.of(context);
    final text = context.bullType;
    final message = failure.toTranslated(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(context.bullShapes.dot),
              ),
            ),
            const Gap(24),
            BullIcon(BullIcons.errorOutline, size: 36, color: colors.error),
            const Gap(16),
            Text(
              loc.walletDeletionFailedTitle,
              style: text.subtitle
                  .copyWith(fontWeight: FontWeight.w400)
                  .copyWith(fontWeight: FontWeight.bold, color: colors.text),
              textAlign: TextAlign.center,
            ),
            const Gap(8),
            Text(
              message,
              style: text.body.copyWith(color: colors.text),
              textAlign: TextAlign.center,
            ),
            const Gap(24),
            BullButton.primary(
              label: loc.walletDeletionFailedOkButton,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
