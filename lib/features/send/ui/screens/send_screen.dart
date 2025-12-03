import 'dart:math' as math;

import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/string_formatting.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/core/widgets/dialpad/dial_pad.dart';
import 'package:bb_mobile/core/widgets/inputs/text_input.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/price_input/balance_row.dart';
import 'package:bb_mobile/core/widgets/price_input/price_input.dart';
import 'package:bb_mobile/core/widgets/segment/segmented_full.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/bitbox/ui/bitbox_router.dart';
import 'package:bb_mobile/features/bitbox/ui/screens/bitbox_action_screen.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:bb_mobile/features/ledger/ui/ledger_router.dart';
import 'package:bb_mobile/features/ledger/ui/screens/ledger_action_screen.dart';
import 'package:bb_mobile/features/psbt_flow/psbt_router.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_state.dart';
import 'package:bb_mobile/features/send/ui/screens/open_the_camera_widget.dart';
import 'package:bb_mobile/features/send/ui/widgets/advanced_options_bottom_sheet.dart';
import 'package:bb_mobile/features/send/ui/widgets/fee_options_modal.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:gif/gif.dart';
import 'package:go_router/go_router.dart';

class SendScreen extends StatelessWidget {
  const SendScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final step = context.select<SendCubit, SendStep>(
      (cubit) => cubit.state.step,
    );
    switch (step) {
      case SendStep.address:
        return const SendAddressScreen();
      case SendStep.amount:
        return const SendAmountScreen();
      case SendStep.confirm:
        return const SendConfirmScreen();
      case SendStep.sending:
        return const SendSendingScreen();
      case SendStep.success:
        return const SendSucessScreen();
    }
  }
}

