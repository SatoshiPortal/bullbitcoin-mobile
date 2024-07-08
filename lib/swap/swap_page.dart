import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/bull_bitcoin_api.dart';
import 'package:bb_mobile/_pkg/mempool_api.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/organisms/swap_widget.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/network_fees/bloc/networkfees_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class SwapPage extends StatefulWidget {
  const SwapPage({super.key});

  @override
  State<SwapPage> createState() => _SwapPageState();
}

class _SwapPageState extends State<SwapPage> {
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
    );

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: currency),
        BlocProvider.value(value: networkFees),
      ],
      child: Scaffold(
        appBar: AppBar(
          flexibleSpace: const _SwapAppBar(),
          automaticallyImplyLeading: false,
        ),
        body: const _Screen(),
      ),
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) {
    final network = context.read<NetworkCubit>().state.getBBNetwork();
    final walletBlocs =
        context.read<HomeCubit>().state.walletBlocsFromNetwork(network);
    final wallets = walletBlocs.map((bloc) => bloc.state.wallet!).toList();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          children: [
            const SizedBox(
              height: 100,
            ),
            SwapWidget(
              wallets: wallets,
              onSwapPressed: _swapButtonPressed,
            ),
          ],
        ),
      ),
    );
  }

  void _swapButtonPressed(Wallet fromWallet, Wallet toWallet, int amount) {
    print('Swap $amount from ${fromWallet.name} to ${toWallet.name}');
  }
}

class _SwapAppBar extends StatelessWidget {
  const _SwapAppBar();

  @override
  Widget build(BuildContext context) {
    return BBAppBar(
      text: 'Swap',
      onBack: () {
        context.pop();
      },
    );
  }
}
