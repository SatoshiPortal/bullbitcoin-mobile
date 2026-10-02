import 'package:bb_mobile/core/widgets/switch/bb_switch.dart';
import 'package:bb_mobile/core/widgets/address_viewer.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton, BullText, Gap;

enum SendType { send, swap }

class CommonSendConfirmTopArea extends StatelessWidget {
  const CommonSendConfirmTopArea({
    super.key,
    required this._formattedConfirmedAmountBitcoin,
    required this._sendType,
    this._sendToExternal,
  });
  final String _formattedConfirmedAmountBitcoin;
  final SendType _sendType;
  final bool? _sendToExternal;
  @override
  Widget build(BuildContext context) {
    return Column(
      // crossAxisAlignment: .stretch,
      children: [
        Container(
          alignment: Alignment.center,
          height: 72,
          width: 72,
          decoration: BoxDecoration(
            color: context.appColors.secondaryFixedDim,
            shape: .circle,
          ),
          child: _sendType == SendType.send
              ? Image.asset(Assets.icons.rightArrow.path, height: 24, width: 24)
              : Image.asset(Assets.icons.swap.path, height: 24, width: 24),
        ),
        const Gap(16),
        if (_sendType == SendType.send)
          BullText(
            context.loc.coreScreensConfirmSend,
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.secondary,
            ),
          )
        else if (_sendToExternal == true)
          BullText(
            context.loc.coreScreensExternalTransfer,
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.secondary,
            ),
          )
        else if (_sendToExternal == false)
          BullText(
            context.loc.coreScreensInternalTransfer,
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.secondary,
            ),
          )
        else
          BullText(
            context.loc.coreScreensConfirmTransfer,
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.secondary,
            ),
          ),
        const Gap(4),
        BullText(
          _formattedConfirmedAmountBitcoin,
          style: context.font.displaySmall?.copyWith(
            color: context.appColors.secondary,
          ),
        ),
      ],
    );
  }
}

class CommonInfoRow extends StatelessWidget {
  const CommonInfoRow({super.key, required this.title, required this.details});

  final String title;
  final Widget details;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          BullText(
            title,
            style: context.font.bodySmall?.copyWith(
              color: context.appColors.onSurfaceVariant,
            ),
          ),
          const Gap(24),
          Expanded(child: details),
        ],
      ),
    );
  }
}

class CommonOnchainSendInfoSection extends StatelessWidget {
  const CommonOnchainSendInfoSection({
    required this._sendWalletLabel,
    required this._receiveWalletLabel,
    required this._formattedBitcoinAmount,
    required this._formattedFiatEquivalent,
    required this._absoluteFees,
    required this._selectedFeeOptionTitle,
    this._onFeePriorityTap,
    this._isToSelf = false,
    this._payjoinToggleValue,
    this._onPayjoinToggleChanged,
    this._note = '',
  });
  final String _sendWalletLabel;
  final String _receiveWalletLabel;
  final String _formattedBitcoinAmount;
  final String _formattedFiatEquivalent;
  final String _absoluteFees;
  final String _selectedFeeOptionTitle;
  final VoidCallback? _onFeePriorityTap;
  final bool _isToSelf;

