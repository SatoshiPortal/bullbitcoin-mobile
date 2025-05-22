import 'package:bb_mobile/core/errors/send_errors.dart';
import 'package:bb_mobile/core/utils/string_formatting.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
// ignore: unused_import
import 'package:bb_mobile/ui/screens/widgets/advanced_options_bottom_sheet.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

enum SendType { send, swap }

class CommonSendConfirmTopArea extends StatelessWidget {
  const CommonSendConfirmTopArea({
    super.key,
    required String formattedConfirmedAmountBitcoin,
    required SendType sendType,
  }) : _formattedConfirmedAmountBitcoin = formattedConfirmedAmountBitcoin,
       _sendType = sendType;
  final String _formattedConfirmedAmountBitcoin;
  final SendType _sendType;
  @override
  Widget build(BuildContext context) {
    return Column(
      // crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          alignment: Alignment.center,
          height: 72,
          width: 72,
          decoration: BoxDecoration(
            color: context.colour.secondaryFixedDim,
            shape: BoxShape.circle,
          ),
          child:
              _sendType == SendType.send
                  ? Image.asset(
                    Assets.icons.rightArrow.path,
                    height: 24,
                    width: 24,
                  )
                  : Image.asset(Assets.icons.swap.path, height: 24, width: 24),
        ),
        const Gap(16),
        if (_sendType == SendType.send)
          BBText('Confirm Send', style: context.font.bodyMedium)
        else
          BBText('Confirm Swap', style: context.font.bodyMedium),
        const Gap(4),
        BBText(
          _formattedConfirmedAmountBitcoin,
          style: context.font.displaySmall,
          color: context.colour.outlineVariant,
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
          BBText(
            title,
            style: context.font.bodySmall,
            color: context.colour.surfaceContainer,
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
    required String sendWalletLabel,
    required String addressOrInvoice,
    required String formattedBitcoinAmount,
    required String formattedFiatEquivalent,
    required String absoluteFees,
    required String selectedFeeOptionTitle,
  }) : _sendWalletLabel = sendWalletLabel,
       _addressOrInvoice = addressOrInvoice,
       _formattedBitcoinAmount = formattedBitcoinAmount,
       _formattedFiatEquivalent = formattedFiatEquivalent,
       _absoluteFees = absoluteFees,
       _selectedFeeOptionTitle = selectedFeeOptionTitle;
  final String _sendWalletLabel;
  final String _addressOrInvoice;
  final String _formattedBitcoinAmount;
  final String _formattedFiatEquivalent;
  final String _absoluteFees;
  final String _selectedFeeOptionTitle;
  Widget _divider(BuildContext context) {
    return Container(height: 1, color: context.colour.secondaryFixedDim);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CommonInfoRow(
            title: 'From',
            details: BBText(
              _sendWalletLabel,
              style: context.font.bodyLarge,
              textAlign: TextAlign.end,
            ),
          ),
          _divider(context),
          CommonInfoRow(
            title: 'To',
            details: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: BBText(
                    _addressOrInvoice,
                    maxLines: 5,
                    style: context.font.bodyLarge,
                    textAlign: TextAlign.end,
                  ),
                ),
                const Gap(8),
                InkWell(
                  child: Icon(
                    Icons.copy,
                    color: context.colour.primary,
                    size: 16,
                  ),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _addressOrInvoice));
                  },
                ),
              ],
            ),
          ),
          _divider(context),
          CommonInfoRow(
            title: 'Amount',
            details: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                BBText(_formattedBitcoinAmount, style: context.font.bodyLarge),
                BBText(
                  '~$_formattedFiatEquivalent',
                  style: context.font.labelSmall,
                  color: context.colour.surfaceContainer,
                ),
              ],
            ),
          ),
          _divider(context),
          CommonInfoRow(
            title: 'Network fees',
            details: BBText(
              "$_absoluteFees sats",
              style: context.font.bodyLarge,
              textAlign: TextAlign.end,
            ),
          ),
          _divider(context),
          CommonInfoRow(
            title: 'Fee Priority',
            details: InkWell(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  BBText(
                    _selectedFeeOptionTitle,
                    style: context.font.bodyLarge,
                    color: context.colour.primary,
                    textAlign: TextAlign.end,
                  ),
                  const Gap(4),
                  Icon(
                    Icons.arrow_forward_ios_sharp,
                    color: context.colour.primary,
                    weight: 100,
                    size: 12,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CommonLnSwapSendInfoSection extends StatelessWidget {
  const CommonLnSwapSendInfoSection({
    required String sendWalletLabel,
    required String addressOrInvoice,
    required String formattedBitcoinAmount,
    required String formattedFiatEquivalent,
    required String swapId,
    required String totalSwapFees,
  }) : _sendWalletLabel = sendWalletLabel,
       _addressOrInvoice = addressOrInvoice,
       _formattedBitcoinAmount = formattedBitcoinAmount,
       _formattedFiatEquivalent = formattedFiatEquivalent,
       _swapId = swapId,
       _totalSwapFees = totalSwapFees;
  final String _sendWalletLabel;
  final String _addressOrInvoice;
  final String _formattedBitcoinAmount;
  final String _formattedFiatEquivalent;
  final String _swapId;
  final String _totalSwapFees;

  Widget _divider(BuildContext context) {
    return Container(height: 1, color: context.colour.secondaryFixedDim);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CommonInfoRow(
            title: 'From',
            details: BBText(
              _sendWalletLabel,
              style: context.font.bodyLarge,
              textAlign: TextAlign.end,
            ),
          ),
          _divider(context),
          CommonInfoRow(
            title: 'To',
            details: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                BBText(
                  StringFormatting.truncateMiddle(_addressOrInvoice),
                  style: context.font.bodyLarge,
                  textAlign: TextAlign.end,
                ),
                const Gap(4),
                InkWell(
                  child: Icon(
                    Icons.copy,
                    color: context.colour.primary,
                    size: 16,
                  ),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _addressOrInvoice));
                  },
                ),
              ],
            ),
            // const Gap(4),
            // InkWell(
            //   child: Icon(
            //     Icons.copy,
            //     color: context.colour.primary,
            //     size: 16,
            //   ),
            // ),
          ),
          _divider(context),
          CommonInfoRow(
            title: 'Swap ID',
            details: BBText(
              _swapId,
              style: context.font.bodyLarge,
              textAlign: TextAlign.end,
            ),
          ),
          _divider(context),
          CommonInfoRow(
            title: 'Amount',
            details: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                BBText(_formattedBitcoinAmount, style: context.font.bodyLarge),
                BBText(
                  '~$_formattedFiatEquivalent',
                  style: context.font.labelSmall,
                  color: context.colour.surfaceContainer,
                ),
              ],
            ),
          ),
          _divider(context),
          CommonInfoRow(
            title: 'Total fees',
            details: BBText(
              "$_totalSwapFees sats",
              style: context.font.bodyLarge,
              textAlign: TextAlign.end,
            ),
          ),
          _divider(context),
        ],
      ),
    );
  }
}

