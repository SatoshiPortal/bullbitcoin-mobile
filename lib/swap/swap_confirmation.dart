import 'package:bb_mobile/_pkg/bull_bitcoin_api.dart';
import 'package:bb_mobile/_pkg/mempool_api.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/network_fees/bloc/networkfees_cubit.dart';
import 'package:bb_mobile/send/bloc/send_cubit.dart';
import 'package:bb_mobile/send/send_page.dart';
import 'package:bb_mobile/swap/create_swap_bloc/swap_cubit.dart';
import 'package:bb_mobile/swap/swap_page_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class SwapConfirmationPage extends StatefulWidget {
  SwapConfirmationPage({
    super.key,
    this.fromWalletId,
    required this.send,
    required this.swap,
  });

  String? fromWalletId;
  SendCubit send;
  CreateSwapCubit swap;

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
        body: _Screen(fromWalletId: widget.fromWalletId),
      ),
    );
  }
}

class _Screen extends StatelessWidget {
  _Screen({this.fromWalletId});

  String? fromWalletId;

  @override
  Widget build(BuildContext context) {
    final generatingInv = context
        .select((CreateSwapCubit cubit) => cubit.state.generatingSwapInv);
    final sendingg = context.select((SendCubit cubit) => cubit.state.sending);
    final buildingOnChain =
        context.select((SendCubit cubit) => cubit.state.buildingOnChain);
    final sending = generatingInv || sendingg || buildingOnChain;

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
    final senderFee =
        context.select((SendCubit send) => send.state.psbtSignedFeeAmount ?? 0);
    final fee = swapFees + senderFee;
    final feeStr = context
        .select((CurrencyCubit cubit) => cubit.state.getAmountInUnits(fee));

    final feeFiat = context.select(
      (NetworkCubit cubit) => cubit.state.calculatePrice(fee, currency),
    );

    final fiatCurrency = context.select(
      (CurrencyCubit cubit) => cubit.state.defaultFiatCurrency?.shortName ?? '',
    );

    final sent = context.select((SendCubit cubit) => cubit.state.sent);
    if (sent) return SendingOnChainTx();

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
            const BBText.title(
              'Network Fee',
            ),
            const Gap(4),
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
              label: 'Broadcast',
              onPressed: () {
                context.read<SendCubit>().sendSwapClicked();
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
