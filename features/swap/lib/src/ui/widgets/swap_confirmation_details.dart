import 'package:bull_ui/app_theme.dart';
import 'package:swap_feature/src/swap_l10n.dart';
import 'package:address_view/address_view.dart' show AddressViewer;
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:swaps/swaps.dart';

class _SwapFeeBreakdown extends StatefulWidget {
  final SwapFees? fees;
  final String? Function(int sats) fiatOf;
  const _SwapFeeBreakdown({required this.fees, required this.fiatOf});
  @override
  State<_SwapFeeBreakdown> createState() => _SwapFeeBreakdownState();
}

class _SwapFeeBreakdownState extends State<_SwapFeeBreakdown> {
  bool expanded = false;

  Widget _feeRow(BuildContext context, String label, int amt) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          BullText(
            label,
            style: context.bullType.label
                .copyWith(fontWeight: FontWeight.w400)
                .copyWith(color: context.appColors.secondary),
          ),
          const Spacer(),
          _AmountWithFiat(
            amt,
            fiat: widget.fiatOf(amt),
            style: context.bullType.label.copyWith(fontWeight: FontWeight.w400),
            color: context.appColors.secondary,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fees = widget.fees;
    final total = fees?.totalFeesMinusLockup(null) ?? 0;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Semantics(
              label: context.swapCopyForLocale.coreScreensTransferFeeLabel,
              button: true,
              expanded: expanded,
              child: InkWell(
                splashColor: context.appColors.transparent,
                splashFactory: NoSplash.splashFactory,
                highlightColor: context.appColors.transparent,
                onTap: () {
                  setState(() {
                    expanded = !expanded;
                  });
                },
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(
                    children: [
                      BullText(
                        context.swapCopyForLocale.coreScreensTransferFeeLabel,
                        style: context.bullType.label
                            .copyWith(fontWeight: FontWeight.w400)
                            .copyWith(
                              color: context.appColors.onSurfaceVariant,
                            ),
                      ),
                      const Spacer(),
                      _AmountWithFiat(
                        total,
                        fiat: widget.fiatOf(total),
                        style: context.bullType.body,
                        color: context.appColors.text,
                      ),
                      const Gap(4),
                      Icon(
                        expanded ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                        color: context.appColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Gap(12),
          if (expanded && fees != null) ...[
            Container(color: context.appColors.surface, height: 1),
            Column(
              children: [
                const Gap(4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: BullText(
                    context
                        .swapCopyForLocale
                        .coreScreensFeeDeductionExplanation,
                    style: context.bullType.caption.copyWith(
                      color: context.appColors.secondary,
                    ),
                  ),
                ),
                if (fees.claimFee case final claimFee?)
                  _feeRow(
                    context,
                    context.swapCopyForLocale.coreScreensReceiveNetworkFeeLabel,
                    claimFee,
                  ),
                if (fees.serverNetworkFees case final serverNetworkFees?)
                  _feeRow(
                    context,
                    context.swapCopyForLocale.coreScreensServerNetworkFeesLabel,
                    serverNetworkFees,
                  ),
                _feeRow(
                  context,
                  context.swapCopyForLocale.coreScreensTransferFeeLabel,
                  fees.boltzFee ?? 0,
                ),
                const Gap(4),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class SwapConfirmationDetails extends StatelessWidget {
  const SwapConfirmationDetails({
    super.key,
    required this.sendWalletLabel,
    this.receiveWalletLabel,
    required this.formattedBitcoinAmount,
    required this.swap,
    required this.fiatOf,
  });
  final String sendWalletLabel;
  final String? receiveWalletLabel;
  final String formattedBitcoinAmount;
  final Swap swap;

  /// The fiat equivalent of an amount of sats, or null without a price.
  final String? Function(int sats) fiatOf;
  Widget _divider(BuildContext context) {
    return Container(height: 1, color: context.appColors.border);
  }

  @override
  Widget build(BuildContext context) {
    final swap = this.swap;
    final receiveWalletLabel = this.receiveWalletLabel;
    final externalAddress = switch (swap) {
      ChainSwap(receiveWalletId: null, :final receiveAddress) => receiveAddress,
      _ => null,
    };
    final receiveAmount = swap.receieveAmount;
    final lockupFee = swap.fees?.lockupFee;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          BullConfirmationRow(
            title: context.swapCopyForLocale.coreScreensFromLabel,
            details: BullText(
              sendWalletLabel,
              style: context.bullType.body.copyWith(
                color: context.appColors.text,
              ),
              textAlign: .end,
            ),
          ),
          _divider(context),
          BullConfirmationRow(
            title: context.swapCopyForLocale.coreScreensToLabel,
            verticalPadding: externalAddress == null ? 10 : 0,
            details: externalAddress != null
                ? Row(
                    mainAxisAlignment: .end,
                    children: [
                      Expanded(
                        child: Semantics(
                          label: context.swapCopyForLocale.coreScreensToLabel,
                          button: true,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: AddressViewer(
                              externalAddress,
                              style: context.bullType.body.copyWith(
                                color: context.appColors.text,
                              ),
                            ),
                          ),
                        ),
                      ),
                      _CopyButton(value: externalAddress),
                    ],
                  )
                : receiveWalletLabel != null && receiveWalletLabel.isNotEmpty
                ? BullText(
                    receiveWalletLabel,
                    style: context.bullType.body.copyWith(
                      color: context.appColors.text,
                    ),
                    textAlign: .end,
                  )
                : const SizedBox.shrink(),
          ),
          _divider(context),
          BullConfirmationRow(
            title: context.swapCopyForLocale.coreScreensTransferIdLabel,
            verticalPadding: 0,
            details: Row(
              mainAxisAlignment: .end,
              mainAxisSize: .min,
              children: [
                Expanded(
                  child: BullText(
                    swap.id,
                    style: context.bullType.body.copyWith(
                      color: context.appColors.text,
                    ),
                    textAlign: .end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _CopyButton(value: swap.id),
              ],
            ),
          ),
          _divider(context),
          BullConfirmationRow(
            title: context.swapCopyForLocale.coreScreensSendAmountLabel,
            details: Column(
              crossAxisAlignment: .end,
              children: [
                if (swap
                    case ChainSwap(:final paymentAmount) ||
                        LnSendSwap(:final paymentAmount))
                  _AmountWithFiat(
                    paymentAmount,
                    fiat: fiatOf(paymentAmount),
                    style: context.bullType.body,
                    color: context.appColors.text,
                  )
                else
                  BullText(
                    formattedBitcoinAmount,
                    style: context.bullType.body.copyWith(
                      color: context.appColors.text,
                    ),
                  ),
              ],
            ),
          ),
          _divider(context),
          if (receiveAmount != null)
            BullConfirmationRow(
              title: context.swapCopyForLocale.coreScreensReceiveAmountLabel,
              details: Column(
                crossAxisAlignment: .end,
                children: [
                  _AmountWithFiat(
                    receiveAmount,
                    fiat: fiatOf(receiveAmount),
                    style: context.bullType.body,
                    color: context.appColors.text,
                  ),
                ],
              ),
            ),
          if (receiveAmount != null) _divider(context),
          if (lockupFee != null)
            BullConfirmationRow(
              title: context.swapCopyForLocale.coreScreensSendNetworkFeeLabel,
              details: Column(
                crossAxisAlignment: .end,
                children: [
                  _AmountWithFiat(
                    lockupFee,
                    fiat: fiatOf(lockupFee),
                    style: context.bullType.body,
                    color: context.appColors.text,
                  ),
                ],
              ),
            ),
          if (lockupFee != null) _divider(context),
          _SwapFeeBreakdown(fees: swap.fees, fiatOf: fiatOf),

          _divider(context),
        ],
      ),
    );
  }
}

class _AmountWithFiat extends StatelessWidget {
  final int sats;
  final String? fiat;
  final TextStyle style;
  final Color color;

  const _AmountWithFiat(
    this.sats, {
    required this.fiat,
    required this.style,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: .end,
    mainAxisSize: .min,
    children: [
      BullAmount.signedSats(
        sats,
        style: style,
        color: color,
        interactive: false,
      ),
      BullFiatEquivalent(fiat),
    ],
  );
}

class _CopyButton extends StatelessWidget {
  final String value;

  const _CopyButton({required this.value});

  @override
  Widget build(BuildContext context) {
    final label = MaterialLocalizations.of(context).copyButtonLabel;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: InkResponse(
          onTap: () => Clipboard.setData(ClipboardData(text: value)),
          radius: 20,
          child: SizedBox(
            width: 28,
            height: 48,
            child: Align(
              alignment: Alignment.centerRight,
              child: Icon(
                Icons.copy,
                color: context.appColors.primary,
                size: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
