import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/utils/string_formatting.dart';
import 'package:bb_mobile/features/scan/scan_widget.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_state.dart';
import 'package:bb_mobile/features/send/ui/widgets/advanced_options_bottom_sheet.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/components/cards/info_card.dart';
import 'package:bb_mobile/ui/components/dialpad/dial_pad.dart';
import 'package:bb_mobile/ui/components/dropdown/selectable_list.dart';
import 'package:bb_mobile/ui/components/inputs/paste_input.dart';
import 'package:bb_mobile/ui/components/navbar/top_bar.dart';
import 'package:bb_mobile/ui/components/price_input/balance_row.dart';
import 'package:bb_mobile/ui/components/price_input/price_input.dart';
import 'package:bb_mobile/ui/components/segment/segmented_full.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
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
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: 'Send',
          color: context.colour.secondaryFixedDim,
          onBack: () => context.pop(),
        ),
      ),
      body: Center(
        child: Column(
          children: [
            Expanded(
              child: ScanWidget(
                onAddressDetected:
                    (address) =>
                        context.read<SendCubit>().addressChanged(address),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                alignment: Alignment.bottomCenter,
                // height: 250,
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
          ],
        ),
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

    final creatingSwap = context.select(
      (SendCubit cubit) => cubit.state.creatingSwap,
    );

    return BBButton.big(
      label: 'Continue',
      onPressed: () {
        context.read<SendCubit>().continueOnAddressConfirmed();
      },
      disabled: loadingBestWallet || creatingSwap,
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
      (cubit) => cubit.state.addressOrInvoice,
    );

    return PasteInput(
      text: address,
      onChanged: (text) => context.read<SendCubit>().addressChanged(text),
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
        ),
      );
    }
    if (swapError != null) {
      return BBText(
        swapError.message,
        style: context.font.bodyMedium,
        color: context.colour.error,
        textAlign: TextAlign.center,
      );
    }
    if (invalidAddress != null) {
      return BBText(
        invalidAddress.toString(),
        style: context.font.bodyMedium,
        color: context.colour.error,
        textAlign: TextAlign.center,
      );
    }
    return const SizedBox(height: 21);
  }
}

class SendAmountScreen extends StatelessWidget {
  const SendAmountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colour.onPrimary,
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(title: 'Send', onBack: () => context.pop()),
      ),
      body: BlocBuilder<SendCubit, SendState>(
        builder: (context, state) {
          final cubit = context.read<SendCubit>();
          final balanceError = context.select(
            (SendCubit cubit) => cubit.state.insufficientBalanceException,
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
          final inputCurrency = context.select(
            (SendCubit cubit) => cubit.state.inputAmountCurrencyCode,
          );

          final availableInputCurrencies = context
              .select<SendCubit, List<String>>(
                (bloc) => bloc.state.inputAmountCurrencyCodes,
              );

          final selectedWalletLabel = context.select(
            (SendCubit cubit) => cubit.state.selectedWallet!.label,
          );
          return IgnorePointer(
            ignoring: state.amountConfirmedClicked,
            child: Stack(
              children: [
                SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Gap(10),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: NetworkDisplay(),
                      ),
                      const Gap(48),
                      PriceInput(
                        amount: state.amount,
                        currency: inputCurrency,
                        amountEquivalent: state.formattedAmountInputEquivalent,
                        availableCurrencies: availableInputCurrencies,
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
                      ),
                      const Gap(64),
                      BalanceRow(
                        balance: state.formattedWalletBalance(),
                        currencyCode: '',
                        showMax: !isLightning,
                        onMaxPressed: cubit.onMaxPressed,
                        walletLabel: selectedWalletLabel,
                      ),
                      DialPad(
                        onNumberPressed: (number) {
                          final inputAmount =
                              context.read<SendCubit>().state.amount;
                          final amount = inputAmount + number;
                          context.read<SendCubit>().amountChanged(amount);
                        },
                        onBackspacePressed: () {
                          final inputAmount =
                              context.read<SendCubit>().state.amount;
                          if (inputAmount.isNotEmpty) {
                            final amount = inputAmount.substring(
                              0,
                              inputAmount.length - 1,
                            );
                            context.read<SendCubit>().amountChanged(amount);
                          }
                        },
                      ),
                      const Gap(64),
                    ],
                  ),
                ),
                const Align(
                  alignment: Alignment.bottomCenter,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Padding(
                        padding: EdgeInsets.all(16.0),
                        child: SendAmountConfirmButton(),
                      ),
                      Gap(16),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
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
          actionIcon: Icons.help_outline,
          onAction: () {},
          onBack: () => context.pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
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
            const Spacer(),
            // const _Warning(),
            const _ConfirmSendErrorSection(),
            const _BottomButtons(),
          ],
        ),
      ),
    );
  }
}

