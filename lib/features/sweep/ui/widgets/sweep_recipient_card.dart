import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/sweep/domain/sweep_plan.dart';
import 'package:bull_ui/bull_ui.dart';

/// One row of the allocation form: where the money goes and how much.
///
/// The amount field keeps its own [TextEditingController] because it is a form
/// field, not business state — the cubit only ever hears about the parsed
/// satoshi value. It re-syncs from [allocation] when something other than
/// typing changes the amount (a BIP21 paste, or the Max toggle clearing it).
class SweepRecipientCard extends StatefulWidget {
  const SweepRecipientCard({
    super.key,
    required this.index,
    required this.allocation,
    required this.bitcoinUnit,
    required this.remainderSat,
    required this.canRemove,
    required this.onAddressChanged,
    required this.onAmountChanged,
    required this.onTakeRemainder,
    required this.onReleaseRemainder,
    required this.onRemove,
    this.onPickChangeAddress,
  });

  final int index;
  final SweepAllocation allocation;
  final BitcoinUnit bitcoinUnit;

  /// What this row would receive if it took the remainder — shown on the Max
  /// chip so the choice is informed. Fee not yet deducted at this point.
  final BigInt remainderSat;

  final bool canRemove;
  final ValueChanged<String> onAddressChanged;
  final ValueChanged<BigInt?> onAmountChanged;
  final VoidCallback onTakeRemainder;
  final VoidCallback onReleaseRemainder;
  final VoidCallback onRemove;

  /// Opens the own-change-address picker. Null when the wallet has no unused
  /// change address to offer, which hides the shortcut rather than dead-ending.
  final VoidCallback? onPickChangeAddress;

  @override
  State<SweepRecipientCard> createState() => _SweepRecipientCardState();
}

class _SweepRecipientCardState extends State<SweepRecipientCard> {
  late final TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: _formatAmount(widget.allocation.amountSat),
    );
  }

  @override
  void didUpdateWidget(SweepRecipientCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only overwrite the field when the incoming value is genuinely different
    // from what's typed — otherwise every rebuild would fight the cursor.
    final incoming = widget.allocation.amountSat;
    if (_parseAmount(_amountController.text) != incoming) {
      _amountController.text = _formatAmount(incoming);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  String _formatAmount(BigInt? sats) {
    if (sats == null) return '';
    return widget.bitcoinUnit == BitcoinUnit.btc
        ? ConvertAmount.satsToBtc(sats.toInt()).toString()
        : sats.toString();
  }

  BigInt? _parseAmount(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    if (widget.bitcoinUnit == BitcoinUnit.btc) {
      final btc = double.tryParse(trimmed);
      if (btc == null || btc <= 0) return null;
      return BigInt.from(ConvertAmount.btcToSats(btc));
    }
    final sats = BigInt.tryParse(trimmed);
    if (sats == null || sats <= BigInt.zero) return null;
    return sats;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final loc = context.loc;
    final allocation = widget.allocation;
    final unitCode = widget.bitcoinUnit == BitcoinUnit.btc ? 'BTC' : 'sats';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(BullRadius.xs),
        border: Border.all(
          color: allocation.takesRemainder ? colors.primary : colors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                loc.sweepRecipientLabel(widget.index + 1),
                style: context.bullText.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.textMuted,
                ),
              ),
              const Spacer(),
              if (widget.canRemove)
                GestureDetector(
                  onTap: widget.onRemove,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: BullIcon(
                      BullIcons.deleteOutline,
                      size: 18,
                      color: colors.textMuted,
                    ),
                  ),
                ),
            ],
          ),
          const Gap(8),
          BullInputText(
            value: allocation.address,
            onChanged: widget.onAddressChanged,
            hint: loc.sweepAddressHint,
            maxLines: 2,
            minLines: 1,
          ),
          if (widget.onPickChangeAddress != null) ...[
            const Gap(6),
            GestureDetector(
              onTap: widget.onPickChangeAddress,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  BullIcon(
                    BullIcons.accountBalanceWallet,
                    size: 14,
                    color: colors.primary,
                  ),
                  const Gap(6),
                  Text(
                    loc.sweepUseOwnChangeAddress,
                    style: context.bullText.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Gap(10),
          if (allocation.takesRemainder)
            _RemainderRow(
              remainderSat: widget.remainderSat,
              bitcoinUnit: widget.bitcoinUnit,
              onRelease: widget.onReleaseRemainder,
            )
          else
            Row(
              children: [
                Expanded(
                  child: BullInputText(
                    controller: _amountController,
                    value: _amountController.text,
                    onlyNumbers: true,
                    hint: loc.sweepAmountHint(unitCode),
                    onChanged: (text) =>
                        widget.onAmountChanged(_parseAmount(text)),
                  ),
                ),
                const Gap(8),
                GestureDetector(
                  onTap: widget.onTakeRemainder,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(BullRadius.xxs),
                      border: Border.all(color: colors.primary),
                    ),
                    child: Text(
                      loc.sweepMax,
                      style: context.bullText.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Replaces the amount field on the row that absorbs the remainder.
class _RemainderRow extends StatelessWidget {
  const _RemainderRow({
    required this.remainderSat,
    required this.bitcoinUnit,
    required this.onRelease,
  });

  final BigInt remainderSat;
  final BitcoinUnit bitcoinUnit;
  final VoidCallback onRelease;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final amount = bitcoinUnit == BitcoinUnit.btc
        ? FormatAmount.btc(ConvertAmount.satsToBtc(remainderSat.toInt()))
        : FormatAmount.sats(remainderSat.toInt());
    return Row(
      children: [
        Expanded(
          child: Text(
            context.loc.sweepTakesRemainderWithAmount(amount),
            style: context.bullText.bodySmall?.copyWith(color: colors.primary),
          ),
        ),
        const Gap(8),
        GestureDetector(
          onTap: onRelease,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              context.loc.sweepUndoMax,
              style: context.bullText.labelMedium?.copyWith(
                color: colors.textMuted,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
