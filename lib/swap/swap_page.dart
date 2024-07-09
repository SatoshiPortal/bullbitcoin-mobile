import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/barcode.dart';
import 'package:bb_mobile/_pkg/boltz/swap.dart';
import 'package:bb_mobile/_pkg/bull_bitcoin_api.dart';
import 'package:bb_mobile/_pkg/file_storage.dart';
import 'package:bb_mobile/_pkg/mempool_api.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/wallet/repository/sensitive_storage.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/organisms/swap_widget.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/network_fees/bloc/networkfees_cubit.dart';
import 'package:bb_mobile/send/bloc/send_cubit.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/swap/create_swap_bloc/swap_cubit.dart';
import 'package:bb_mobile/swap/onchain_listeners.dart';
import 'package:bb_mobile/swap/watcher_bloc/watchtxs_bloc.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:boltz_dart/boltz_dart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class SwapPage extends StatefulWidget {
  const SwapPage({super.key});

  void get openScanner {}

  @override
  State<SwapPage> createState() => _SwapPageState();
}

class _SwapPageState extends State<SwapPage> {
  late SendCubit send;
  late NetworkFeesCubit networkFees;

  late CreateSwapCubit swap;
  late CurrencyCubit currency;

  @override
  void initState() {
    swap = CreateSwapCubit(
      walletSensitiveRepository: locator<WalletSensitiveStorageRepository>(),
      swapBoltz: locator<SwapBoltz>(),
      walletTx: locator<WalletTx>(),
      homeCubit: context.read<HomeCubit>(),
      watchTxsBloc: context.read<WatchTxsBloc>(),
      networkCubit: context.read<NetworkCubit>(),
    )..fetchFees(context.read<NetworkCubit>().state.testnet);

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

    WalletBloc? walletBloc;

    walletBloc = context.read<HomeCubit>().state.walletBlocs?[0];

    send = SendCubit(
      walletTx: locator<WalletTx>(),
      barcode: locator<Barcode>(),
      defaultRBF: locator<SettingsCubit>().state.defaultRBF,
      fileStorage: locator<FileStorage>(),
      networkCubit: locator<NetworkCubit>(),
      homeCubit: locator<HomeCubit>(),
      swapBoltz: locator<SwapBoltz>(),
      currencyCubit: currency,
      openScanner: false,
      walletBloc: walletBloc,
      swapCubit: swap,
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
        body: const OnchainListeners(child: _Screen()),
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
              onSwapPressed: (Wallet fromWallet, Wallet toWallet, int amount) =>
                  _swapButtonPressed(context, fromWallet, toWallet, amount),
            ),
          ],
        ),
      ),
    );
  }

  void _swapButtonPressed(
    BuildContext context,
    Wallet fromWallet,
    Wallet toWallet,
    int amount,
  ) async {
    print('Swap $amount from ${fromWallet.name} to ${toWallet.name}');

    final walletBloc =
        context.read<HomeCubit>().state.getWalletBlocById(fromWallet.id);

    context.read<SendCubit>().updateWalletBloc(walletBloc!);

    await Future.delayed(Duration.zero);

    context.read<CreateSwapCubit>().createOnChainSwap(
          wallet: fromWallet,
          amount: amount,
          isTestnet: true,
          btcElectrumUrl: 'electrum.blockstream.info:60002',
          lbtcElectrumUrl: 'blockstream.info:465',
          toAddress:
              'tlq1qqd8f92dfedpvsydxxk54l8glwa5m8e84ygqz7n5dgyujp37v3n60pjzfrc2xu4a9fla6snzgznn9tjpwc99d7kn2s472sw2la', // TODO: Derive this from toWallet.lastUnused
          direction: ChainSwapDirection.btcToLbtc,
        );
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
