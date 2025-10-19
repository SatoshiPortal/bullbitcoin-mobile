// ignore_for_file: dead_code

import 'package:bb_mobile/core/screens/send_confirm_screen.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/core/widgets/inputs/amount_input_formatter.dart';
import 'package:bb_mobile/core/widgets/inputs/text_input.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/price_input/price_input.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/swap/presentation/swap_bloc.dart';
import 'package:bb_mobile/features/swap/presentation/swap_state.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:gif/gif.dart';
import 'package:go_router/go_router.dart';

enum _SwapCardType { pay, receive }

enum _SwapDropdownType { from, to }

class SwapFlow extends StatelessWidget {
  const SwapFlow({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => locator<SwapCubit>()..init(),
      child: const SwapPage(),
    );
  }
}

class SwapPage extends StatelessWidget {
  const SwapPage({super.key});

  @override
  Widget build(BuildContext context) {
    final step = context.select<SwapCubit, SwapPageStep>(
      (cubit) => cubit.state.step,
    );
    switch (step) {
      case SwapPageStep.amount:
        return const SwapAmountPage();
      case SwapPageStep.confirm:
        return const SwapConfirmPage();
      case SwapPageStep.progress:
        return const SwapProgressPage();
      case _:
        return const SizedBox.shrink();
    }
  }
}

class SwapAmountPage extends StatelessWidget {
  const SwapAmountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final amountConfirmedClicked = context.select(
      (SwapCubit cubit) => cubit.state.amountConfirmedClicked,
    );

    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: 'Internal Transfer',
          onBack: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            FadingLinearProgress(
              height: 3,
              trigger: amountConfirmedClicked,
              backgroundColor: context.colour.onPrimary,
              foregroundColor: context.colour.primary,
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Green info banner
                      Builder(
                        builder:
                            (context) => InfoCard(
                              description:
                                  'Transfer Bitcoin seamlessly between your wallets. Only keep funds in the Instant Payment Wallet is for day-to-day spending.',
                              tagColor: context.colour.inverseSurface,
                              bgColor: context.colour.inverseSurface.withValues(
                                alpha: 0.1,
                              ),
                            ),
                      ),
                      const Gap(12),
                      // Transfer From
                      const SwapFromToDropdown(type: _SwapDropdownType.from),

                      const Gap(12),
                      // Transfer To
                      const SwapFromToDropdown(type: _SwapDropdownType.to),
                      const Gap(12),
                      // Transfer Amount
                      const SwapTransferAmountField(),
                      const Gap(12),
                      const SwapAvailableBalance(),
                      const Gap(12),
                      const SwapFeesInformation(),
                      const Gap(12),
                      const SwapCreationError(),
                      const Gap(24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 10,
          ),
          child: const SwapContinueWithAmountButton(),
        ),
      ),
    );
  }
}

class SwapCard extends StatelessWidget {
  const SwapCard({super.key, required this.type});

  final _SwapCardType type;

  @override
  Widget build(BuildContext context) {
    final amount = context.select(
      (SwapCubit cubit) =>
          type == _SwapCardType.pay
              ? cubit.state.fromAmount
              : cubit.state.toAmount.split(' ')[0],
    );

    final conversionAmount = context.select(
      (SwapCubit cubit) =>
          type == _SwapCardType.pay
              ? cubit.state.formattedFromAmountEquivalent
              : cubit.state.formattedToAmountEquivalent,
    );

    final currency = context.select(
      (SwapCubit cubit) =>
          type == _SwapCardType.pay
              ? cubit.state.displayFromCurrencyCode
              : cubit.state.displayToCurrencyCode,
    );
    final availableCurrencies = context.select(
      (SwapCubit cubit) => cubit.state.inputAmountCurrencyCodes,
    );
    final loadingWallets = context.select(
      (SwapCubit cubit) => cubit.state.loadingWallets,
    );
    final amountConfirmedClicked = context.select(
      (SwapCubit cubit) => cubit.state.amountConfirmedClicked,
    );
    return Material(
      elevation: 2,
      child: Container(
        height: 138,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colour.onPrimary,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: context.colour.secondaryFixedDim),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BBText(
              'You ${type == _SwapCardType.pay ? 'Pay' : 'Receive'}',
              style: context.font.labelLarge,
              color: context.colour.outline,
            ),
            // const Spacer(),
            IgnorePointer(
              ignoring: type == _SwapCardType.receive || amountConfirmedClicked,
              child: Row(
                children: [
                  Expanded(
                    child: BBInputText(
                      disabled: loadingWallets || amountConfirmedClicked,
                      style: context.font.displaySmall,
                      value: amount,
                      hideBorder: true,
                      hint: '0',
                      hintStyle: context.font.displaySmall?.copyWith(
                        color: context.colour.outline,
                      ),
                      onlyNumbers: true,
                      maxLines: 1,
                      onChanged: (v) {
                        if (type == _SwapCardType.pay) {
                          context.read<SwapCubit>().amountChanged(v);
                        }
                      },
                    ),
                  ),
                  const Gap(8),
                  InkWell(
                    onTap:
                        amountConfirmedClicked
                            ? null
                            : () async {
                              final c = await showModalBottomSheet<String?>(
                                useRootNavigator: true,
                                context: context,
                                isScrollControlled: true,
                                backgroundColor:
                                    context.colour.secondaryFixedDim,
                                constraints: const BoxConstraints(
                                  maxWidth: double.infinity,
                                ),
                                builder: (context) {
                                  return CurrencyBottomSheet(
                                    availableCurrencies: availableCurrencies,
                                    selectedValue: currency,
                                  );
                                },
                              );
                              if (c == null) return;
                              // ignore: unawaited_futures, use_build_context_synchronously
                              context.read<SwapCubit>().currencyCodeChanged(c);
                            },
                    child: BBText(currency, style: context.font.displaySmall),
                  ),
                ],
              ),
            ),
            const Gap(4),
            if (amount == '0' || amount.isEmpty)
              const SizedBox.shrink()
            else
              BBText(conversionAmount, style: context.font.labelSmall),
          ],
        ),
      ),
    );
  }
}

