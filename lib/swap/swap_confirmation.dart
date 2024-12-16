import 'package:bb_mobile/_pkg/bull_bitcoin_api.dart';
import 'package:bb_mobile/_pkg/mempool_api.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/warning.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/network_fees/bloc/networkfees_cubit.dart';
import 'package:bb_mobile/send/bloc/send_cubit.dart';
import 'package:bb_mobile/send/send_page.dart';
import 'package:bb_mobile/styles.dart';
import 'package:bb_mobile/swap/create_swap_bloc/swap_cubit.dart';
import 'package:bb_mobile/swap/fee_popup.dart';
import 'package:bb_mobile/swap/onchain_listeners.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class SwapConfirmationPage extends StatefulWidget {
  const SwapConfirmationPage({
    super.key,
    this.fromWalletId,
    required this.send,
    required this.swap,
  });

  final String? fromWalletId;
  final SendCubit send;
  final CreateSwapCubit swap;

  @override
  State<SwapConfirmationPage> createState() => _SwapConfirmationPageState();
}

class _SwapConfirmationPageState extends State<SwapConfirmationPage> {
  // late SendCubit send;
  late NetworkFeesCubit networkFees;

  late CurrencyCubit currency;

  @override
  void initState() {
    networkFees = NetworkFeesCubit(
      networkCubit: locator<NetworkCubit>(),
      hiveStorage: locator<HiveStorage>(),
      mempoolAPI: locator<MempoolAPI>(),
      defaultNetworkFeesCubit: context.read<NetworkFeesCubit>(),
    );

    currency = CurrencyCubit(
      hiveStorage: locator<HiveStorage>(),
      bbAPI: locator<BullBitcoinAPI>(),
      defaultCurrencyCubit: context.read<CurrencyCubit>(),
    )..updateAmountDirect(widget.send.state.tx!.getAmount(sentAsTotal: true));

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: currency),
        BlocProvider.value(value: networkFees),
        BlocProvider.value(value: widget.swap),
        BlocProvider.value(value: widget.send),
      ],
      child: Scaffold(
        appBar: AppBar(
          flexibleSpace: const _SwapAppBar(),
          automaticallyImplyLeading: false,
        ),
        body:
            OnchainListeners(child: _Screen(fromWalletId: widget.fromWalletId)),
      ),
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen({this.fromWalletId});

  final String? fromWalletId;

  @override
  Widget build(BuildContext context) {
    final generatingInv = context
        .select((CreateSwapCubit cubit) => cubit.state.generatingSwapInv);
    final sendingg = context.select((SendCubit cubit) => cubit.state.sending);
    final buildingOnChain =
        context.select((SendCubit cubit) => cubit.state.buildingOnChain);
    final sending = generatingInv || sendingg || buildingOnChain;

    final senderFee =
        context.select((SendCubit send) => send.state.psbtSignedFeeAmount ?? 0);

    final amount = context.select((CurrencyCubit cubit) => cubit.state.amount);
    final amtStr = context
        .select((CurrencyCubit cubit) => cubit.state.getAmountInUnits(amount));

    final currency =
        context.select((CurrencyCubit _) => _.state.defaultFiatCurrency);
    final amtFiat = context.select(
      (NetworkCubit cubit) => cubit.state.calculatePrice(amount, currency),
    );

    final swapTx =
        context.select((CreateSwapCubit cubit) => cubit.state.swapTx);

    final swapFees = swapTx?.totalFees() ?? 0;
    final fee = swapFees + senderFee;
    final feeStr = context
        .select((CurrencyCubit cubit) => cubit.state.getAmountInUnits(fee));

    final feeFiat = context.select(
      (NetworkCubit cubit) => cubit.state.calculatePrice(fee, currency),
    );

    final fiatCurrency = context.select(
      (CurrencyCubit cubit) => cubit.state.defaultFiatCurrency?.shortName ?? '',
    );

    // final sent = context.select((SendCubit cubit) => cubit.state.sent);
    // if (sent) return ChainSwapProgressWidget();

    final showWarning = context.select(
      (CreateSwapCubit x) => x.state.showSwapWarning(),
    );

    context.select(
      (SendCubit x) => x.state.selectedWalletBloc?.state.wallet?.name ?? '',
    );

    if (showWarning == true) {
      return const _Warnings();
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Gap(24),
            const BBText.titleLarge(
              'Confirm Transaction',
            ),
            const Gap(32),
            const BBText.title(
              'Transaction Amount',
            ),
            const Gap(4),
            BBText.bodyBold(
              amtStr,
            ),
            BBText.body(
              '~ $amtFiat $fiatCurrency ',
            ),
            const Gap(24),
            const BBText.title(
              'Swap script Address',
            ),
            const Gap(4),
            BBText.body(swapTx!.scriptAddress),
            const Gap(24),
            Row(
              children: [
                const BBText.title(
                  'Total Fee',
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  iconSize: 22.0,
                  padding: EdgeInsets.zero,
                  color: context.colour.onPrimaryContainer,
                  onPressed: () {
                    FeePopUp.openPopup(
                      context,
                      senderFee,
                      swapTx.claimFees ?? 0,
                      swapTx.boltzFees ?? 0,
                    );
                    // show popup
                  },
                ),
              ],
            ),
            // const Gap(4),
            BBText.body(
              feeStr,
            ),
            BBText.body(
              '~ $feeFiat $fiatCurrency',
            ),
            const Gap(24),
            BBButton.big(
              loading: sending,
              disabled: sending,
              label: 'Confirm',
              onPressed: () {
                context.read<SendCubit>().sendSwap();
              },
              loadingText: 'Broadcasting',
            ),
            const Gap(32),
            const SendErrDisplay(),
          ],
        ),
      ),
    );
  }
}

