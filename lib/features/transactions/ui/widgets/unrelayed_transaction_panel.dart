import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_failure.dart';
import 'package:bb_mobile/features/transactions/presentation/transaction_failure_l10n.dart';
import 'package:bull_ui/bull_ui.dart';

class UnrelayedTransactionPanel extends StatefulWidget {
  final bool busy;
  final TransactionFailure? failure;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  const UnrelayedTransactionPanel({
    super.key,
    required this.onRetry,
    required this.onCancel,
    this.busy = false,
    this.failure,
  });

  @override
  State<UnrelayedTransactionPanel> createState() =>
      _UnrelayedTransactionPanelState();
}

class _UnrelayedTransactionPanelState extends State<UnrelayedTransactionPanel> {
  bool _confirming = false;

  Future<void> _confirmCancel() async {
    if (widget.busy || _confirming) {
      return;
    }
    setState(() => _confirming = true);
    final accepted = await BullDialog.show<bool>(
      context: context,
      builder: (dialogContext) {
        final colors = dialogContext.bull;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BullText(
              dialogContext.loc.transactionCancelUnbroadcastTitle,
              style: dialogContext.bullText.titleMedium,
            ),
            const Gap(16),
            BullText(
              dialogContext.loc.transactionCancelUnbroadcastDescription,
              style: dialogContext.bullText.bodyMedium,
            ),
            const Gap(24),
            BullButton.big(
              label: dialogContext.loc.cancel,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              bgColor: colors.primary,
              textColor: colors.onPrimary,
            ),
            const Gap(12),
            BullButton.big(
              label: dialogContext.loc.transactionKeepTransaction,
              onPressed: () => Navigator.of(dialogContext).pop(false),
              bgColor: colors.transparent,
              textColor: colors.text,
              outlined: true,
              borderColor: colors.outlineVariant,
            ),
          ],
        );
      },
    );
    if (!mounted) {
      return;
    }
    setState(() => _confirming = false);
    if (accepted == true && !widget.busy) {
      widget.onCancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final disabled = widget.busy || _confirming;
    final failure = widget.failure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BullInfoBar(
          message: context.loc.transactionNotBroadcastDescription,
          tone: BullInfoTone.warning,
        ),
        const Gap(16),
        BullButton.big(
          label: context.loc.retry,
          disabled: disabled,
          onPressed: widget.onRetry,
          bgColor: colors.primary,
          textColor: colors.onPrimary,
        ),
        const Gap(12),
        BullButton.big(
          label: context.loc.cancel,
          disabled: disabled,
          onPressed: _confirmCancel,
          bgColor: colors.transparent,
          textColor: colors.text,
          outlined: true,
          borderColor: colors.outlineVariant,
        ),
        if (failure != null) ...[
          const Gap(16),
          BullInfoBar(
            message: failure.toTranslated(context),
            tone: BullInfoTone.warning,
          ),
        ],
      ],
    );
  }
}