class SwapTransferAmountField extends StatefulWidget {
  const SwapTransferAmountField({super.key});

  @override
  State<SwapTransferAmountField> createState() =>
      _SwapTransferAmountFieldState();
}

class _SwapTransferAmountFieldState extends State<SwapTransferAmountField> {
  late TextEditingController _controller;
  String _lastFromAmount = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fromAmount = context.select(
      (SwapCubit cubit) => cubit.state.fromAmount,
    );
    final toAmount = context.select(
      (SwapCubit cubit) => cubit.state.toAmount.split(' ')[0],
    );

    final currency = context.select(
      (SwapCubit cubit) => cubit.state.displayFromCurrencyCode,
    );
    final toCurrency = context.select(
      (SwapCubit cubit) => cubit.state.displayToCurrencyCode,
    );
    final loadingWallets = context.select(
      (SwapCubit cubit) => cubit.state.loadingWallets,
    );

    // Only update controller if fromAmount changed externally (not from user typing)
    if (fromAmount != _lastFromAmount && fromAmount != _controller.text) {
      _controller.text = fromAmount;
      _lastFromAmount = fromAmount;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText('Transfer amount', style: context.font.bodyLarge),
        const Gap(8),
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4.0),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 16.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (loadingWallets)
                  const LoadingLineContent(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _controller,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [AmountInputFormatter(currency)],
                          style: context.font.displaySmall?.copyWith(
                            color: context.colour.primary,
                          ),
                          decoration: InputDecoration(
                            hintText: '0',
                            hintStyle: context.font.displaySmall?.copyWith(
                              color: context.colour.primary,
                            ),
                            border: InputBorder.none,
                          ),
                          onChanged: (value) {
                            context.read<SwapCubit>().amountChanged(value);
                          },
                        ),
                      ),
                      const Gap(8.0),
                      Text(
                        currency,
                        style: context.font.displaySmall?.copyWith(
                          color: context.colour.primary,
                        ),
                      ),
                    ],
                  ),
                const Gap(16),
                if (loadingWallets)
                  const LoadingLineContent(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                  )
                else
                  Row(
                    children: [
                      InkWell(
                        onTap: () {
                          context.read<SwapCubit>().switchFromAndToWallets();
                        },
                        child: Icon(
                          Icons.swap_vert,
                          color: context.colour.outline,
                        ),
                      ),
                      const Gap(8.0),
                      Text(
                        '$toAmount $toCurrency',
                        style: context.font.bodyMedium?.copyWith(
                          color: context.colour.outline,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class SwapChangeButton extends StatelessWidget {
  const SwapChangeButton({super.key});

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select(
      (SwapCubit cubit) => cubit.state.loadingWallets,
    );
    return Material(
      elevation: 2,
      shadowColor: context.colour.secondary,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: context.colour.surface,
        ),
        child: IconButton(
          icon: const Icon(Icons.swap_vert),
          iconSize: 16,
          padding: EdgeInsets.zero,
          onPressed: () {
            if (isLoading) return;
            context.read<SwapCubit>().switchFromAndToWallets();
          },
        ),
      ),
    );
  }
}

class SwapAvailableBalance extends StatelessWidget {
  const SwapAvailableBalance({super.key});

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final balance = context.select(
      (SwapCubit cubit) => cubit.state.fromWalletBalance,
    );
    final formattedBalance = context.select(
      (SwapCubit cubit) => cubit.state.formattedFromWalletBalance(),
    );
    final loadingWallets = context.select(
      (SwapCubit cubit) => cubit.state.loadingWallets,
    );
    // const maxSelected = false;

    return Row(
      children: [
        BBText(
          'Available balance',
          style: context.font.labelLarge,
          color: context.colour.surface,
        ),
        const Gap(4),
        BBText(formattedBalance, style: context.font.labelLarge),
        const Spacer(),
        BBButton.small(
          label: 'MAX',
          height: 30,
          width: 51,
          bgColor: context.colour.secondaryFixedDim,
          textColor: context.colour.secondary,
          textStyle: context.font.labelLarge,
          disabled: context.select(
            (SwapCubit cubit) => loadingWallets || balance == 0,
          ),
          onPressed:
              () async => await context.read<SwapCubit>().sendMaxClicked(),
        ),
      ],
    );
  }
}