class SendAddressScreen extends StatelessWidget {
  const SendAddressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.secondaryFixedDim,
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: context.loc.sendTitle,
          color: context.appColors.secondaryFixedDim,
          onBack: () => context.pop(),
        ),
      ),
      body: Stack(
        fit: .expand,
        children: [
          Column(
            children: [
              FadingLinearProgress(
                height: 3,
                trigger: context.select(
                  (SendCubit cubit) =>
                      cubit.state.loadingBestWallet || cubit.state.creatingSwap,
                ),
                backgroundColor: context.appColors.onPrimary,
                foregroundColor: context.appColors.primary,
              ),
              Expanded(
                child: Stack(
                  fit: .expand,
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.5,
                      child: OpenTheCameraWidget(
                        onScannedPaymentRequest: (data) => context
                            .read<SendCubit>()
                            .onScannedPaymentRequest(data.$1, data.$2),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SingleChildScrollView(
                        child: Container(
                          decoration: BoxDecoration(
                            color: context.appColors.onPrimary,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: .stretch,
                            mainAxisSize: .min,
                            children: [
                              const Gap(32),
                              BBText(
                                context.loc.sendRecipientAddress,
                                style: context.font.bodyMedium,
                              ),
                              const Gap(16),
                              const AddressField(),
                              const Gap(16),
                              const AddressErrorSection(),
                              const Gap(16),
                              const SendContinueWithAddressButton(),
                              const Gap(42),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SendContinueWithAddressButton extends StatelessWidget {
  const SendContinueWithAddressButton({super.key});

  @override
  Widget build(BuildContext context) {
    final loadingBestWallet = context.select(
      (SendCubit cubit) => cubit.state.loadingBestWallet,
    );
    final isValidPaymentRequest = context.select(
      (SendCubit cubit) => cubit.state.paymentRequest != null,
    );
    final creatingSwap = context.select(
      (SendCubit cubit) => cubit.state.creatingSwap,
    );

    return BBButton.big(
      label: context.loc.sendContinue,
      onPressed: () {
        context.read<SendCubit>().continueOnAddressConfirmed();
      },
      disabled: !isValidPaymentRequest || loadingBestWallet || creatingSwap,
      bgColor: context.appColors.secondary,
      textColor: context.appColors.onPrimary,
    );
  }
}

class AddressField extends StatelessWidget {
  const AddressField({super.key});

  @override
  Widget build(BuildContext context) {
    final address = context.select<SendCubit, String>(
      (cubit) => cubit.state.copiedRawPaymentRequest,
    );

    return BBInputText(
      onChanged: context.read<SendCubit>().onChangedText,
      value: address,
      hint: context.loc.sendPasteAddressOrInvoice,
      hintStyle: context.font.bodyLarge?.copyWith(
        color: context.appColors.surfaceContainer,
      ),
      maxLines: 1,
      rightIcon: Icon(
        Icons.paste_sharp,
        color: context.appColors.secondary,
        size: 20,
      ),
      onRightTap: () {
        Clipboard.getData(Clipboard.kTextPlain).then((value) {
          if (value != null) {
            if (context.mounted) {
              context.read<SendCubit>().onChangedText(value.text ?? '');
            }
          }
        });
      },
    );
  }
}

class AddressErrorSection extends StatelessWidget {
  const AddressErrorSection({super.key});

  @override
  Widget build(BuildContext context) {
    final balanceError = context.select(
      (SendCubit cubit) => cubit.state.insufficientBalanceException,
    );
    final swapError = context.select(
      (SendCubit cubit) => cubit.state.swapCreationException,
    );
    final invalidAddress = context.select(
      (SendCubit cubit) => cubit.state.invalidBitcoinStringException,
    );
    if (balanceError != null) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: BBText(
          context.loc.sendErrorInsufficientBalanceForPayment,
          style: context.font.bodyMedium,
          color: context.appColors.error,
          textAlign: .center,
          maxLines: 2,
        ),
      );
    }
    if (swapError != null) {
      return BBText(
        context.loc.sendErrorSwapCreationFailed,
        style: context.font.bodyMedium,
        color: context.appColors.error,
        textAlign: .center,
        maxLines: 2,
      );
    }
    if (invalidAddress != null) {
      return BBText(
        context.loc.sendErrorInvalidAddressOrInvoice,
        style: context.font.bodyMedium,
        color: context.appColors.error,
        textAlign: .center,
        maxLines: 2,
      );
    }
    return const SizedBox(height: 21);
  }
}

class SendAmountScreen extends StatefulWidget {
  const SendAmountScreen({super.key});

  @override
  State<SendAmountScreen> createState() => _SendAmountScreenState();
}

class _SendAmountScreenState extends State<SendAmountScreen> {
  late TextEditingController _amountController;
  late FocusNode _amountFocusNode;
  bool _isMax = false;

  @override
  void initState() {
    super.initState();
    final amount = context.read<SendCubit>().state.amount;
    _amountController = TextEditingController.fromValue(
      TextEditingValue(
        text: amount,
        selection: TextSelection.collapsed(offset: amount.length),
      ),
    );
    _amountFocusNode = FocusNode();
  }

  void _setIsMax(bool isMax) {
    setState(() {
      _isMax = isMax;
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.onPrimary,
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: context.loc.sendTitle,
          onBack: () => context.read<SendCubit>().backClicked(),
        ),
      ),
      body: Column(
        children: [
          FadingLinearProgress(
            height: 3,
            trigger: context.select(
              (SendCubit cubit) => cubit.state.creatingSwap,
            ),
            backgroundColor: context.appColors.onPrimary,
            foregroundColor: context.appColors.primary,
          ),
          Expanded(
            child: BlocListener<SendCubit, SendState>(
              listenWhen: (previous, current) =>
                  previous.amount != current.amount &&
                  _amountController.text != current.amount,
              listener: (context, state) {
                final amount = state.amount;
                final currentCursor = _amountController.selection.baseOffset;
                final safePosition = _isMax
                    ? amount.length
                    : math.min(currentCursor, amount.length);

                _amountController.value = TextEditingValue(
                  text: amount,
                  selection: TextSelection.collapsed(offset: safePosition),
                );
              },
              child: BlocBuilder<SendCubit, SendState>(
                builder: (context, state) {
                  final cubit = context.read<SendCubit>();
                  final balanceError = context.select(
                    (SendCubit cubit) =>
                        cubit.state.insufficientBalanceException,
                  );
                  final swapLimitsError = context.select(
                    (SendCubit cubit) => cubit.state.swapLimitsException,
                  );
                  final swapCreationError = context.select(
                    (SendCubit cubit) => cubit.state.swapCreationException,
                  );
                  final walletHasBalance = context.select(
                    (SendCubit cubit) => cubit.state.walletHasBalance,
                  );
                  final isLightning = context.select(
                    (SendCubit cubit) => cubit.state.isLightning,
                  );
                  final isChainSwap = context.select(
                    (SendCubit cubit) => cubit.state.chainSwap != null,
                  );
                  final inputCurrency = context.select(
                    (SendCubit cubit) => cubit.state.inputAmountCurrencyCode,
                  );

                  final availableInputCurrencies = context
                      .select<SendCubit, List<String>>(
                        (bloc) => bloc.state.inputAmountCurrencyCodes,
                      );
                  final buildError = context.select(
                    (SendCubit cubit) => cubit.state.buildTransactionException,
                  );
                  final selectedWalletLabel = context.select(
                    (SendCubit cubit) => cubit.state.selectedWallet!.label,
                  );
                  return IgnorePointer(
                    ignoring: state.amountConfirmedClicked,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: .stretch,
                          children: [
                            const Gap(10),
                            const NetworkDisplay(),
                            const Gap(24),
                            PriceInput(
                              currency: inputCurrency,
                              amountEquivalent:
                                  state.formattedAmountInputEquivalent,
                              availableCurrencies: availableInputCurrencies,
                              amountController: _amountController,
                              onNoteChanged: cubit.noteChanged,
                              onCurrencyChanged: (currencyCode) {
                                _setIsMax(false);
                                context.read<SendCubit>().onCurrencyChanged(
                                  currencyCode,
                                );
                              },
                              error:
                                  balanceError != null
                                      ? context.loc.sendErrorInsufficientBalanceForPayment
                                      : !walletHasBalance
                                      ? context.loc.sendInsufficientBalance
                                      : swapLimitsError != null
                                      ? _getSwapLimitsErrorMessage(context, swapLimitsError)
                                      : swapCreationError != null
                                      ? context.loc.sendErrorSwapCreationFailed
                                      : null,
                              focusNode: _amountFocusNode,
                              readOnly: _isMax,
                              isMax: _isMax,
                            ),
                            const Gap(48),
                            Divider(
                              height: 1,
                              color: context.appColors.secondaryFixedDim,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: BalanceRow(
                                balance: state.formattedWalletBalance(),
                                currencyCode: '',
                                onMaxPressed: !isLightning && !isChainSwap
                                    ? () {
                                        _setIsMax(true);
                                        context.read<SendCubit>().amountChanged(
                                          isMax: true,
                                        );
                                      }
                                    : null,
                                walletLabel: selectedWalletLabel,
                              ),
                            ),
                            Builder(
                              builder: (context) {
                                final inputCurrency = context
                                    .select<SendCubit, String>(
                                      (cubit) =>
                                          cubit.state.inputAmountCurrencyCode,
                                    );

                                return AmountDialPad(
                                  controller: _amountController,
                                  inputCurrencyCode: inputCurrency,
                                  onAmountChanged: () {
                                    // Unset max since user manually changed the amount
                                    _setIsMax(false);
                                    // Inform the cubit of the change
                                    context.read<SendCubit>().amountChanged(
                                      amount: _amountController.text,
                                    );
                                  },
                                );
                              },
                            ),
                            const Gap(16),
                            if (buildError != null) const _SendError(),
                            const SendAmountConfirmButton(),
                            const Gap(48),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SendAmountConfirmButton extends StatelessWidget {
  const SendAmountConfirmButton({super.key});

  @override
  Widget build(BuildContext context) {
    final hasBalance = context.select(
      (SendCubit cubit) => cubit.state.walletHasBalance,
    );
    final amountConfirmedClicked = context.select(
      (SendCubit cubit) => cubit.state.amountConfirmedClicked,
    );
    final creatingSwap = context.select(
      (SendCubit cubit) => cubit.state.creatingSwap,
    );
    final loadingBestWallet = context.select(
      (SendCubit cubit) => cubit.state.loadingBestWallet,
    );
    final inputAmountSat = context.select(
      (SendCubit cubit) => cubit.state.inputAmountSat,
    );
    return BBButton.big(
      label: context.loc.sendContinue,
      onPressed: () {
        context.read<SendCubit>().onAmountConfirmed();
      },
      disabled:
          amountConfirmedClicked ||
          !hasBalance ||
          creatingSwap ||
          loadingBestWallet ||
          inputAmountSat <= 0,
      bgColor: context.appColors.secondary,
      textColor: context.appColors.onPrimary,
    );
  }
}

class NetworkDisplay extends StatelessWidget {
  const NetworkDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    final sendType = context.select<SendCubit, SendType>(
      (cubit) => cubit.state.sendType,
    );

    return AnimatedOpacity(
      opacity: 0.5,
      duration: const Duration(milliseconds: 200),
      child: IgnorePointer(
        child: BBSegmentFull(
          items: SendType.values.map((e) => e.displayName).toSet(),
          onSelected: (c) {},
          initialValue: sendType.displayName,
        ),
      ),
    );
  }
}

class SendConfirmScreen extends StatelessWidget {
  const SendConfirmScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isLnSwap = context.select(
      (SendCubit cubit) => cubit.state.lightningSwap != null,
    );
    final isChainSwap = context.select(
      (SendCubit cubit) => cubit.state.chainSwap != null,
    );
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: context.loc.sendTitle,
          onBack: () => context.read<SendCubit>().backClicked(),
        ),
      ),
      body: Column(
        children: [
          FadingLinearProgress(
            height: 3,
            trigger: context.select(
              (SendCubit cubit) =>
                  cubit.state.buildingTransaction ||
                  cubit.state.signingTransaction,
            ),
            backgroundColor: context.appColors.onPrimary,
            foregroundColor: context.appColors.primary,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: .stretch,
                  children: [
                    // const Gap(24),
                    const SendConfirmTopArea(),
                    const Gap(40),
                    if (isLnSwap)
                      const _LnSwapSendInfoSection()
                    else if (isChainSwap)
                      const _ChainSwapSendInfoSection()
                    else
                      const _OnchainSendInfoSection(),
                    const Gap(40),
                    const _SendError(),
                    const _BottomButtons(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SendError extends StatelessWidget {
  const _SendError();

  @override
  Widget build(BuildContext context) {
    final buildError = context.select(
      (SendCubit cubit) => cubit.state.buildTransactionException,
    );

    final confirmError = context.select(
      (SendCubit cubit) => cubit.state.confirmTransactionException,
    );

    if (buildError != null) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            BBText(
              context.loc.sendErrorBuildFailed,
              style: context.font.bodyLarge,
              color: context.appColors.error,
              maxLines: 5,
              textAlign: .center,
            ),
            const Gap(8),
            BBText(
              buildError.message,
              style: context.font.bodyMedium,
              color: context.appColors.error,
              maxLines: 5,
              textAlign: .center,
            ),
          ],
        ),
      );
    }
    if (confirmError != null) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            BBText(
              context.loc.sendErrorConfirmationFailed,
              style: context.font.bodyLarge,
              color: context.appColors.error,
              maxLines: 5,
              textAlign: .center,
            ),
            const Gap(8),
            BBText(
              confirmError.message,
              style: context.font.bodyMedium,
              color: context.appColors.error,
              maxLines: 5,
              textAlign: .center,
            ),
          ],
        ),
      );
    } else {
      return const SizedBox.shrink();
    }
  }
}

// ignore: unused_element
class _HighFeeWarning extends StatelessWidget {
  final double feePercent;
  const _HighFeeWarning(this.feePercent);

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      title: context.loc.sendHighFeeWarning,
      description:
          context.loc.sendHighFeeWarningDescription(feePercent.toStringAsFixed(2)),
      tagColor: context.appColors.onError,
      bgColor: context.appColors.secondaryFixed,
    );
  }
}

class _SlowPaymentWarning extends StatelessWidget {
  const _SlowPaymentWarning();

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      title: context.loc.sendSlowPaymentWarning,
      description: context.loc.sendSlowPaymentWarningDescription,
      tagColor: context.appColors.onError,
      bgColor: context.appColors.secondaryFixed,
    );
  }
}

class _BottomButtons extends StatelessWidget {
  const _BottomButtons();

  @override
  Widget build(BuildContext context) {
    final isBitcoinWallet = context.select(
      (SendCubit cubit) => !cubit.state.selectedWallet!.isLiquid,
    );
    final wallet = context.select(
      (SendCubit cubit) => cubit.state.selectedWallet,
    );
    final hasFinalizedTx = context.select(
      (SendCubit cubit) => cubit.state.signedBitcoinTx != null,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          if (isBitcoinWallet && !hasFinalizedTx) ...[
            BBButton.big(
              label: context.loc.sendAdvancedSettings,
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: context.appColors.secondaryFixed,
                  constraints: const BoxConstraints(maxWidth: double.infinity),
                  builder: (BuildContext buildContext) => BlocProvider.value(
                    value: context.read<SendCubit>(),
                    child: const AdvancedOptionsBottomSheet(),
                  ),
                );
              },
              borderColor: context.appColors.secondary,
              outlined: true,
              bgColor: context.appColors.transparent,
              textColor: context.appColors.secondary,
            ),
            const Gap(12),
          ],
          if (wallet != null && wallet.signsRemotely && !hasFinalizedTx)
            (wallet.signerDevice != null && wallet.signerDevice!.isLedger)
                ? const SignLedgerButton()
                : (wallet.signerDevice != null && wallet.signerDevice!.isBitBox)
                ? const SignBitBoxButton()
                : const ShowPsbtButton()
          else
            const ConfirmSendButton(),
        ],
      ),
    );
  }
}

class ConfirmSendButton extends StatelessWidget {
  const ConfirmSendButton({super.key});

  @override
  Widget build(BuildContext context) {
    final hasFinalizedTx = context.select(
      (SendCubit cubit) => cubit.state.signedBitcoinTx != null,
    );
    final disableSendButton = context.select(
      (SendCubit cubit) => cubit.state.disableConfirmSend,
    );
    return BBButton.big(
      label: hasFinalizedTx ? context.loc.sendBroadcastTransaction : context.loc.sendConfirm,
      onPressed: () {
        context.read<SendCubit>().onConfirmTransactionClicked();
      },
      bgColor: context.appColors.secondary,
      textColor: context.appColors.onSecondary,
      disabled: disableSendButton,
    );
  }
}

class _OnchainSendInfoSection extends StatelessWidget {
  const _OnchainSendInfoSection();
  Widget _divider(BuildContext context) {
    return Container(height: 1, color: context.appColors.secondaryFixedDim);
  }

  @override
  Widget build(BuildContext context) {
    final selectedWallet = context.select(
      (SendCubit cubit) => cubit.state.selectedWallet,
    );
    final paymentRequestAddress = context.select(
      (SendCubit cubit) => cubit.state.paymentRequestAddress,
    );
    final formattedBitcoinAmount = context.select(
      (SendCubit cubit) => cubit.state.formattedConfirmedAmountBitcoin,
    );
    final formattedFiatEquivalent = context.select(
      (SendCubit cubit) => cubit.state.formattedConfirmedAmountFiat,
    );
    final hasFinalizedTx = context.select(
      (SendCubit cubit) => cubit.state.signedBitcoinTx != null,
    );
    // final selectedFees = context.select(
    //   (SendCubit cubit) => cubit.state.selectedFee,
    // );

    final selectedFeeOption = context.select(
      (SendCubit cubit) => cubit.state.selectedFeeOption,
    );
    final feePercent = context.select(
      (SendCubit cubit) => cubit.state.getFeeAsPercentOfAmount(),
    );
    final showFeeWarning = context.select(
      (SendCubit cubit) => cubit.state.showFeeWarning,
    );
    final formattedAbsoluteFees = context.select(
      (SendCubit cubit) => cubit.state.formattedAbsoluteFees,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          InfoRow(
            title: context.loc.sendFrom,
            details: BBText(
              selectedWallet!.displayLabel,
              style: context.font.bodyLarge,
              textAlign: .end,
            ),
          ),
          _divider(context),
          InfoRow(
            title: context.loc.sendTo,
            details: Row(
              mainAxisAlignment: .end,
              mainAxisSize: .min,
              children: [
                Expanded(
                  child: BBText(
                    paymentRequestAddress,
                    maxLines: 5,
                    style: context.font.bodyLarge,
                    textAlign: .end,
                  ),
                ),
                const Gap(8),
                InkWell(
                  child: Icon(
                    Icons.copy,
                    color: context.appColors.primary,
                    size: 16,
                  ),
                  onTap: () {
                    Clipboard.setData(
                      ClipboardData(text: paymentRequestAddress),
                    );
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
          InfoRow(
            title: context.loc.sendAmount,
            details: Column(
              crossAxisAlignment: .end,
              children: [
                BBText(formattedBitcoinAmount, style: context.font.bodyLarge),
                BBText(
                  '~$formattedFiatEquivalent',
                  style: context.font.labelSmall,
                  color: context.appColors.surfaceContainer,
                ),
              ],
            ),
          ),

          _divider(context),
          InfoRow(
            title: context.loc.sendNetworkFees,
            details: BBText(
              formattedAbsoluteFees,
              style: context.font.bodyLarge,
              textAlign: .end,
            ),
          ),
          if (!selectedWallet.isLiquid) ...[
            _divider(context),
            InfoRow(
              title: context.loc.sendFeePriority,
              details: InkWell(
                onTap: hasFinalizedTx
                    ? null
                    : () async {
                        final selected = await _showFeeOptions(context);

                        if (selected != null) {
                          final fee = FeeSelectionName.fromString(selected);
                          // ignore: use_build_context_synchronously
                          await context.read<SendCubit>().feeOptionSelected(
                            fee,
                          );
                        }
                      },
                child: Row(
                  mainAxisAlignment: .end,
                  children: [
                    BBText(
                      selectedFeeOption.title(),
                      style: context.font.bodyLarge,
                      color: context.appColors.primary,
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
          ],
          if (showFeeWarning == true) ...[
            const Gap(16),
            _HighFeeWarning(feePercent),
          ],
        ],
      ),
    );
  }

  Future<String?> _showFeeOptions(BuildContext context) async {
    final sendCubit = context.read<SendCubit>();

    final selected = await showModalBottomSheet<String>(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appColors.onSecondary,
      constraints: const BoxConstraints(maxWidth: double.infinity),
      builder: (BuildContext buildContext) =>
          BlocProvider.value(value: sendCubit, child: FeeOptionsModal()),
    );

    return selected;
  }
}

class _LnSwapSendInfoSection extends StatelessWidget {
  const _LnSwapSendInfoSection();
  Widget _divider(BuildContext context) {
    return Container(height: 1, color: context.appColors.secondaryFixedDim);
  }

  @override
  Widget build(BuildContext context) {
    final selectedWallet = context.select(
      (SendCubit cubit) => cubit.state.selectedWallet,
    );
    final paymentRequestAddress = context.select(
      (SendCubit cubit) => cubit.state.paymentRequestAddress,
    );
    final swap = context.select((SendCubit cubit) => cubit.state.lightningSwap);
    final paymentRequest = context.select(
      (SendCubit cubit) => cubit.state.paymentRequest,
    );
    final feePercent = context.select(
      (SendCubit cubit) => cubit.state.getFeeAsPercentOfAmount(),
    );
    final showFeeWarning = context.select(
      (SendCubit cubit) => cubit.state.showFeeWarning,
    );
    final isSlowPayment = context.select(
      (SendCubit cubit) => cubit.state.isSlowPayment,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          InfoRow(
            title: context.loc.sendFrom,
            details: BBText(
              selectedWallet!.displayLabel,
              style: context.font.bodyLarge,
              textAlign: .end,
            ),
          ),
          _divider(context),
          InfoRow(
            title: context.loc.sendSwapId,
            details: BBText(
              swap!.id,
              style: context.font.bodyLarge,
              textAlign: .end,
            ),
          ),
          _divider(context),
          InfoRow(
            title: context.loc.sendTo,
            details: Row(
              mainAxisAlignment: .end,
              mainAxisSize: .min,
              children: [
                Expanded(
                  child: BBText(
                    paymentRequest!.isLnAddress
                        ? paymentRequestAddress
                        : StringFormatting.truncateMiddle(
                            paymentRequestAddress,
                          ),
                    style: context.font.bodyLarge,
                    textAlign: .end,
                    maxLines: 10,
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
                    Clipboard.setData(
                      ClipboardData(text: paymentRequestAddress),
                    );
                  },
                ),
              ],
            ),
          ),
          _divider(context),

          if (swap.sendAmount != null)
            InfoRow(
              title: context.loc.sendSendAmount,
              details: Column(
                crossAxisAlignment: .end,
                children: [
                  CurrencyText(
                    swap.paymentAmount,
                    showFiat: false,
                    style: context.font.bodyLarge,
                  ),
                ],
              ),
            ),
          _divider(context),
          if (swap.receieveAmount != null)
            InfoRow(
              title: context.loc.sendReceiveAmount,
              details: Column(
                crossAxisAlignment: .end,
                children: [
                  CurrencyText(
                    swap.receieveAmount!,
                    showFiat: false,
                    style: context.font.bodyLarge,
                  ),
                ],
              ),
            ),
          if (swap.receieveAmount != null) _divider(context),
          if (swap.fees?.lockupFee != null)
            InfoRow(
              title: context.loc.sendNetworkFeesLabel,
              details: Column(
                crossAxisAlignment: .end,
                children: [
                  CurrencyText(
                    swap.fees!.lockupFee!,
                    showFiat: false,
                    style: context.font.bodyLarge,
                  ),
                ],
              ),
            ),
          if (swap.fees?.lockupFee != null) _divider(context),
          _SwapFeeBreakdown(fees: swap.fees),
          if (showFeeWarning == true) ...[
            const Gap(16),
            _HighFeeWarning(feePercent),
          ],
          if (isSlowPayment == true) ...[
            const Gap(8),
            const _SlowPaymentWarning(),
          ],
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
          BBText(
            label,
            style: context.font.bodySmall,
            color: context.appColors.surfaceContainer,
          ),
          const Spacer(),
          CurrencyText(
            amt,
            showFiat: false,
            style: context.font.bodySmall,
            color: context.appColors.surfaceContainer,
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
                  BBText(
                    context.loc.sendTransferFee,
                    style: context.font.bodySmall,
                    color: context.appColors.surfaceContainer,
                  ),
                  const Spacer(),
                  CurrencyText(
                    total,
                    showFiat: false,
                    style: context.font.bodyLarge,
                    color: context.appColors.outlineVariant,
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
                  child: BBText(
                    context.loc.sendTransferFeeDescription,
                    style: context.font.labelSmall,
                    color: context.appColors.surfaceContainer,
                  ),
                ),
                if (fees.claimFee != null)
                  _feeRow(context, context.loc.sendReceiveNetworkFee, fees.claimFee!),
                if (fees.serverNetworkFees != null)
                  _feeRow(
                    context,
                    context.loc.sendServerNetworkFees,
                    fees.serverNetworkFees!,
                  ),
                _feeRow(context, 'Transfer Fee', fees.boltzFee ?? 0),
                const Gap(4),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ChainSwapSendInfoSection extends StatelessWidget {
  const _ChainSwapSendInfoSection();
  Widget _divider(BuildContext context) {
    return Container(height: 1, color: context.appColors.secondaryFixedDim);
  }

  @override
  Widget build(BuildContext context) {
    final selectedWallet = context.select(
      (SendCubit cubit) => cubit.state.selectedWallet,
    );
    final paymentRequestAddress = context.select(
      (SendCubit cubit) => cubit.state.paymentRequestAddress,
    );
    final swap = context.select((SendCubit cubit) => cubit.state.chainSwap);
    final feePercent = context.select(
      (SendCubit cubit) => cubit.state.getFeeAsPercentOfAmount(),
    );
    final showFeeWarning = context.select(
      (SendCubit cubit) => cubit.state.showFeeWarning,
    );
    final absoluteFees = context.select(
      (SendCubit cubit) => cubit.state.absoluteFees,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          InfoRow(
            title: context.loc.sendFrom,
            details: BBText(
              selectedWallet!.displayLabel,
              style: context.font.bodyLarge,
              textAlign: .end,
            ),
          ),
          _divider(context),
          InfoRow(
            title: context.loc.sendSwapId,
            details: BBText(
              swap!.id,
              style: context.font.bodyLarge,
              textAlign: .end,
            ),
          ),
          _divider(context),
          InfoRow(
            title: context.loc.sendTo,
            details: Row(
              mainAxisAlignment: .end,
              mainAxisSize: .min,
              children: [
                Expanded(
                  child: BBText(
                    paymentRequestAddress,
                    style: context.font.bodyLarge,
                    textAlign: .end,
                    maxLines: 10,
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
                    Clipboard.setData(
                      ClipboardData(text: paymentRequestAddress),
                    );
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
          InfoRow(
            title: context.loc.sendSendAmount,
            details: Column(
              crossAxisAlignment: .end,
              children: [
                CurrencyText(
                  swap.sendAmount!,
                  showFiat: false,
                  style: context.font.bodyLarge,
                ),
              ],
            ),
          ),
          _divider(context),
          if (swap.receieveAmount != null)
            InfoRow(
              title: context.loc.sendReceiveAmount,
              details: Column(
                crossAxisAlignment: .end,
                children: [
                  CurrencyText(
                    swap.receieveAmount!,
                    showFiat: false,
                    style: context.font.bodyLarge,
                  ),
                ],
              ),
            ),
          if (swap.receieveAmount != null) _divider(context),
          if (absoluteFees != null)
            InfoRow(
              title: context.loc.sendSendNetworkFee,
              details: Column(
                crossAxisAlignment: .end,
                children: [
                  CurrencyText(
                    absoluteFees,
                    showFiat: false,
                    style: context.font.bodyLarge,
                  ),
                ],
              ),
            ),
          if (absoluteFees != null) _divider(context),
          _SwapFeeBreakdown(fees: swap.fees),
          const Gap(16),

          const _SlowPaymentWarning(),

          if (showFeeWarning == true) ...[
            const Gap(8),
            _HighFeeWarning(feePercent),
          ],
          _divider(context),
        ],
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.title, required this.details});

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
            color: context.appColors.surfaceContainer,
          ),
          const Gap(24),
          Expanded(child: details),
        ],
      ),
    );
  }
}

class SendConfirmTopArea extends StatelessWidget {
  const SendConfirmTopArea({super.key});

  @override
  Widget build(BuildContext context) {
    final amountBitcoin = context.select(
      (SendCubit cubit) => cubit.state.formattedConfirmedAmountBitcoin,
    );

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
          child: Image.asset(
            Assets.icons.rightArrow.path,
            height: 24,
            width: 24,
          ),
        ),
        const Gap(16),
        BBText(context.loc.sendConfirmSend, style: context.font.bodyMedium),
        const Gap(4),
        BBText(
          amountBitcoin,
          style: context.font.displaySmall,
          color: context.appColors.outlineVariant,
        ),
      ],
    );
  }
}

class SendSendingScreen extends StatelessWidget {
  const SendSendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isLnPaid = context.select(
      (SendCubit cubit) => cubit.state.isLnInvoicePaid,
    );
    final isLnSwap = context.select(
      (SendCubit cubit) => cubit.state.lightningSwap != null,
    );
    final isLiquid = context.select(
      (SendCubit cubit) => cubit.state.selectedWallet!.isLiquid,
    );

    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: const TopBar(title: 'Send'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Align(
          child: Column(
            children: [
              const Gap(192),
              Gif(
                autostart: Autostart.loop,
                height: 123,
                image: AssetImage(Assets.animations.cubesLoading.path),
              ),
              if (!isLnSwap) ...[
                const Gap(8),
                BBText(context.loc.sendSending, style: context.font.headlineLarge),
                const Gap(8),
                BBText(
                  context.loc.sendBroadcastingTransaction,
                  style: context.font.bodyMedium,
                  maxLines: 4,
                  textAlign: .center,
                ),
              ],
              if (isLnSwap && !isLnPaid) ...[
                const Gap(8),
                BBText(context.loc.sendSending, style: context.font.headlineLarge),
                const Gap(8),
                if (isLiquid)
                  BBText(
                    context.loc.sendSwapInProgressInvoice,
                    style: context.font.bodyMedium,
                    maxLines: 4,
                    textAlign: .center,
                  )
                else
                  BBText(
                    context.loc.sendSwapInProgressBitcoin,
                    style: context.font.bodyMedium,
                    maxLines: 4,
                    textAlign: .center,
                  ),
              ],
            ],
          ),
        ),
      ),

      // const Spacer(flex: 2),
      // BBButton.big(
      //   label: 'Go home',
      //   onPressed: () {},
      //   bgColor: context.colour.secondary,
      //   textColor: context.colour.onSecondary,
      // ),
    );
  }
}

class SendSucessScreen extends StatelessWidget {
  const SendSucessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final amount = context.select(
      (SendCubit cubit) => cubit.state.formattedConfirmedAmountBitcoin,
    );

    final fiatEquivalent = context.select(
      (SendCubit cubit) => cubit.state.formattedConfirmedAmountFiat,
    );

    final isBitcoin = context.select(
      (SendCubit cubit) => !cubit.state.selectedWallet!.isLiquid,
    );

    final walletTransaction = context.select(
      (SendCubit cubit) => cubit.state.walletTransaction,
    );
    final payjoin = context.select(
      (SendCubit cubit) => cubit.state.payjoinSender,
    );
    final lnSwap = context.select(
      (SendCubit cubit) => cubit.state.lightningSwap,
    );
    final chainSwap = context.select(
      (SendCubit cubit) => cubit.state.chainSwap,
    );
    final isLnSwap = lnSwap != null;
    final isChainSwap = chainSwap != null;
    final isSwap = isLnSwap || isChainSwap;

    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: context.loc.sendTitle,
          onBack: () => context.goNamed(WalletRoute.walletHome.name),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: .stretch,
          mainAxisAlignment: .center,
          children: [
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const Gap(8),
                  if (lnSwap?.status == SwapStatus.failed ||
                      lnSwap?.status == SwapStatus.expired ||
                      lnSwap?.status == SwapStatus.refundable ||
                      chainSwap?.status == SwapStatus.failed ||
                      chainSwap?.status == SwapStatus.expired ||
                      chainSwap?.status == SwapStatus.refundable) ...[
                    BBText(
                      context.loc.sendSwapRefundInProgress,
                      style: context.font.headlineLarge,
                      textAlign: .center,
                    ),
                    BBText(
                      context.loc.sendSwapFailed,
                      style: context.font.headlineLarge,
                      textAlign: .center,
                    ),
                  ] else if ((isLnSwap &&
                          lnSwap.status == SwapStatus.completed &&
                          lnSwap.refundTxid != null) ||
                      (isChainSwap &&
                          chainSwap.status == SwapStatus.completed &&
                          chainSwap.refundTxid != null)) ...[
                    BBText(
                      context.loc.sendSwapRefundCompleted,
                      style: context.font.headlineLarge,
                      textAlign: .center,
                    ),
                    BBText(
                      context.loc.sendRefundProcessed,
                      style: context.font.headlineLarge,
                      textAlign: .center,
                    ),
                  ] else if (isLnSwap && lnSwap.status == SwapStatus.canCoop ||
                      lnSwap?.status == SwapStatus.completed) ...[
                    Gif(
                      image: AssetImage(Assets.animations.successTick.path),
                      autostart: Autostart.once,
                      height: 100,
                      width: 100,
                    ),
                    const Gap(20),
                    BBText(context.loc.sendInvoicePaid, style: context.font.headlineLarge),
                  ] else if (isLnSwap &&
                      !isBitcoin &&
                      lnSwap.status != SwapStatus.canCoop &&
                      lnSwap.status != SwapStatus.completed)
                    BBText(
                      context.loc.sendPaymentProcessing,
                      style: context.font.headlineLarge,
                      textAlign: .center,
                    )
                  else if (isLnSwap && isBitcoin)
                    BBText(
                      context.loc.sendPaymentWillTakeTime,
                      style: context.font.headlineLarge,
                    )
                  else if (isChainSwap) ...[
                    BBText(context.loc.sendSwapInitiated, style: context.font.bodyLarge),
                    BBText(
                      context.loc.sendSwapWillTakeTime,
                      style: context.font.labelSmall,
                    ),
                  ] else
                    BBText(context.loc.sendSuccessfullySent, style: context.font.bodyLarge),
                  const Gap(8),
                  BBText(
                    amount,
                    style: context.font.displaySmall,
                    maxLines: 4,
                    textAlign: .center,
                  ),
                  const Gap(4),
                  BBText(
                    '~$fiatEquivalent',
                    style: context.font.bodyLarge,
                    color: context.appColors.surfaceContainer,
                    maxLines: 4,
                    textAlign: .center,
                  ),
                ],
              ),
            ),
            const Spacer(flex: 2),
            if (walletTransaction != null || isSwap || payjoin != null)
              BBButton.big(
                label: context.loc.sendViewDetails,
                onPressed: () {
                  if (walletTransaction != null) {
                    context.pushNamed(
                      TransactionsRoute.transactionDetails.name,
                      pathParameters: {'txId': walletTransaction.txId},
                      queryParameters: {'walletId': walletTransaction.walletId},
                    );
                  } else if (isLnSwap) {
                    context.pushNamed(
                      TransactionsRoute.swapTransactionDetails.name,
                      pathParameters: {'swapId': lnSwap.id},
                      queryParameters: {'walletId': lnSwap.walletId},
                    );
                  } else if (isChainSwap) {
                    context.pushNamed(
                      TransactionsRoute.swapTransactionDetails.name,
                      pathParameters: {'swapId': chainSwap.id},
                      queryParameters: {'walletId': chainSwap.walletId},
                    );
                  } else if (payjoin != null) {
                    context.pushNamed(
                      TransactionsRoute.payjoinTransactionDetails.name,
                      pathParameters: {'payjoinId': payjoin.id},
                    );
                  }
                },
                bgColor: context.appColors.secondary,
                textColor: context.appColors.onSecondary,
              ),
            const Gap(32),
          ],
        ),
      ),
    );
  }
}

class ShowPsbtButton extends StatelessWidget {
  const ShowPsbtButton({super.key});

  @override
  Widget build(BuildContext context) {
    final unsignedPsbt = context.select(
      (SendCubit cubit) => cubit.state.unsignedPsbt,
    );

    final signerDevice = context.select(
      (SendCubit cubit) => cubit.state.selectedWallet!.signerDevice,
    );

    return BBButton.big(
      label: context.loc.sendShowPsbt,
      onPressed: () {
        context.pushNamed(
          PsbtFlowRoutes.show.name,
          extra: (psbt: unsignedPsbt, signerDevice: signerDevice),
        );
      },
      bgColor: context.appColors.secondary,
      textColor: context.appColors.onSecondary,
    );
  }
}

class SignLedgerButton extends StatelessWidget {
  const SignLedgerButton({super.key});

  @override
  Widget build(BuildContext context) {
    final unsignedPsbt = context.select(
      (SendCubit cubit) => cubit.state.unsignedPsbt,
    );

    final derivationPath = context.select(
      (SendCubit cubit) => cubit.state.selectedWallet?.derivationPath,
    );

    final deviceType = context.select(
      (SendCubit cubit) => cubit.state.selectedWallet?.signerDevice,
    );

    final scriptType = context.select(
      (SendCubit cubit) => cubit.state.selectedWallet?.scriptType,
    );

    return BBButton.big(
      label: context.loc.sendSignWithLedger,
      onPressed: () async {
        if (unsignedPsbt == null) return;

        final result = await context.pushNamed<String>(
          LedgerRoute.ledgerSignTransaction.name,
          extra: LedgerRouteParams(
            psbt: unsignedPsbt,
            derivationPath: derivationPath,
            requestedDeviceType: deviceType,
            scriptType: scriptType,
          ),
        );

        if (result != null && context.mounted) {
          SnackBarUtils.showSnackBar(
            context,
            context.loc.sendTransactionSignedLedger,
          );
          // Update the signedBitcoinTx with the result from Ledger
          await context.read<SendCubit>().updateSignedBitcoinTx(result);
        }
      },
      bgColor: context.appColors.secondary,
      textColor: context.appColors.onSecondary,
    );
  }
}

class SignBitBoxButton extends StatelessWidget {
  const SignBitBoxButton({super.key});

  @override
  Widget build(BuildContext context) {
    final unsignedPsbt = context.select(
      (SendCubit cubit) => cubit.state.unsignedPsbt,
    );

    final derivationPath = context.select(
      (SendCubit cubit) => cubit.state.selectedWallet?.derivationPath,
    );

    final deviceType = context.select(
      (SendCubit cubit) => cubit.state.selectedWallet?.signerDevice,
    );

    final scriptType = context.select(
      (SendCubit cubit) => cubit.state.selectedWallet?.scriptType,
    );

    return BBButton.big(
      label: context.loc.sendSignWithBitBox,
      onPressed: () async {
        if (unsignedPsbt == null) return;

        final result = await context.pushNamed<String>(
          BitBoxRoute.bitboxSignTransaction.name,
          extra: BitBoxRouteParams(
            psbt: unsignedPsbt,
            derivationPath: derivationPath,
            requestedDeviceType: deviceType,
            scriptType: scriptType,
          ),
        );

        if (result != null && context.mounted) {
          final finalizedTx = await _finalizePsbt(result);
          if (context.mounted) {
            await context.read<SendCubit>().updateSignedBitcoinTx(finalizedTx);
          }
        }
      },
      bgColor: context.appColors.secondary,
      textColor: context.appColors.onSecondary,
    );
  }

  Future<String> _finalizePsbt(String signedPsbt) async {
    try {
      if (signedPsbt.startsWith('cHN')) {
        final psbt = Psbt.fromBase64(signedPsbt);
        final builder = PsbtBuilder.fromPsbt(psbt);
        return builder.finalizeAll().toHex();
      } else {
        return signedPsbt;
      }
    } catch (e) {
      log.warning('Failed to finalize PSBT');
      return signedPsbt;
    }
  }
}

/// Helper function to get localized error message for SwapLimitsException
String _getSwapLimitsErrorMessage(BuildContext context, SwapLimitsException error) {
  if (error.isBelowMinimum && error.minLimit != null) {
    return context.loc.sendErrorAmountBelowMinimum(error.minLimit.toString());
  } else if (error.isAboveMaximum && error.maxLimit != null) {
    return context.loc.sendErrorAmountAboveMaximum(error.maxLimit.toString());
  } else if (error.message.contains('Balance too low')) {
    return context.loc.sendErrorBalanceTooLowForMinimum;
  } else if (error.message.contains('exceeds maximum')) {
    return context.loc.sendErrorAmountExceedsMaximum;
  } else {
    return context.loc.sendErrorAmountBelowSwapLimits;
  }
}
