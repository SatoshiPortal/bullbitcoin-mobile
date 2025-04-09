import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/settings/domain/usecases/get_bitcoin_unit_usecase.dart';
import 'package:bb_mobile/core/settings/domain/usecases/get_currency_usecase.dart';
import 'package:bb_mobile/core/utxo/domain/usecases/get_utxos_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/detect_bitcoin_string_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/select_best_wallet_usecase.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_state.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/components/cards/info_card.dart';
import 'package:bb_mobile/ui/components/dialpad/dial_pad.dart';
import 'package:bb_mobile/ui/components/inputs/paste_input.dart';
import 'package:bb_mobile/ui/components/navbar/top_bar.dart';
import 'package:bb_mobile/ui/components/price_input/balance_row.dart';
import 'package:bb_mobile/ui/components/price_input/price_input.dart';
import 'package:bb_mobile/ui/components/segment/segmented_full.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:gif/gif.dart';
import 'package:go_router/go_router.dart';

class SendFlow extends StatelessWidget {
  const SendFlow({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SendCubit(
        bestWalletUsecase: locator<SelectBestWalletUsecase>(),
        detectBitcoinStringUsecase: locator<DetectBitcoinStringUsecase>(),
        getCurrencyUsecase: locator<GetCurrencyUsecase>(),
        getBitcoinUnitUseCase: locator<GetBitcoinUnitUsecase>(),
        convertSatsToCurrencyAmountUsecase:
            locator<ConvertSatsToCurrencyAmountUsecase>(),
        getNetworkFeesUsecase: locator<GetNetworkFeesUsecase>(),
        getAvailableCurrenciesUsecase: locator<GetAvailableCurrenciesUsecase>(),
        getUtxosUsecase: locator<GetUtxosUsecase>(),
      )
        ..getCurrencies()
        ..getExchangeRate(),
      child: const SendScreen(),
    );
  }
}

class SendScreen extends StatelessWidget {
  const SendScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final step =
        context.select<SendCubit, SendStep>((cubit) => cubit.state.step);
    switch (step) {
      case SendStep.address:
        return const SendAddressScreen();
      case SendStep.amount:
        return const SendAmountScreen();
      case SendStep.confirm:
        return const SendConfirmScreen();
      case SendStep.sending:
        return const SendSendingScreen();
      case SendStep.sent:
        throw UnimplementedError();
    }
  }
}

class SendAddressScreen extends StatelessWidget {
  const SendAddressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: read address from bloc
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
        child: Stack(
          children: [
            Expanded(child: Container(color: context.colour.secondaryFixedDim)),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                alignment: Alignment.bottomCenter,
                height: 250,
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
                    const Gap(42),
                    BBText(
                      "Recipient's address",
                      style: context.font.bodyMedium,
                    ),
                    const Gap(16),
                    const AddressField(),
                    const Gap(13 + 16),
                    const SendContinueWithAddressButton(),
                    const Gap(24),
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
  const SendContinueWithAddressButton({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final error = context.select(
      (SendCubit cubit) => cubit.state.error,
    );
    return BBButton.big(
      label: 'Continue',
      onPressed: () {
        context.read<SendCubit>().continueOnAddressConfirmed();
      },
      disabled: error != null,
      bgColor: context.colour.secondary,
      textColor: context.colour.onPrimary,
    );
  }
}

class AddressField extends StatelessWidget {
  const AddressField({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final address = context
        .select<SendCubit, String>((cubit) => cubit.state.addressOrInvoice);
    return PasteInput(
      text: address,
      onChanged: (text) {
        context.read<SendCubit>().addressChanged(text);
      },
    );
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
        flexibleSpace: TopBar(
          title: 'Send',
          onBack: () => context.pop(),
        ),
      ),
      body: BlocBuilder<SendCubit, SendState>(
        builder: (context, state) {
          final cubit = context.read<SendCubit>();

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Gap(10),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: NetworkDisplay(),
                ),
                const Gap(16),
                const Gap(82),
                PriceInput(
                  amount: state.amount,
                  currency: state.bitcoinUnit.name,
                  amountEquivalent:
                      '${state.amount.isEmpty ? '' : state.fiatApproximatedAmount} ${state.fiatCurrencyCode}',
                  availableCurrencies: state.fiatCurrencyCodes,
                  onNoteChanged: cubit.noteChanged,
                  onCurrencyChanged: cubit.currencyCodeChanged,
                ),
                const Gap(82),
                BalanceRow(
                  balance: state.balanceApproximatedAmount,
                  currencyCode: state.fiatCurrencyCode,
                  onMaxPressed: cubit.onMaxPressed,
                ),
                DialPad(
                  onNumberPressed: cubit.onNumberPressed,
                  onBackspacePressed: cubit.onBackspacePressed,
                ),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SendAmountConfirmButton(),
                ),
                const Gap(24),
              ],
            ),
          );
        },
      ),
    );
  }
}