class SwapFeesInformation extends StatelessWidget {
  const SwapFeesInformation({super.key});

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final totalFees = context.select(
      (SwapCubit cubit) => cubit.state.estimatedFeesFormatted,
    );

    return Row(
      children: [
        BBText(
          'Total Fees ',
          style: context.font.labelLarge,
          color: context.colour.surface,
        ),
        const Gap(4),
        BBText(totalFees, style: context.font.labelLarge),
      ],
    );
  }
}

class SwapCreationError extends StatelessWidget {
  const SwapCreationError({super.key});

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final swapCreationError = context.select(
      (SwapCubit cubit) => cubit.state.swapCreationException,
    );
    final insuffientBalance = context.select(
      (SwapCubit cubit) => cubit.state.insufficientBalanceException,
    );
    final swapLimitsException = context.select(
      (SwapCubit cubit) => cubit.state.swapLimitsException,
    );

    if (swapLimitsException != null) {
      return BBText(
        swapLimitsException.message,
        style: context.font.labelLarge,
        color: context.colour.error,
        maxLines: 4,
      );
    }
    if (swapCreationError != null) {
      return BBText(
        swapCreationError.message,
        style: context.font.labelLarge,
        color: context.colour.error,
        maxLines: 4,
      );
    }
    if (insuffientBalance != null) {
      return BBText(
        insuffientBalance.message,
        style: context.font.labelLarge,
        color: context.colour.error,
        maxLines: 4,
      );
    } else {
      return const SizedBox.shrink();
    }
  }
}

class SwapFromToDropdown extends StatelessWidget {
  const SwapFromToDropdown({super.key, required this.type});

  final _SwapDropdownType type;

  @override
  Widget build(BuildContext context) {
    final items = context.select(
      (SwapCubit cubit) =>
          type == _SwapDropdownType.from
              ? cubit.state.fromWalletDropdownItems
              : cubit.state.toWalletDropdownItems,
    );
    final id = context.select(
      (SwapCubit cubit) =>
          type == _SwapDropdownType.from
              ? cubit.state.fromWalletId
              : cubit.state.toWalletId,
    );

    final dropdownItems =
        items
            .map(
              (item) => DropdownMenuItem(
                value: item.id,
                child: BBText(item.label, style: context.font.headlineSmall),
              ),
            )
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BBText(
          'Transfer ${type == _SwapDropdownType.from ? 'from' : 'to'}',
          style: context.font.bodyLarge,
        ),
        const Gap(4),
        SizedBox(
          height: 56,
          child: Material(
            elevation: 4,
            color: context.colour.onPrimary,
            borderRadius: BorderRadius.circular(4.0),
            child: Center(
              child:
                  items.isEmpty
                      ? const LoadingLineContent()
                      : DropdownButtonFormField(
                        value: id,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16.0,
                          ),
                        ),
                        icon: Icon(
                          Icons.keyboard_arrow_down,
                          color: context.colour.secondary,
                        ),
                        items: dropdownItems,
                        onChanged: (value) {
                          if (value != null) {
                            type == _SwapDropdownType.from
                                ? context
                                    .read<SwapCubit>()
                                    .updateSelectedFromWallet(value)
                                : context
                                    .read<SwapCubit>()
                                    .updateSelectedToWallet(value);
                          }
                        },
                      ),
            ),
          ),
        ),
      ],
    );
  }
}

class SwapContinueWithAmountButton extends StatelessWidget {
  const SwapContinueWithAmountButton({super.key});

  @override
  Widget build(BuildContext context) {
    final disableContinueWithAmounts = context.select(
      (SwapCubit cubit) => cubit.state.disableContinueWithAmounts,
    );

    return BBButton.big(
      label: 'Continue',
      bgColor: context.colour.secondary,
      textColor: context.colour.onSecondary,
      disabled: disableContinueWithAmounts,
      onPressed: () {
        if (disableContinueWithAmounts) return;
        context.read<SwapCubit>().continueWithAmountsClicked();
      },
    );
  }
}