class _SwapAppBar extends StatelessWidget {
  const _SwapAppBar();

  @override
  Widget build(BuildContext context) {
    return BBAppBar(
      text: 'Swap Bitcoin',
      onBack: () {
        context.pop();
      },
    );
  }
}

class _Warnings extends StatelessWidget {
  const _Warnings();

  @override
  Widget build(BuildContext context) {
    final swapTx = context.select((CreateSwapCubit x) => x.state.swapTx);
    if (swapTx == null) return const SizedBox.shrink();

    final swaptx = context.select((CreateSwapCubit x) => x.state.swapTx!);

    final errHighFees =
        context.select((CreateSwapCubit x) => x.state.swapTx!.highFees());

    final amt = swaptx.outAmount;

    const minAmt = 1000000;

    final currency =
        context.select((CurrencyCubit _) => _.state.defaultFiatCurrency);

    final fees = swaptx.totalFees() ?? 0;

    final feeStr = context
        .select((CurrencyCubit cubit) => cubit.state.getAmountInUnits(fees));

    final feesFiatStr = context.select(
      (NetworkCubit cubit) => cubit.state.calculatePrice(fees, currency),
    );

    final amtStr = context
        .select((CurrencyCubit cubit) => cubit.state.getAmountInUnits(amt));

    final amtFiatStr = context.select(
      (NetworkCubit cubit) => cubit.state.calculatePrice(amt, currency),
    );

    final minAmtStr = context
        .select((CurrencyCubit cubit) => cubit.state.getAmountInUnits(minAmt));

    final minAmtFiatStr = context.select(
      (NetworkCubit cubit) => cubit.state.calculatePrice(minAmt, currency),
    );

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WarningContainer(
              children: [
                const Gap(24),
                if (errHighFees != null)
                  HighFeesWarn(
                    feePercentage: errHighFees,
                    amt: amtStr,
                    amtFiat: amtFiatStr,
                    fees: feeStr,
                    feesFiat: feesFiatStr,
                    minAmt: minAmtStr,
                    minAmtFiat: minAmtFiatStr,
                    // amt: swapTx.outAmount,
                    // fees: swapTx.totalFees() ?? 0,
                  ),
                const Gap(24),
                Center(
                  child: BBButton.big(
                    leftIcon: Icons.send_outlined,
                    label: 'Continue anyways',
                    onPressed: () {
                      context.read<CreateSwapCubit>().removeWarnings();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class HighFeesWarn extends StatelessWidget {
  const HighFeesWarn({
    required this.feePercentage,
    required this.amt,
    required this.amtFiat,
    required this.fees,
    required this.feesFiat,
    required this.minAmt,
    required this.minAmtFiat,
  });

  final double feePercentage;
  final String amt;
  final String amtFiat;
  final String fees;
  final String feesFiat;
  final String minAmt;
  final String minAmtFiat;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BBText.titleLarge('High fee warning', isRed: true),
        const Gap(8),
        // const BBText.body('Bitcoin Network fees are currently high.'),
        // const Gap(8),
        const BBText.bodySmall(
          'When swapping between Instant and Secure wallets, you must pay Bitcoin Network fees and Swap fees.',
        ),
        const Gap(8),
        Row(
          children: [
            const BBText.bodySmall('You are about to pay over '),
            BBText.bodySmall(
              '${feePercentage.toStringAsFixed(2)}% ',
              isBold: true,
            ),
          ],
        ),
        const BBText.bodySmall(
          'in Bitcoin Network and swap fees for this transaction.',
        ),
        const Gap(8),
        Row(
          children: [
            const BBText.bodySmall('Amount you send: '),
            BBText.bodySmall(amt, isBold: true),
          ],
        ),
        Row(
          children: [
            const BBText.bodySmall('Network fees: '),
            BBText.bodySmall(fees, isBold: true),
          ],
        ),
        const Gap(24),
        const BBText.titleLarge('Payment may take many hours', isRed: true),
        const Gap(8),
        const BBText.body(
          'It may take many hours to the recipient to see your payment. Do not continue if recipient requires immediate payment.',
        ),
      ],
    );
  }
}
