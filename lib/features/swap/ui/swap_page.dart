// ignore_for_file: dead_code

import 'package:bb_mobile/features/swap/presentation/swap_bloc.dart';
import 'package:bb_mobile/features/swap/presentation/swap_state.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/components/inputs/text_input.dart';
import 'package:bb_mobile/ui/components/navbar/top_bar.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/screens/send_confirm_screen.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
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
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: 'Swap',
          color: context.colour.secondaryFixedDim,
          onBack: () => context.pop(),
        ),
      ),
      body: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwapFromToDropdown(type: _SwapDropdownType.from),
            Gap(16),
            SwapAvailableBalance(),
            Gap(16),
            SizedBox(
              height: 135 * 2,
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: SwapCard(type: _SwapCardType.pay),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SwapCard(type: _SwapCardType.receive),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: SwapChangeButton(),
                  ),
                ],
              ),
            ),
            Gap(16),
            SwapFeesInformation(),
            Gap(32),
            SwapFromToDropdown(type: _SwapDropdownType.to),
            Gap(32),
            SwapCreationError(),
            Spacer(),
            SwapContinueWithAmountButton(),
          ],
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
              : cubit.state.formattedToAmount,
    );

    final conversionAmount = context.select(
      (SwapCubit cubit) =>
          type == _SwapCardType.pay
              ? cubit.state.formattedFromAmountEquivalent
              : cubit.state.formattedToAmountEquivalent,
    );

    return Material(
      elevation: 2,
      child: Container(
        height: 130,
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
            const Spacer(),
            IgnorePointer(
              ignoring: type == _SwapCardType.receive,
              child: BBInputText(
                style: context.font.headlineMedium,
                value: amount,
                onChanged: (v) {
                  if (type == _SwapCardType.pay) {
                    context.read<SwapCubit>().amountChanged(v);
                  }
                },
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

class SwapChangeButton extends StatelessWidget {
  const SwapChangeButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(32),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: IconButton(
          icon: const Icon(Icons.swap_vert),
          iconSize: 32,
          onPressed: () {
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
      (SwapCubit cubit) => cubit.state.formattedFromWalletBalance(),
    );
    const maxSelected = false;

    return Row(
      children: [
        BBText(
          'Available balance',
          style: context.font.labelLarge,
          color: context.colour.surface,
        ),
        const Gap(4),
        BBText(balance, style: context.font.labelLarge),
        const Spacer(),
        BBButton.small(
          label: 'MAX',
          height: 40,
          width: 88,
          onPressed: () {},
          bgColor:
              maxSelected
                  ? context.colour.secondary
                  : context.colour.onSecondary,
          textColor:
              maxSelected
                  ? context.colour.onSecondary
                  : context.colour.secondary,
          outlined: true,
          borderColor:
              maxSelected
                  ? context.colour.onSecondary
                  : context.colour.secondary,
          disabled: true,
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
    if (swapCreationError == null) {
      return const SizedBox.shrink();
    }
    return BBText(
      swapCreationError.message,
      style: context.font.labelLarge,
      color: context.colour.error,
      maxLines: 4,
    );
  }
}

class SwapFromToDropdown extends StatelessWidget {
  const SwapFromToDropdown({super.key, required this.type});

  final _SwapDropdownType type;
  // make the DropFownMenuItem be a named tuple
  List<DropdownMenuItem> _buildDropdownItems(
    BuildContext context,
    List<({String label, String id})> items,
  ) {
    return [
      for (final ({String label, String id}) item in items)
        DropdownMenuItem(
          value: item.id,
          child: BBText(item.label, style: context.font.headlineSmall),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final items = context.select(
      (SwapCubit cubit) =>
          type == _SwapDropdownType.from
              ? cubit.state.fromWalletDropdownItems
              : cubit.state.toWalletDropdownItems,
    );
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    final id = context.select(
      (SwapCubit cubit) =>
          type == _SwapDropdownType.from
              ? cubit.state.fromWalletId
              : cubit.state.toWalletId,
    );

    final dropdownItems = _buildDropdownItems(context, items);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BBText(
          'Swap ${type == _SwapDropdownType.from ? 'from' : 'to'}',
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
              child: DropdownButtonFormField(
                value: id,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
                ),
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: context.colour.secondary,
                ),
                items: dropdownItems,
                onChanged: (value) {
                  if (value != null) {
                    type == _SwapDropdownType.from
                        ? context.read<SwapCubit>().updateSelectedFromWallet(
                          value as String,
                        )
                        : context.read<SwapCubit>().updateSelectedToWallet(
                          value as String,
                        );
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
    final totalFees = context.select(
      (SwapCubit cubit) => cubit.state.estimatedFeesFormatted,
    );
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: 'Swap',
          actionIcon: Icons.help_outline,
          onAction: () {},
          onBack: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
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
              formattedFiatEquivalent: '',
              swapId: swap!.id,
              totalSwapFees: totalFees,
            ),
            const Gap(64),
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
              disableSendButton: false,
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
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: 'Swap',
          actionIcon: Icons.help_outline,
          onAction: () {},
          onBack: () => context.pop(),
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
                  Gif(
                    autostart: Autostart.loop,
                    height: 123,
                    image: AssetImage(Assets.images2.cubesLoading.path),
                  ),

                  const Gap(8),
                  BBText('Sending...', style: context.font.headlineLarge),
                  const Gap(8),
                  BBText(
                    'The swap is in progress. Bitcoin transactions can take a while to confirm. You can return home and wait.',
                    style: context.font.bodyMedium,
                    maxLines: 4,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const Spacer(flex: 2),
            BBButton.big(
              label: 'Go home',
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
