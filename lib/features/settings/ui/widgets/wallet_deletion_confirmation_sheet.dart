import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bull_ui/bull_ui.dart';

/// Delete-wallet confirmation sheet, built on [BullBottomSheet] so it matches
/// the app's other destructive prompts.
class WalletDeletionConfirmationSheet extends StatelessWidget {
  const WalletDeletionConfirmationSheet({super.key, required this.onConfirm});

  final VoidCallback onConfirm;

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onConfirm,
  }) {
    return BullBottomSheet.show<void>(
      context: context,
      child: WalletDeletionConfirmationSheet(onConfirm: onConfirm),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final loc = context.loc;
    final text = context.bullType;

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
            BullIcon(BullIcons.deleteOutline, size: 36, color: colors.error),
            const Gap(16),
            Text(
              loc.walletDeletionConfirmationTitle,
              style: text.subtitle
                  .copyWith(fontWeight: FontWeight.w400)
                  .copyWith(fontWeight: FontWeight.bold, color: colors.text),
              textAlign: TextAlign.center,
            ),
            const Gap(8),
            Text(
              loc.walletDeletionConfirmationMessage,
              style: text.body.copyWith(color: colors.text),
              textAlign: TextAlign.center,
            ),
            const Gap(24),
            BullButton.primary(
              label: loc.walletDeletionConfirmationDeleteButton,
              onPressed: () {
                Navigator.of(context).pop();
                onConfirm();
              },
            ),
            const Gap(12),
            BullButton.secondary(
              label: loc.walletDeletionConfirmationCancelButton,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