  /// Payjoin toggle row: shown when [_payjoinToggleValue] is non-null (i.e.
  /// a payjoin is available for this send), letting the sender choose NOT to
  /// payjoin. The value mirrors the feature's will-attempt state so the
  /// switch and the sign path can never disagree.
  final bool? _payjoinToggleValue;
  final ValueChanged<bool>? _onPayjoinToggleChanged;
  final String _note;
  Widget _divider(BuildContext context) {
    return Container(height: 1, color: context.appColors.secondaryFixedDim);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          CommonInfoRow(
            title: context.loc.coreScreensFromLabel,
            details: BullText(
              _sendWalletLabel,
              style: context.font.bodyLarge?.copyWith(
                color: context.appColors.secondary,
              ),
              textAlign: .end,
            ),
          ),
          _divider(context),
          CommonInfoRow(
            title: context.loc.coreScreensToLabel,
            details: AddressViewer(
              _receiveWalletLabel,
              style: context.font.bodyLarge,
              color: context.appColors.secondary,
            ),
          ),
          if (_isToSelf) ...[
            _divider(context),
            CommonInfoRow(
              title: context.loc.sendSelfTransfer,
              details: Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  Icons.check,
                  color: context.appColors.secondary,
                  size: 20,
                ),
              ),
            ),
          ],
          if (_payjoinToggleValue != null) ...[
            _divider(context),
            CommonInfoRow(
              title: context.loc.sendPayjoinLabel,
              details: Align(
                alignment: Alignment.centerRight,
                child: BBSwitch(
                  value: _payjoinToggleValue,
                  onChanged: _onPayjoinToggleChanged,
                ),
              ),
            ),
          ],
          if (_note.isNotEmpty) ...[
            _divider(context),
            CommonInfoRow(
              title: context.loc.receiveNote,
              details: BullText(
                _note,
                style: context.font.bodyLarge?.copyWith(
                  color: context.appColors.secondary,
                ),
                textAlign: .end,
              ),
            ),
          ],
          _divider(context),
          CommonInfoRow(
            title: context.loc.coreScreensAmountLabel,
            details: Column(
              crossAxisAlignment: .end,
              children: [
                BullText(
                  _formattedBitcoinAmount,
                  style: context.font.bodyLarge?.copyWith(
                    color: context.appColors.secondary,
                  ),
                ),
                BullText(
                  _formattedFiatEquivalent,
                  style: context.font.labelSmall?.copyWith(
                    color: context.appColors.secondary,
                  ),
                ),
              ],
            ),
          ),
          _divider(context),
          CommonInfoRow(
            title: context.loc.coreScreensNetworkFeesLabel,
            details: BullText(
              _absoluteFees,
              style: context.font.bodyLarge?.copyWith(
                color: context.appColors.secondary,
              ),
              textAlign: .end,
            ),
          ),
          _divider(context),
          if (_onFeePriorityTap != null)
            CommonInfoRow(
              title: context.loc.coreScreensFeePriorityLabel,
              details: InkWell(
                onTap: _onFeePriorityTap,
                child: Row(
                  mainAxisAlignment: .end,
                  children: [
                    BullText(
                      _selectedFeeOptionTitle,
                      style: context.font.bodyLarge?.copyWith(
                        color: context.appColors.primary,
                      ),
                      textAlign: .end,
                    ),
                    const Gap(4),
                    Icon(
                      Icons.arrow_forward_ios_sharp,
                      color: context.appColors.primary,
                      weight: 100,
                      size: 12,
                    ),
                  ],
                ),
              ),
            ),
          if (_onFeePriorityTap != null) _divider(context),
        ],
      ),
    );
  }
}

class CommonLnSwapSendInfoSection extends StatelessWidget {
  const CommonLnSwapSendInfoSection({
    required this._sendWalletLabel,
    required this._paymentRequestAddress,
    required this._formattedBitcoinAmount,
    required this._formattedFiatEquivalent,
    required this._swapId,
    required this._totalSwapFees,
  });
  final String _sendWalletLabel;
  final String _paymentRequestAddress;
  final String _formattedBitcoinAmount;
  final String _formattedFiatEquivalent;
  final String _swapId;
  final String _totalSwapFees;

