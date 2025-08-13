import 'dart:math' as math;

import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
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
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:bb_mobile/features/psbt_flow/psbt_router.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_state.dart';
import 'package:bb_mobile/features/send/ui/screens/open_the_camera_widget.dart';
import 'package:bb_mobile/features/send/ui/widgets/advanced_options_bottom_sheet.dart';
import 'package:bb_mobile/features/send/ui/widgets/fee_options_modal.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
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
      backgroundColor: context.colour.secondaryFixedDim,
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: 'Send',
          color: context.colour.secondaryFixedDim,
          onBack: () => context.pop(),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            children: [
              FadingLinearProgress(
                height: 3,
                trigger: context.select(
                  (SendCubit cubit) =>
                      cubit.state.loadingBestWallet || cubit.state.creatingSwap,
                ),
                backgroundColor: context.colour.onPrimary,
                foregroundColor: context.colour.primary,
              ),
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.5,
                      child: OpenTheCameraWidget(
                        onScannedPaymentRequest:
                            (data) => context
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
                            color: context.colour.onPrimary,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Gap(32),
                              BBText(
                                "Recipient's address",
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
      label: 'Continue',
      onPressed: () {
        context.read<SendCubit>().continueOnAddressConfirmed();
      },
      disabled: !isValidPaymentRequest || loadingBestWallet || creatingSwap,
      bgColor: context.colour.secondary,
      textColor: context.colour.onPrimary,
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
      hint: 'Paste a payment address or invoice',
      hintStyle: context.font.bodyLarge?.copyWith(
        color: context.colour.surfaceContainer,
      ),
      maxLines: 1,
      rightIcon: Icon(
        Icons.paste_sharp,
        color: context.colour.secondary,
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
          balanceError.message,
          style: context.font.bodyMedium,
          color: context.colour.error,
          textAlign: TextAlign.center,
          maxLines: 2,
        ),
      );
    }
    if (swapError != null) {
      return BBText(
        swapError.message,
        style: context.font.bodyMedium,
        color: context.colour.error,
        textAlign: TextAlign.center,
        maxLines: 2,
      );
    }
    if (invalidAddress != null) {
      return BBText(
        invalidAddress.toString(),
        style: context.font.bodyMedium,
        color: context.colour.error,
        textAlign: TextAlign.center,
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

  @override
  void initState() {
    super.initState();
    final displayAmount = context.read<SendCubit>().state.displayAmount;
    _amountController = TextEditingController.fromValue(
      TextEditingValue(
        text: displayAmount,
        selection: TextSelection.collapsed(offset: displayAmount.length),
      ),
    );
    _amountFocusNode = FocusNode();
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
      backgroundColor: context.colour.onPrimary,
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: 'Send',
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
            backgroundColor: context.colour.onPrimary,
            foregroundColor: context.colour.primary,
          ),
          Expanded(
            child: BlocListener<SendCubit, SendState>(
              listenWhen:
                  (previous, current) =>
                      previous.displayAmount != current.displayAmount &&
                      _amountController.text != current.displayAmount,
              listener: (context, state) {
                final displayAmount = state.displayAmount;
                final currentCursor = _amountController.selection.baseOffset;
                final safePosition = math.min(
                  currentCursor,
                  displayAmount.length,
                );

                _amountController.value = TextEditingValue(
                  text: displayAmount,
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
                          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                context.read<SendCubit>().onCurrencyChanged(
                                  currencyCode,
                                );
                              },
                              error:
                                  balanceError != null
                                      ? balanceError.toString()
                                      : !walletHasBalance
                                      ? 'Insufficient balance'
                                      : swapLimitsError != null
                                      ? swapLimitsError.toString()
                                      : swapCreationError?.toString(),
                              focusNode: _amountFocusNode,
                              readOnly: state.sendMax,
                            ),
                            const Gap(48),
                            Divider(
                              height: 1,
                              color: context.colour.secondaryFixedDim,
                            ),
                            BalanceRow(
                              balance: state.formattedWalletBalance(),
                              currencyCode: '',
                              showMax: !isLightning && !isChainSwap,
                              onMaxPressed: cubit.onMaxPressed,
                              walletLabel: selectedWalletLabel,
                            ),
                            DialPad(
                              onNumberPressed: (number) async {
                                if (!_amountFocusNode.hasFocus) {
                                  _amountFocusNode.requestFocus();

                                  final currentText = _amountController.text;
                                  _amountController
                                      .selection = TextSelection.collapsed(
                                    offset: currentText.length,
                                  );
                                }

                                final inputAmount =
                                    context.read<SendCubit>().state.amount;

                                final selection = _amountController.selection;
                                final cursorPosition = selection.baseOffset
                                    .clamp(0, inputAmount.length);
                                final endPosition = selection.extentOffset
                                    .clamp(0, inputAmount.length);

                                String newAmount;
                                int newCursorPosition;

                                if (cursorPosition == endPosition) {
                                  newAmount =
                                      inputAmount.substring(0, cursorPosition) +
                                      number +
                                      inputAmount.substring(cursorPosition);
                                  newCursorPosition = cursorPosition + 1;
                                } else {
                                  final start = math.min(
                                    cursorPosition,
                                    endPosition,
                                  );
                                  final end = math.max(
                                    cursorPosition,
                                    endPosition,
                                  );
                                  newAmount =
                                      inputAmount.substring(0, start) +
                                      number +
                                      inputAmount.substring(end);
                                  newCursorPosition = start + 1;
                                }

                                final targetCursorPosition = newCursorPosition;

                                await context.read<SendCubit>().amountChanged(
                                  newAmount,
                                );

                                _amountController.value = TextEditingValue(
                                  text: newAmount,
                                  selection: TextSelection.collapsed(
                                    offset: targetCursorPosition,
                                  ),
                                );
                              },
                              onBackspacePressed: () async {
                                if (!_amountFocusNode.hasFocus) {
                                  _amountFocusNode.requestFocus();

                                  final currentText = _amountController.text;
                                  _amountController
                                      .selection = TextSelection.collapsed(
                                    offset: currentText.length,
                                  );
                                }

                                final inputAmount =
                                    context.read<SendCubit>().state.amount;
                                if (inputAmount.isEmpty) return;

                                final selection = _amountController.selection;
                                final cursorPosition = selection.baseOffset
                                    .clamp(0, inputAmount.length);
                                final endPosition = selection.extentOffset
                                    .clamp(0, inputAmount.length);

                                String newAmount;
                                int newCursorPosition;

                                if (cursorPosition == endPosition) {
                                  if (cursorPosition > 0) {
                                    newAmount =
                                        inputAmount.substring(
                                          0,
                                          cursorPosition - 1,
                                        ) +
                                        inputAmount.substring(cursorPosition);
                                    newCursorPosition = cursorPosition - 1;
                                  } else {
                                    return;
                                  }
                                } else {
                                  final start = math.min(
                                    cursorPosition,
                                    endPosition,
                                  );
                                  final end = math.max(
                                    cursorPosition,
                                    endPosition,
                                  );
                                  newAmount =
                                      inputAmount.substring(0, start) +
                                      inputAmount.substring(end);
                                  newCursorPosition = start;
                                }

                                // Store the intended cursor position before updating state
                                final targetCursorPosition = newCursorPosition;

                                // Update state first
                                await context.read<SendCubit>().amountChanged(
                                  newAmount,
                                );

                                // Then update controller with the stored cursor position
                                _amountController.value = TextEditingValue(
                                  text: newAmount,
                                  selection: TextSelection.collapsed(
                                    offset: targetCursorPosition,
                                  ),
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
    return BBButton.big(
      label: 'Continue',
      onPressed: () {
        context.read<SendCubit>().onAmountConfirmed();
      },
      disabled:
          amountConfirmedClicked ||
          !hasBalance ||
          creatingSwap ||
          loadingBestWallet,
      bgColor: context.colour.secondary,
      textColor: context.colour.onPrimary,
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
          title: 'Send',
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
            backgroundColor: context.colour.onPrimary,
            foregroundColor: context.colour.primary,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Gap(24),
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
              'Could Not Build Transaction',
              style: context.font.bodyLarge,
              color: context.colour.error,
              maxLines: 5,
              textAlign: TextAlign.center,
            ),
            const Gap(8),
            BBText(
              buildError.message,
              style: context.font.bodyMedium,
              color: context.colour.error,
              maxLines: 5,
              textAlign: TextAlign.center,
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
              confirmError.title,
              style: context.font.bodyLarge,
              color: context.colour.error,
              maxLines: 5,
              textAlign: TextAlign.center,
            ),
            const Gap(8),
            BBText(
              confirmError.message,
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

// ignore: unused_element
class _HighFeeWarning extends StatelessWidget {
  final double feePercent;
  const _HighFeeWarning(this.feePercent);

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      title: 'High fee warning',
      description:
          'Total fee is ${feePercent.toStringAsFixed(2)}% of the amount you are sending',
      tagColor: context.colour.onError,
      bgColor: context.colour.secondaryFixed,
    );
  }
}

class _SlowPaymentWarning extends StatelessWidget {
  const _SlowPaymentWarning();

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      title: 'Slow Payment Warning',
      description: 'Bitcoin swaps will take time to confirm.',
      tagColor: context.colour.onError,
      bgColor: context.colour.secondaryFixed,
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isBitcoinWallet) ...[
            BBButton.big(
              label: 'Advanced Settings',
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: context.colour.secondaryFixed,
                  constraints: const BoxConstraints(maxWidth: double.infinity),
                  builder:
                      (BuildContext buildContext) => BlocProvider.value(
                        value: context.read<SendCubit>(),
                        child: const AdvancedOptionsBottomSheet(),
                      ),
                );
              },
              borderColor: context.colour.secondary,
              outlined: true,
              bgColor: Colors.transparent,
              textColor: context.colour.secondary,
            ),
            const Gap(12),
          ],
          if (wallet != null && wallet.signsRemotely)
            const ShowPsbtButton()
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
    final disableSendButton = context.select(
      (SendCubit cubit) => cubit.state.disableConfirmSend,
    );
    return BBButton.big(
      label: 'Confirm',
      onPressed: () {
        context.read<SendCubit>().onConfirmTransactionClicked();
      },
      bgColor: context.colour.secondary,
      textColor: context.colour.onSecondary,
      disabled: disableSendButton,
    );
  }
}

class _OnchainSendInfoSection extends StatelessWidget {
  const _OnchainSendInfoSection();
  Widget _divider(BuildContext context) {
    return Container(height: 1, color: context.colour.secondaryFixedDim);
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InfoRow(
            title: 'From',
            details: BBText(
              selectedWallet!.displayLabel,
              style: context.font.bodyLarge,
              textAlign: TextAlign.end,
            ),
          ),
          _divider(context),
          InfoRow(
            title: 'To',
            details: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: BBText(
                    paymentRequestAddress,
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
            title: 'Amount',
            details: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                BBText(formattedBitcoinAmount, style: context.font.bodyLarge),
                BBText(
                  '~$formattedFiatEquivalent',
                  style: context.font.labelSmall,
                  color: context.colour.surfaceContainer,
                ),
              ],
            ),
          ),

          _divider(context),
          InfoRow(
            title: 'Network fees',
            details: BBText(
              formattedAbsoluteFees,
              style: context.font.bodyLarge,
              textAlign: TextAlign.end,
            ),
          ),
          if (!selectedWallet.isLiquid) ...[
            _divider(context),
            InfoRow(
              title: 'Fee Priority',
              details: InkWell(
                onTap: () async {
                  final selected = await _showFeeOptions(context);

                  if (selected != null) {
                    final fee = FeeSelectionName.fromString(selected);
                    // ignore: use_build_context_synchronously
                    await context.read<SendCubit>().feeOptionSelected(fee);
                  }
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    BBText(
                      selectedFeeOption.title(),
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
      backgroundColor: context.colour.onSecondary,
      constraints: const BoxConstraints(maxWidth: double.infinity),
      builder:
          (BuildContext buildContext) =>
              BlocProvider.value(value: sendCubit, child: FeeOptionsModal()),
    );

    return selected;
  }
}

class _LnSwapSendInfoSection extends StatelessWidget {
  const _LnSwapSendInfoSection();
  Widget _divider(BuildContext context) {
    return Container(height: 1, color: context.colour.secondaryFixedDim);
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InfoRow(
            title: 'From',
            details: BBText(
              selectedWallet!.displayLabel,
              style: context.font.bodyLarge,
              textAlign: TextAlign.end,
            ),
          ),
          _divider(context),
          InfoRow(
            title: 'Swap ID',
            details: BBText(
              swap!.id,
              style: context.font.bodyLarge,
              textAlign: TextAlign.end,
            ),
          ),
          _divider(context),
          InfoRow(
            title: 'To',
            details: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: BBText(
                    paymentRequest!.isLnAddress
                        ? paymentRequestAddress
                        : StringFormatting.truncateMiddle(
                          paymentRequestAddress,
                        ),
                    style: context.font.bodyLarge,
                    textAlign: TextAlign.end,
                    maxLines: 10,
                  ),
                ),
                const Gap(4),
                InkWell(
                  child: Icon(
                    Icons.copy,
                    color: context.colour.primary,
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
          InfoRow(
            title: 'Amount',
            details: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                BBText(formattedBitcoinAmount, style: context.font.bodyLarge),
                BBText(
                  '~$formattedFiatEquivalent',
                  style: context.font.labelSmall,
                  color: context.colour.surfaceContainer,
                ),
              ],
            ),
          ),
          _divider(context),
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
            color: context.colour.surfaceContainer,
          ),
          const Spacer(),
          CurrencyText(
            amt,
            showFiat: false,
            style: context.font.bodySmall,
            color: context.colour.surfaceContainer,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fees = widget.fees;
    final total = fees?.totalFees(null) ?? 0;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: InkWell(
              splashColor: Colors.transparent,
              splashFactory: NoSplash.splashFactory,
              highlightColor: Colors.transparent,
              onTap: () {
                setState(() {
                  expanded = !expanded;
                });
              },
              child: Row(
                children: [
                  BBText(
                    'Swap Fees',
                    style: context.font.bodySmall,
                    color: context.colour.surfaceContainer,
                  ),
                  const Spacer(),
                  CurrencyText(
                    total,
                    showFiat: false,
                    style: context.font.bodyLarge,
                    color: context.colour.outlineVariant,
                  ),
                  const Gap(4),
                  Icon(
                    expanded ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                    color: context.colour.primary,
                  ),
                ],
              ),
            ),
          ),
          const Gap(12),
          if (expanded && fees != null) ...[
            Container(color: context.colour.surface, height: 1),
            Column(
              children: [
                const Gap(4),

                _feeRow(
                  context,
                  'Network Fee',
                  fees.lockupFee! + fees.claimFee!,
                ),
                _feeRow(context, 'Boltz Swap Fee', fees.boltzFee ?? 0),
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
    return Container(height: 1, color: context.colour.secondaryFixedDim);
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
    final swap = context.select((SendCubit cubit) => cubit.state.chainSwap);
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InfoRow(
            title: 'From',
            details: BBText(
              selectedWallet!.displayLabel,
              style: context.font.bodyLarge,
              textAlign: TextAlign.end,
            ),
          ),
          _divider(context),
          InfoRow(
            title: 'Swap ID',
            details: BBText(
              swap!.id,
              style: context.font.bodyLarge,
              textAlign: TextAlign.end,
            ),
          ),
          _divider(context),
          InfoRow(
            title: 'To',
            details: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: BBText(
                    paymentRequestAddress,
                    style: context.font.bodyLarge,
                    textAlign: TextAlign.end,
                    maxLines: 10,
                  ),
                ),
                const Gap(4),
                InkWell(
                  child: Icon(
                    Icons.copy,
                    color: context.colour.primary,
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
            title: 'Amount',
            details: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                BBText(formattedBitcoinAmount, style: context.font.bodyLarge),
                BBText(
                  '~$formattedFiatEquivalent',
                  style: context.font.labelSmall,
                  color: context.colour.surfaceContainer,
                ),
              ],
            ),
          ),
          _divider(context),
          InfoRow(
            title: 'Send Network Fee',
            details: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                BBText(formattedAbsoluteFees, style: context.font.bodyLarge),
              ],
            ),
          ),
          _divider(context),
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
            color: context.colour.surfaceContainer,
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
          child: Image.asset(
            Assets.icons.rightArrow.path,
            height: 24,
            width: 24,
          ),
        ),
        const Gap(16),
        BBText('Confirm Send', style: context.font.bodyMedium),
        const Gap(4),
        BBText(
          amountBitcoin,
          style: context.font.displaySmall,
          color: context.colour.outlineVariant,
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
                BBText('Sending', style: context.font.headlineLarge),
                const Gap(8),
                BBText(
                  'Broadcasting the transaction.',
                  style: context.font.bodyMedium,
                  maxLines: 4,
                  textAlign: TextAlign.center,
                ),
              ],
              if (isLnSwap && !isLnPaid) ...[
                const Gap(8),
                BBText('Sending', style: context.font.headlineLarge),
                const Gap(8),
                if (isLiquid)
                  BBText(
                    'The swap is in progress. The invoice will be paid in a few seconds.',
                    style: context.font.bodyMedium,
                    maxLines: 4,
                    textAlign: TextAlign.center,
                  )
                else
                  BBText(
                    'The swap is in progress. Bitcoin transactions can take a while to confirm. You can return home and wait.',
                    style: context.font.bodyMedium,
                    maxLines: 4,
                    textAlign: TextAlign.center,
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
          title: 'Send',
          onBack: () => context.goNamed(WalletRoute.walletHome.name),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
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
                      'Swap Refund In Progress',
                      style: context.font.headlineLarge,
                      textAlign: TextAlign.center,
                    ),
                    BBText(
                      'The swap failed. Your refund will be processed shortly.',
                      style: context.font.headlineLarge,
                      textAlign: TextAlign.center,
                    ),
                  ] else if ((isLnSwap &&
                          lnSwap.status == SwapStatus.completed &&
                          lnSwap.refundTxid != null) ||
                      (isChainSwap &&
                          chainSwap.status == SwapStatus.completed &&
                          chainSwap.refundTxid != null)) ...[
                    BBText(
                      'Swap Refund Completed',
                      style: context.font.headlineLarge,
                      textAlign: TextAlign.center,
                    ),
                    BBText(
                      'Your refund has been processed.',
                      style: context.font.headlineLarge,
                      textAlign: TextAlign.center,
                    ),
                  ] else if (isLnSwap &&
                      (lnSwap.status == SwapStatus.completed ||
                          lnSwap.status == SwapStatus.canCoop))
                    BBText('Invoice Paid', style: context.font.headlineLarge)
                  else if (isLnSwap &&
                      !isBitcoin &&
                      (lnSwap.status != SwapStatus.completed &&
                          lnSwap.status != SwapStatus.canCoop))
                    BBText(
                      'The payment is being processed. It may take up to a minute',
                      style: context.font.headlineLarge,
                      textAlign: TextAlign.center,
                    )
                  else if (isLnSwap && isBitcoin)
                    BBText(
                      'Payment Will Take Time',
                      style: context.font.headlineLarge,
                    )
                  else if (isChainSwap) ...[
                    BBText('Swap Initiated', style: context.font.bodyLarge),
                    BBText(
                      'It will take a while to confirm',
                      style: context.font.labelSmall,
                    ),
                  ] else
                    BBText('Successfully Sent', style: context.font.bodyLarge),
                  const Gap(8),
                  BBText(
                    amount,
                    style: context.font.displaySmall,
                    maxLines: 4,
                    textAlign: TextAlign.center,
                  ),
                  const Gap(4),
                  BBText(
                    '~$fiatEquivalent',
                    style: context.font.bodyLarge,
                    color: context.colour.surfaceContainer,
                    maxLines: 4,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const Spacer(flex: 2),
            if (walletTransaction != null || isSwap || payjoin != null)
              BBButton.big(
                label: 'View Details',
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
                bgColor: context.colour.secondary,
                textColor: context.colour.onSecondary,
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

    return BBButton.big(
      label: 'Show PSBT',
      onPressed: () {
        context.pushNamed(PsbtFlowRoutes.show.name, extra: unsignedPsbt);
      },
      bgColor: context.colour.secondary,
      textColor: context.colour.onSecondary,
    );
  }
}