class SendAmountConfirmButton extends StatelessWidget {
  const SendAmountConfirmButton({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final error = context.select(
      (SendCubit cubit) => cubit.state.error,
    );
    return BBButton.big(
      label: 'Continue',
      onPressed: () {
        context.read<SendCubit>().onAmountConfirmed();
      },
      disabled: error != null,
      bgColor: context.colour.secondary,
      textColor: context.colour.onPrimary,
    );
  }
}

class NetworkDisplay extends StatelessWidget {
  const NetworkDisplay({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final sendType = context.select<SendCubit, SendType>(
      (cubit) => cubit.state.sendType,
    );

    return IgnorePointer(
      child: BBSegmentFull(
        items: SendType.values.map((e) => e.displayName).toSet(),
        onSelected: (c) {},
        initialValue: sendType.displayName,
      ),
    );
  }
}

class SendConfirmScreen extends StatelessWidget {
  const SendConfirmScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
      body: const SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Gap(24),
            ConfirmTopArea(),
            Gap(40),
            _InfoSection(),
            Gap(65),
            _Warning(),
            Gap(52),
            _BottomButtons(),
            Gap(40),
          ],
        ),
      ),
    );
  }
}

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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BBButton.big(
            label: 'Advanced Settings',
            onPressed: () {},
            borderColor: context.colour.secondary,
            outlined: true,
            bgColor: Colors.transparent,
            textColor: context.colour.secondary,
          ),
          const Gap(12),
          BBButton.big(
            label: 'Confirm',
            onPressed: () {},
            bgColor: context.colour.secondary,
            textColor: context.colour.onSecondary,
          ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection();
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
          InfoRow(
            title: 'From',
            details:
                BBText('Secure Bitcoin wallet', style: context.font.bodyLarge),
          ),
          _divider(context),
          InfoRow(
            title: 'To',
            details: Row(
              children: [
                BBText('bc1qphad...3aculnn', style: context.font.bodyLarge),
                const Gap(4),
                InkWell(
                  child: Icon(
                    Icons.copy,
                    color: context.colour.primary,
                    size: 16,
                  ),
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
                BBText('42,000 SATS', style: context.font.bodyLarge),
                BBText(
                  '~35.60 CAD',
                  style: context.font.labelSmall,
                  color: context.colour.surfaceContainer,
                ),
              ],
            ),
          ),
          _divider(context),
          InfoRow(
            title: 'Network fees',
            details: BBText('1000 SATS', style: context.font.bodyLarge),
          ),
          _divider(context),
          InfoRow(
            title: 'Fee Priority',
            details: InkWell(
              child: Row(
                children: [
                  BBText(
                    'Fastest',
                    style: context.font.bodyLarge,
                    color: context.colour.primary,
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

class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.title,
    required this.details,
  });

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
          const Spacer(),
          details,
        ],
      ),
    );
  }
}

class ConfirmTopArea extends StatelessWidget {
  const ConfirmTopArea({super.key});

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
          '42,000 SATS',
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
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: 'Send',
          actionIcon: Icons.help_outline,
          onBack: () => context.pop(),
          onAction: () {},
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
                    'The send is in progress. It might take a while for the Bitcoin transaction to confirm. You can close this screen and go home.',
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

class SendWarning extends StatelessWidget {
  const SendWarning({super.key});

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