  Widget _divider(BuildContext context) {
    return Container(height: 1, color: context.appColors.secondaryFixedDim);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          CommonInfoRow(
            title: context.loc.coreScreensFromLabel,
            details: BullText(
              _sendWalletLabel,
              style: context.font.bodyLarge?.copyWith(
                color: context.appColors.secondary,
              ),
              textAlign: .end,
            ),
          ),
          _divider(context),
          CommonInfoRow(
            title: context.loc.coreScreensToLabel,
            details: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: AddressViewer(
                    _paymentRequestAddress,
                    style: context.font.bodyLarge?.copyWith(
                      color: context.appColors.secondary,
                    ),
                  ),
                ),
                const Gap(4),
                InkWell(
                  onTap: () {
                    Clipboard.setData(
                      ClipboardData(text: _paymentRequestAddress),
                    );
                  },
                  child: Icon(
                    Icons.copy,
                    color: context.appColors.primary,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
          _divider(context),
          CommonInfoRow(
            title: context.loc.coreScreensTransferIdLabel,
            details: BullText(
              _swapId,
              style: context.font.bodyLarge?.copyWith(
                color: context.appColors.secondary,
              ),
              textAlign: .end,
            ),
          ),
          _divider(context),
          CommonInfoRow(
            title: context.loc.coreScreensAmountLabel,
            details: Column(
              crossAxisAlignment: .end,
              children: [
                BullText(
                  _formattedBitcoinAmount,
                  style: context.font.bodyLarge?.copyWith(
                    color: context.appColors.secondary,
                  ),
                ),
                BullText(
                  _formattedFiatEquivalent,
                  style: context.font.labelSmall?.copyWith(
                    color: context.appColors.secondary,
                  ),
                ),
              ],
            ),
          ),
          _divider(context),
          CommonInfoRow(
            title: context.loc.coreScreensTotalFeesLabel,
            details: BullText(
              _totalSwapFees,
              style: context.font.bodyLarge?.copyWith(
                color: context.appColors.secondary,
              ),
              textAlign: .end,
            ),
          ),
          _divider(context),
        ],
      ),
    );
  }
}

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
            style: context.font.bodySmall?.copyWith(
              color: context.appColors.secondary,
            ),
          ),
          const Spacer(),
          CurrencyText(
            amt,
            showFiat: false,
            style: context.font.bodySmall,
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
            child: InkWell(
              splashColor: context.appColors.transparent,
              splashFactory: NoSplash.splashFactory,
              highlightColor: context.appColors.transparent,
              onTap: () {
                setState(() {
                  expanded = !expanded;
                });
              },
              child: Row(
                children: [
                  BullText(
                    context.loc.coreScreensTransferFeeLabel,
                    style: context.font.bodySmall?.copyWith(
                      color: context.appColors.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  CurrencyText(
                    total,
                    showFiat: false,
                    style: context.font.bodyLarge,
                    color: context.appColors.secondary,
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
                    style: context.font.labelSmall?.copyWith(
                      color: context.appColors.secondary,
                    ),
                  ),
                ),
                if (fees.claimFee != null)
                  _feeRow(
                    context,
                    context.loc.coreScreensReceiveNetworkFeeLabel,
                    fees.claimFee!,
                  ),
                if (fees.serverNetworkFees != null)
                  _feeRow(
                    context,
                    context.loc.coreScreensServerNetworkFeesLabel,
                    fees.serverNetworkFees!,
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

class CommonChainSwapSendInfoSection extends StatelessWidget {
  const CommonChainSwapSendInfoSection({
    required this.sendWalletLabel,
    this.receiveWalletLabel,
    this.receiveAddress,
    required this.formattedBitcoinAmount,
    required this.swap,
    required this.absoluteFeesFormatted,
    this.absoluteFees,
  });
  final String sendWalletLabel;
  final String? receiveWalletLabel;
  final String? receiveAddress;
  final String formattedBitcoinAmount;
  final Swap swap;
  final String absoluteFeesFormatted;
  final int? absoluteFees;
  Widget _divider(BuildContext context) {
    return Container(height: 1, color: context.appColors.secondaryFixedDim);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          CommonInfoRow(
            title: context.loc.coreScreensFromLabel,
            details: BullText(
              sendWalletLabel,
              style: context.font.bodyLarge?.copyWith(
                color: context.appColors.secondary,
              ),
              textAlign: .end,
            ),
          ),
          _divider(context),
          CommonInfoRow(
            title: context.loc.coreScreensToLabel,
            details:
                swap.isChainSwap &&
                    (swap as ChainSwap).receiveWalletId == null &&
                    (swap as ChainSwap).receiveAddress != null
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        child: AddressViewer(
                          (swap as ChainSwap).receiveAddress!,
                          style: context.font.bodyLarge?.copyWith(
                            color: context.appColors.secondary,
                          ),
                        ),
                      ),
                      const Gap(4),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(
                            ClipboardData(
                              text: (swap as ChainSwap).receiveAddress!,
                            ),
                          );
                        },
                        child: Icon(
                          Icons.copy,
                          color: context.appColors.primary,
                          size: 16,
                        ),
                      ),
                    ],
                  )
                : receiveWalletLabel != null && receiveWalletLabel!.isNotEmpty
                ? BullText(
                    receiveWalletLabel!,
                    style: context.font.bodyLarge?.copyWith(
                      color: context.appColors.secondary,
                    ),
                    textAlign: .end,
                  )
                : const SizedBox.shrink(),
          ),
          _divider(context),
          CommonInfoRow(
            title: context.loc.coreScreensTransferIdLabel,
            details: Row(
              mainAxisAlignment: .end,
              mainAxisSize: .min,
              children: [
                Expanded(
                  child: BullText(
                    swap.id,
                    style: context.font.bodyLarge?.copyWith(
                      color: context.appColors.secondary,
                    ),
                    textAlign: .end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Gap(4),
                InkWell(
                  child: Icon(
                    Icons.copy,
                    color: context.appColors.primary,
                    size: 16,
                  ),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: swap.id));
                  },
                ),
              ],
            ),
          ),
          _divider(context),
          CommonInfoRow(
            title: context.loc.coreScreensSendAmountLabel,
            details: Column(
              crossAxisAlignment: .end,
              children: [
                if (swap.isChainSwap)
                  CurrencyText(
                    (swap as ChainSwap).paymentAmount,
                    showFiat: false,
                    style: context.font.bodyLarge?.copyWith(
                      color: context.appColors.secondary,
                    ),
                  )
                else if (swap.isLnSendSwap)
                  CurrencyText(
                    (swap as LnSendSwap).paymentAmount,
                    showFiat: false,
                    style: context.font.bodyLarge?.copyWith(
                      color: context.appColors.secondary,
                    ),
                  )
                else
                  BullText(
                    formattedBitcoinAmount,
                    style: context.font.bodyLarge?.copyWith(
                      color: context.appColors.secondary,
                    ),
                  ),
              ],
            ),
          ),
          _divider(context),
          if (swap.receieveAmount != null)
            CommonInfoRow(
              title: context.loc.coreScreensReceiveAmountLabel,
              details: Column(
                crossAxisAlignment: .end,
                children: [
                  CurrencyText(
                    swap.receieveAmount!,
                    showFiat: false,
                    style: context.font.bodyLarge,
                    color: context.appColors.secondary,
                  ),
                ],
              ),
            ),
          if (swap.receieveAmount != null) _divider(context),
          if (swap.fees?.lockupFee != null)
            CommonInfoRow(
              title: context.loc.coreScreensSendNetworkFeeLabel,
              details: Column(
                crossAxisAlignment: .end,
                children: [
                  CurrencyText(
                    swap.fees!.lockupFee!,
                    showFiat: false,
                    style: context.font.bodyLarge,
                    color: context.appColors.secondary,
                  ),
                ],
              ),
            ),
          if (swap.fees?.lockupFee != null) _divider(context),
          _SwapFeeBreakdown(fees: swap.fees),

          _divider(context),
        ],
      ),
    );
  }
}