class SwapConfirmPage extends StatelessWidget {
  const SwapConfirmPage({super.key});

  @override
  Widget build(BuildContext context) {
    final formattedConfirmedAmountBitcoin = context.select(
      (SwapCubit cubit) => cubit.state.formattedConfirmedAmountBitcoin,
    );
    final sendWalletLabel = context.select(
      (SwapCubit cubit) => cubit.state.fromWalletLabel,
    );
    final receiveWalletLabel = context.select(
      (SwapCubit cubit) => cubit.state.toWalletLabel,
    );
    final swap = context.select((SwapCubit cubit) => cubit.state.swap);
    final buildError = context.select(
      (SwapCubit cubit) => cubit.state.buildTransactionException,
    );
    final confirmError = context.select(
      (SwapCubit cubit) => cubit.state.confirmTransactionException,
    );
    final sendNetwork = context.select(
      (SwapCubit cubit) => cubit.state.fromWalletNetwork,
    );
    context.select((SwapCubit cubit) => cubit.state.estimatedFeesFormatted);
    final disableSendSwapButton = context.select(
      (SwapCubit cubit) => cubit.state.disableSendSwapButton,
    );
    final absoluteFeesFormatted = context.select(
      (SwapCubit cubit) => cubit.state.absoluteFeesFormatted,
    );
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: 'Confirm Transfer',
          onBack: () => context.pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Gap(24),
            CommonSendConfirmTopArea(
              formattedConfirmedAmountBitcoin: formattedConfirmedAmountBitcoin,
              sendType: SendType.swap,
            ),
            const Gap(40),
            CommonChainSwapSendInfoSection(
              sendWalletLabel: sendWalletLabel,
              receiveWalletLabel: receiveWalletLabel,
              formattedBitcoinAmount: formattedConfirmedAmountBitcoin,
              swap: swap!,
              absoluteFeesFormatted: absoluteFeesFormatted,
            ),
            const Spacer(),
            // const _Warning(),
            CommonConfirmSendErrorSection(
              confirmError: confirmError,
              buildError: buildError,
            ),

            CommonSendBottomButtons(
              isBitcoinWallet: sendNetwork == WalletNetwork.bitcoin,
              blocProviderValue: context.read<SwapCubit>(),
              onSendPressed: () {
                context.read<SwapCubit>().confirmSwapClicked();
              },
              disableSendButton: disableSendSwapButton,
            ),
          ],
        ),
      ),
    );
  }
}

class SwapProgressPage extends StatelessWidget {
  const SwapProgressPage({super.key});

  @override
  Widget build(BuildContext context) {
    final swap = context.select((SwapCubit cubit) => cubit.state.swap!);

    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: const TopBar(title: 'Internal Transfer'),
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
                  if (swap.status == SwapStatus.pending ||
                      swap.status == SwapStatus.paid) ...[
                    Gif(
                      autostart: Autostart.loop,
                      height: 123,
                      image: AssetImage(Assets.animations.cubesLoading.path),
                    ),
                    const Gap(8),
                    BBText(
                      'Transfer Pending',
                      style: context.font.headlineLarge,
                    ),
                    const Gap(8),
                    BBText(
                      'The transfer is in progress. Bitcoin transactions can take a while to confirm. You can return home and wait.',
                      style: context.font.bodyMedium,
                      maxLines: 4,
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (swap.status == SwapStatus.completed &&
                      swap.refundTxid == null) ...[
                    BBText(
                      'Transfer completed',
                      style: context.font.headlineLarge,
                    ),
                    const Gap(8),
                    BBText(
                      'Wow, you waited! The transfer has completed sucessfully.',
                      style: context.font.bodyMedium,
                      maxLines: 4,
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (swap.status == SwapStatus.refundable) ...[
                    BBText(
                      'Transfer Refund In Progress',
                      style: context.font.headlineLarge,
                    ),
                    const Gap(8),
                    BBText(
                      'There was an error with the transfer. Your refund is in progress.',
                      style: context.font.bodyMedium,
                      maxLines: 4,
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (swap.status == SwapStatus.completed &&
                      swap.refundTxid != null) ...[
                    BBText(
                      'Transfer Refunded',
                      style: context.font.headlineLarge,
                    ),
                    const Gap(8),
                    BBText(
                      'The transfer has been sucessfully refunded.',
                      style: context.font.bodyMedium,
                      maxLines: 4,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),

            const Spacer(flex: 2),
            BBButton.big(
              label: 'Go home',
              onPressed: () => context.pop(),
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
