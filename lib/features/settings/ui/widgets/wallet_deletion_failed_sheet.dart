import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';
import 'package:bull_ui/bull_ui.dart';

/// Wallet-deletion failure sheet, built on [BullBottomSheet] to match
/// [WalletDeletionConfirmationSheet].
class WalletDeletionFailedSheet extends StatelessWidget {
  const WalletDeletionFailedSheet({super.key, required this.error});

  final WalletError error;

  /// Present the sheet via [BullBottomSheet].
  static Future<void> show(BuildContext context, {required WalletError error}) {
    return BullBottomSheet.show<void>(
      context: context,
      child: WalletDeletionFailedSheet(error: error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final loc = context.loc;
    final text = context.bullText;
    final message = switch (error) {
      CannotDeleteDefaultWalletError() => loc.walletDeletionErrorDefaultWallet,
      CannotDeleteWalletWithOngoingSwapsError() =>
        loc.walletDeletionErrorOngoingSwaps,
      WalletNotFound() => loc.walletDeletionErrorWalletNotFound,
      _ => loc.walletDeletionErrorGeneric,
    };

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
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Gap(24),
            BullIcon(BullIcons.errorOutline, size: 36, color: colors.error),
            const Gap(16),
            Text(
              loc.walletDeletionFailedTitle,
              style: text.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.text,
              ),
              textAlign: TextAlign.center,
            ),
            const Gap(8),
            Text(
              message,
              style: text.bodyMedium?.copyWith(color: colors.text),
              textAlign: TextAlign.center,
            ),
            const Gap(24),
            BullButton.big(
              label: loc.walletDeletionFailedOkButton,
              onPressed: () => Navigator.of(context).pop(),
              bgColor: colors.error,
              textColor: colors.onError,
            ),
          ],
        ),
      ),
    );
  }
}