class CommonSendBottomButtons extends StatelessWidget {
  const CommonSendBottomButtons({
    required this._disableSendButton,
    required this._onSendPressed,
  });

  final bool _disableSendButton;
  final Function _onSendPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CommonConfirmSendButton(
        disableSendButton: _disableSendButton,
        onPressed: _onSendPressed,
      ),
    );
  }
}

class CommonConfirmSendButton extends StatelessWidget {
  const CommonConfirmSendButton({
    super.key,
    required this._disableSendButton,
    required this._onPressed,
  });
  final bool _disableSendButton;
  final Function _onPressed;

  @override
  Widget build(BuildContext context) {
    return BullButton.big(
      label: context.loc.coreScreensConfirmButton,
      onPressed: () {
        _onPressed();
      },
      bgColor: context.appColors.secondary,
      textColor: context.appColors.onSecondary,
      disabled: _disableSendButton,
    );
  }
}

class CommonConfirmSendErrorSection extends StatelessWidget {
  const CommonConfirmSendErrorSection({required this.errorMessage});

  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    if (errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            BullText(
              context.loc.sendErrorBuildFailed,
              style: context.font.bodyLarge,
              color: context.appColors.error,
              maxLines: 5,
              textAlign: .center,
            ),
            const Gap(8),
            BullText(
              errorMessage!,
              style: context.font.bodyMedium,
              color: context.appColors.error,
              maxLines: 5,
              textAlign: .center,
            ),
            const Gap(8),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
