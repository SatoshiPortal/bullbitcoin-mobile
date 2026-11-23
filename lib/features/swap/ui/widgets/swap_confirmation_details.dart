import 'package:address_view/address_view.dart' show AddressViewer;
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:swaps/swaps.dart';

class _SwapFeeBreakdown extends StatefulWidget {
  final SwapFees? fees;
  const _SwapFeeBreakdown({required this.fees});
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
          BullAmount.signedSats(
            amt,
            style: context.bullType.label.copyWith(fontWeight: FontWeight.w400),
            color: context.appColors.secondary,
            interactive: false,
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
              label: context.loc.coreScreensTransferFeeLabel,
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
                        context.loc.coreScreensTransferFeeLabel,
                        style: context.bullType.label
                            .copyWith(fontWeight: FontWeight.w400)
                            .copyWith(
                              color: context.appColors.onSurfaceVariant,
                            ),
                      ),
                      const Spacer(),
                      BullAmount.signedSats(
                        total,
                        style: context.bullType.body.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        color: context.appColors.secondary,
                        interactive: false,
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
                    context.loc.coreScreensFeeDeductionExplanation,
                    style: context.bullType.caption.copyWith(
                      color: context.appColors.secondary,
                    ),
                  ),
                ),
                if (fees.claimFee case final claimFee?)
                  _feeRow(
                    context,
                    context.loc.coreScreensReceiveNetworkFeeLabel,
                    claimFee,
                  ),
                if (fees.serverNetworkFees case final serverNetworkFees?)
                  _feeRow(
                    context,
                    context.loc.coreScreensServerNetworkFeesLabel,
                    serverNetworkFees,
                  ),
                _feeRow(
                  context,
                  context.loc.coreScreensTransferFeeLabel,
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
  });
  final String sendWalletLabel;
  final String? receiveWalletLabel;
  final String formattedBitcoinAmount;
  final Swap swap;
  Widget _divider(BuildContext context) {
    return Container(height: 1, color: context.appColors.secondaryFixedDim);
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
            title: context.loc.coreScreensFromLabel,
            details: BullText(
              sendWalletLabel,
              style: context.bullType.body
                  .copyWith(fontWeight: FontWeight.w500)
                  .copyWith(color: context.appColors.secondary),
              textAlign: .end,
            ),
          ),
          _divider(context),
          BullConfirmationRow(
            title: context.loc.coreScreensToLabel,
            verticalPadding: externalAddress == null ? 10 : 0,
            details: externalAddress != null
                ? Row(
                    mainAxisAlignment: .end,
                    children: [
                      Expanded(
                        child: Semantics(
                          label: context.loc.coreScreensToLabel,
                          button: true,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: AddressViewer(
                              externalAddress,
                              style: context.bullType.body.copyWith(
                                fontWeight: FontWeight.w500,
                                color: context.appColors.secondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Gap(4),
                      _CopyButton(value: externalAddress),
                    ],
                  )
                : receiveWalletLabel != null && receiveWalletLabel.isNotEmpty
                ? BullText(
                    receiveWalletLabel,
                    style: context.bullType.body.copyWith(
                      fontWeight: FontWeight.w500,
                      color: context.appColors.secondary,
                    ),
                    textAlign: .end,
                  )
                : const SizedBox.shrink(),
          ),
          _divider(context),
          BullConfirmationRow(
            title: context.loc.coreScreensTransferIdLabel,
            verticalPadding: 0,
            details: Row(
              mainAxisAlignment: .end,
              mainAxisSize: .min,
              children: [
                Expanded(
                  child: BullText(
                    swap.id,
                    style: context.bullType.body
                        .copyWith(fontWeight: FontWeight.w500)
                        .copyWith(color: context.appColors.secondary),
                    textAlign: .end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Gap(4),
                _CopyButton(value: swap.id),
              ],
            ),
          ),
          _divider(context),
          BullConfirmationRow(
            title: context.loc.coreScreensSendAmountLabel,
            details: Column(
              crossAxisAlignment: .end,
              children: [
                if (swap case ChainSwap(:final paymentAmount))
                  BullAmount.signedSats(
                    paymentAmount,
                    style: context.bullType.body
                        .copyWith(fontWeight: FontWeight.w500)
                        .copyWith(color: context.appColors.secondary),
                    interactive: false,
                  )
                else if (swap case LnSendSwap(:final paymentAmount))
                  BullAmount.signedSats(
                    paymentAmount,
                    style: context.bullType.body
                        .copyWith(fontWeight: FontWeight.w500)
                        .copyWith(color: context.appColors.secondary),
                    interactive: false,
                  )
                else
                  BullText(
                    formattedBitcoinAmount,
                    style: context.bullType.body
                        .copyWith(fontWeight: FontWeight.w500)
                        .copyWith(color: context.appColors.secondary),
                  ),
              ],
            ),
          ),
          _divider(context),
          if (receiveAmount != null)
            BullConfirmationRow(
              title: context.loc.coreScreensReceiveAmountLabel,
              details: Column(
                crossAxisAlignment: .end,
                children: [
                  BullAmount.signedSats(
                    receiveAmount,
                    style: context.bullType.body.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    color: context.appColors.secondary,
                    interactive: false,
                  ),
                ],
              ),
            ),
          if (receiveAmount != null) _divider(context),
          if (lockupFee != null)
            BullConfirmationRow(
              title: context.loc.coreScreensSendNetworkFeeLabel,
              details: Column(
                crossAxisAlignment: .end,
                children: [
                  BullAmount.signedSats(
                    lockupFee,
                    style: context.bullType.body.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    color: context.appColors.secondary,
                    interactive: false,
                  ),
                ],
              ),
            ),
          if (lockupFee != null) _divider(context),
          _SwapFeeBreakdown(fees: swap.fees),

          _divider(context),
        ],
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  final String value;

  const _CopyButton({required this.value});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: MaterialLocalizations.of(context).copyButtonLabel,
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      padding: EdgeInsets.zero,
      icon: Icon(Icons.copy, color: context.appColors.primary, size: 16),
      onPressed: () => Clipboard.setData(ClipboardData(text: value)),
    );
  }
}
