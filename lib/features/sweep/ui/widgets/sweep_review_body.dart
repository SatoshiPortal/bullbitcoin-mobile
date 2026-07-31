import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/tx_recipient.dart';
import 'package:bb_mobile/features/sweep/domain/sweep_quote.dart';
import 'package:bb_mobile/features/sweep/ui/sweep_amount_format.dart';
import 'package:bull_ui/bull_ui.dart';

/// What the user is about to sign: every output, the real fee read off the PSBT,
/// and where the leftover goes.
class SweepReviewBody extends StatelessWidget {
  const SweepReviewBody({
    super.key,
    required this.quote,
    required this.bitcoinUnit,
    required this.hideAmounts,
    required this.feeRow,
  });

  final SweepQuote quote;
  final BitcoinUnit bitcoinUnit;
  final bool hideAmounts;

  /// The tappable fee row, injected by the screen so this widget stays free of
  /// any cubit reference.
  final Widget feeRow;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final colors = context.bull;
    final plan = quote.plan;
    final change = quote.changeSat;
    final remainder = quote.remainderSat;

    return BullScrollableColumn(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(
          loc.sweepReviewSpending(plan.inputs.length),
          style: context.bullText.labelMedium?.copyWith(
            color: colors.textMuted,
          ),
        ),
        const Gap(4),
        Text(
          formatSweepAmount(
            plan.totalInputSat,
            bitcoinUnit,
            hidden: hideAmounts,
          ),
          style: context.bullText.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: colors.text,
          ),
        ),
        const Gap(20),
        Text(
          loc.sweepReviewRecipients,
          style: context.bullText.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: colors.text,
          ),
        ),
        const Gap(8),
        for (final recipient in plan.recipients)
          _OutputRow(
            address: recipient.address,
            amountLabel: switch (recipient) {
              FixedTxRecipient(:final amountSat) => formatSweepAmount(
                amountSat,
                bitcoinUnit,
                hidden: hideAmounts,
              ),
              DrainTxRecipient() => formatSweepAmount(
                remainder ?? BigInt.zero,
                bitcoinUnit,
                hidden: hideAmounts,
              ),
            },
            note: recipient is DrainTxRecipient
                ? loc.sweepReviewRemainderNote
                : null,
          ),
        const Gap(12),
        feeRow,
        const Gap(12),
        BullDetailsTable(
          items: [
            if (change != null && change > BigInt.zero)
              BullDetailsTableItem(
                label: loc.sweepReviewChange,
                displayValue: formatSweepAmount(
                  change,
                  bitcoinUnit,
                  hidden: hideAmounts,
                ),
                copiedMessage: loc.addressCardCopiedMessage,
              ),
          ],
        ),
        if (quote.changeAbsorbedIntoFee) ...[
          const Gap(12),
          BullInfoBar(
            message: loc.sweepReviewDustAbsorbed,
            tone: BullInfoTone.warning,
          ),
        ],
        const Gap(12),
        BullInfoBar(message: loc.sweepReviewInputsPinned),
      ],
    );
  }
}

class _OutputRow extends StatelessWidget {
  const _OutputRow({
    required this.address,
    required this.amountLabel,
    this.note,
  });

  final String address;
  final String amountLabel;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(BullRadius.xs),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: BullAddressText(address: address)),
              const Gap(12),
              Text(
                amountLabel,
                style: context.bullText.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
            ],
          ),
          if (note != null) ...[
            const Gap(4),
            Text(
              note!,
              style: context.bullText.bodySmall?.copyWith(
                color: colors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