class _ConfirmSendErrorSection extends StatelessWidget {
  const _ConfirmSendErrorSection();

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
              buildError.title,
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
class _Warning extends StatelessWidget {
  const _Warning();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InfoCard(
        title: 'High fee warning',
        description: 'Network fee is over 3% of total transaction amount.',
        tagColor: context.colour.tertiary,
        bgColor: context.colour.tertiary.withAlpha(33),
      ),
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
    final addressOrInvoice = context.select(
      (SendCubit cubit) => cubit.state.addressOrInvoice,
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
    final absoluteFees = context.select(
      (SendCubit cubit) => cubit.state.absoluteFees,
    );
    final selectedFeeOption = context.select(
      (SendCubit cubit) => cubit.state.selectedFeeOption,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InfoRow(
            title: 'From',
            details: BBText(
              selectedWallet!.label,
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
                    addressOrInvoice,
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
                    Clipboard.setData(ClipboardData(text: addressOrInvoice));
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
              "${absoluteFees ?? 0} sats",
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
                  final selected = await _showFeeOptions(
                    context,
                    context.read<SendCubit>().state.selectedFeeOption!,
                    context.read<SendCubit>().state.bitcoinFeesList!,
                  );

                  if (selected != null) {
                    final fee = FeeSelectionName.fromString(selected);
                    // ignore: use_build_context_synchronously
                    context.read<SendCubit>().feeOptionSelected(fee);
                  }
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    BBText(
                      selectedFeeOption!.title(),
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
        ],
      ),
    );
  }

  Future<String?> _showFeeOptions(
    BuildContext context,
    FeeSelection selectedFeeOption,
    FeeOptions feeList,
  ) async {
    final fees = feeList.display(
      context.read<SendCubit>().state.bitcoinTxSize ?? 140,
      context.read<SendCubit>().state.exchangeRate,
      context.read<SendCubit>().state.fiatCurrencyCode,
    );
    final List<SelectableListItem> feeOptions = [
      for (final fee in fees)
        SelectableListItem(
          value: fee.$1,
          title: fee.$1,
          subtitle1: fee.$2,
          subtitle2: fee.$3,
        ),
    ];
    final selected = await showModalBottomSheet<String>(
      useRootNavigator: true,
      context: context,
      backgroundColor: context.colour.onSecondary,
      builder:
          (BuildContext buildContext) => Padding(
            padding: const EdgeInsets.all(16),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,

              children: [
                const Gap(16),

                BBText(
                  'Select network fee',
                  style: context.font.headlineMedium,
                ),
                const Gap(16),
                SelectableList(
                  selectedValue: selectedFeeOption.title(),
                  items: feeOptions,
                ),
                const Spacer(),
              ],
            ),
          ),
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
    final addressOrInvoice = context.select(
      (SendCubit cubit) => cubit.state.addressOrInvoice,
    );
    final formattedBitcoinAmount = context.select(
      (SendCubit cubit) => cubit.state.formattedConfirmedAmountBitcoin,
    );
    final formattedFiatEquivalent = context.select(
      (SendCubit cubit) => cubit.state.formattedConfirmedAmountFiat,
    );
    final swap = context.select((SendCubit cubit) => cubit.state.lightningSwap);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InfoRow(
            title: 'From',
            details: BBText(
              selectedWallet!.label,
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
                BBText(
                  StringFormatting.truncateMiddle(addressOrInvoice),
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
                    Clipboard.setData(ClipboardData(text: addressOrInvoice));
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
            title: 'Total fees',
            details: BBText(
              "${swap.fees?.totalFees(null)} sats",
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
    final addressOrInvoice = context.select(
      (SendCubit cubit) => cubit.state.addressOrInvoice,
    );
    final formattedBitcoinAmount = context.select(
      (SendCubit cubit) => cubit.state.formattedConfirmedAmountBitcoin,
    );
    final formattedFiatEquivalent = context.select(
      (SendCubit cubit) => cubit.state.formattedConfirmedAmountFiat,
    );
    final swap = context.select((SendCubit cubit) => cubit.state.chainSwap);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InfoRow(
            title: 'From',
            details: BBText(
              selectedWallet!.label,
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
                BBText(
                  StringFormatting.truncateMiddle(addressOrInvoice),
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
                    Clipboard.setData(ClipboardData(text: addressOrInvoice));
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
            title: 'Total fees',
            details: BBText(
              "${swap.fees?.totalFees(null)} sats",
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
        flexibleSpace: TopBar(
          title: 'Send',
          actionIcon: Icons.help_outline,
          onAction: () {},
        ),
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
                image: AssetImage(Assets.images2.cubesLoading.path),
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

    final isLnSwap = context.select(
      (SendCubit cubit) => cubit.state.lightningSwap != null,
    );
    final isBitcoin = context.select(
      (SendCubit cubit) => !cubit.state.selectedWallet!.isLiquid,
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
          actionIcon: Icons.close,
          onAction: context.pop,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const Gap(8),
                  if (isLnSwap && !isBitcoin)
                    BBText('Invoice Paid', style: context.font.headlineLarge)
                  else if (isLnSwap && isBitcoin)
                    BBText(
                      'Invoice Will Be Paid Shortly',
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
            BBButton.big(
              label: 'View Details',
              onPressed: () {},
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

class SendWarning extends StatelessWidget {
  const SendWarning({super.key});

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