class CommonSendBottomButtons extends StatelessWidget {
  const CommonSendBottomButtons({
    required bool isBitcoinWallet,
    required StateStreamableSource<Object?> blocProviderValue,
    required bool disableSendButton,
    required Function onSendPressed,
  }) : _isBitcoinWallet = isBitcoinWallet,
       _blocProviderValue = blocProviderValue,
       _disableSendButton = disableSendButton,
       _onSendPressed = onSendPressed;

  // ignore: unused_field
  final bool _isBitcoinWallet;
  // ignore: unused_field
  final StateStreamableSource<Object?> _blocProviderValue;
  final bool _disableSendButton;
  final Function _onSendPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // if (_isBitcoinWallet) ...[
          //   BBButton.big(
          //     label: 'Advanced Settings',
          //     onPressed: () {
          //       showModalBottomSheet(
          //         context: context,
          //         isScrollControlled: true,
          //         backgroundColor: context.colour.secondaryFixed,
          //         builder:
          //             (BuildContext buildContext) => BlocProvider.value(
          //               value: _blocProviderValue,
          //               child: const AdvancedOptionsBottomSheet(),
          //             ),
          //       );
          //     },
          //     borderColor: context.colour.secondary,
          //     outlined: true,
          //     bgColor: Colors.transparent,
          //     textColor: context.colour.secondary,
          //   ),
          //   const Gap(12),
          // ],
          CommonConfirmSendButton(
            disableSendButton: _disableSendButton,
            onPressed: _onSendPressed,
          ),
        ],
      ),
    );
  }
}

class CommonChainSwapSendInfoSection extends StatelessWidget {
  const CommonChainSwapSendInfoSection({
    required String sendWalletLabel,
    String? receiveWalletLabel,
    String? receiveAddress,
    required String formattedBitcoinAmount,
    required String formattedFiatEquivalent,
    required String swapId,
    required String totalSwapFees,
  }) : _sendWalletLabel = sendWalletLabel,
       _receiveWalletLabel = receiveWalletLabel,
       _receiveAddress = receiveAddress,
       _formattedBitcoinAmount = formattedBitcoinAmount,
       _formattedFiatEquivalent = formattedFiatEquivalent,
       _swapId = swapId,
       _totalSwapFees = totalSwapFees;
  final String _sendWalletLabel;
  final String? _receiveWalletLabel;
  final String? _receiveAddress;
  final String _formattedBitcoinAmount;
  // ignore: unused_field
  final String _formattedFiatEquivalent;
  final String _swapId;
  final String _totalSwapFees;

  Widget _divider(BuildContext context) {
    return Container(height: 1, color: context.colour.secondaryFixedDim);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CommonInfoRow(
            title: 'From',
            details: BBText(
              _sendWalletLabel,
              style: context.font.bodyLarge,
              textAlign: TextAlign.end,
            ),
          ),
          _divider(context),

          CommonInfoRow(
            title: 'To',
            details: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_receiveWalletLabel != null)
                  BBText(
                    _receiveWalletLabel,
                    style: context.font.bodyLarge,
                    textAlign: TextAlign.end,
                  )
                else ...[
                  BBText(
                    StringFormatting.truncateMiddle(_receiveAddress!),
                    style: context.font.bodyLarge,
                    textAlign: TextAlign.end,
                  ),
                  const Gap(4),
                  InkWell(
                    child: Icon(
                      Icons.copy,
                      color: context.colour.primary,
                      size: 16,
                    ),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: _receiveAddress));
                    },
                  ),
                ],
              ],
            ),
            // const Gap(4),
            // InkWell(
            //   child: Icon(
            //     Icons.copy,
            //     color: context.colour.primary,
            //     size: 16,
            //   ),
            // ),
          ),
          _divider(context),
          CommonInfoRow(
            title: 'Swap ID',
            details: BBText(
              _swapId,
              style: context.font.bodyLarge,
              textAlign: TextAlign.end,
            ),
          ),
          _divider(context),
          CommonInfoRow(
            title: 'Amount',
            details: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                BBText(_formattedBitcoinAmount, style: context.font.bodyLarge),
                // BBText(
                //   '~$_formattedFiatEquivalent',
                //   style: context.font.labelSmall,
                //   color: context.colour.surfaceContainer,
                // ),
              ],
            ),
          ),
          _divider(context),
          CommonInfoRow(
            title: 'Total fees',
            details: BBText(
              _totalSwapFees,
              style: context.font.bodyLarge,
              textAlign: TextAlign.end,
            ),
          ),
          _divider(context),
        ],
      ),
    );
  }
}

class CommonConfirmSendButton extends StatelessWidget {
  const CommonConfirmSendButton({
    super.key,
    required bool disableSendButton,
    required Function onPressed,
  }) : _disableSendButton = disableSendButton,
       _onPressed = onPressed;
  final bool _disableSendButton;
  final Function _onPressed;

  @override
  Widget build(BuildContext context) {
    return BBButton.big(
      label: 'Confirm',
      onPressed: () {
        _onPressed();
      },
      bgColor: context.colour.secondary,
      textColor: context.colour.onSecondary,
      disabled: _disableSendButton,
    );
  }
}

class CommonConfirmSendErrorSection extends StatelessWidget {
  const CommonConfirmSendErrorSection({
    required BuildTransactionException? buildError,
    required ConfirmTransactionException? confirmError,
  }) : _buildError = buildError,
       _confirmError = confirmError;

  final BuildTransactionException? _buildError;
  final ConfirmTransactionException? _confirmError;

  @override
  Widget build(BuildContext context) {
    if (_buildError != null) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            BBText(
              _buildError.title,
              style: context.font.bodyLarge,
              color: context.colour.error,
              maxLines: 5,
              textAlign: TextAlign.center,
            ),
            const Gap(8),
            BBText(
              _buildError.message,
              style: context.font.bodyMedium,
              color: context.colour.error,
              maxLines: 5,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    if (_confirmError != null) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            BBText(
              _confirmError.title,
              style: context.font.bodyLarge,
              color: context.colour.error,
              maxLines: 5,
              textAlign: TextAlign.center,
            ),
            const Gap(8),
            BBText(
              _confirmError.message,
              style: context.font.bodyMedium,
              color: context.colour.error,
              maxLines: 5,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    } else {
      return const SizedBox.shrink();
    }
  }
}
