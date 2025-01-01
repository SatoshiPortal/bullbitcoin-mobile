import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/barcode.dart';
import 'package:bb_mobile/_pkg/boltz/swap.dart';
import 'package:bb_mobile/_pkg/bull_bitcoin_api.dart';
import 'package:bb_mobile/_pkg/file_storage.dart';
import 'package:bb_mobile/_pkg/mempool_api.dart';
import 'package:bb_mobile/_pkg/payjoin/manager.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:bb_mobile/_repository/app_wallets_repository.dart';
import 'package:bb_mobile/_repository/network_repository.dart';
import 'package:bb_mobile/_repository/wallet/sensitive_wallet_storage.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/network_fees/bloc/networkfees_cubit.dart';
import 'package:bb_mobile/send/bloc/send_cubit.dart';
import 'package:bb_mobile/send/send_page.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/swap/create_swap_bloc/swap_cubit.dart';
import 'package:bb_mobile/swap/onchain_listeners.dart';
import 'package:bb_mobile/swap/ui_swapwidget/swap_widget.dart';
import 'package:bb_mobile/swap/watcher_bloc/watchtxs_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class SwapPage extends StatefulWidget {
  const SwapPage({super.key, this.fromWalletId});

  final String? fromWalletId;

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
      // networkCubit: locator<NetworkCubit>(),
      networkRepository: locator<NetworkRepository>(),

      hiveStorage: locator<HiveStorage>(),
      mempoolAPI: locator<MempoolAPI>(),
      defaultNetworkFeesCubit: context.read<NetworkFeesCubit>(),
    );

    currency = CurrencyCubit(
      hiveStorage: locator<HiveStorage>(),
      bbAPI: locator<BullBitcoinAPI>(),
      defaultCurrencyCubit: context.read<CurrencyCubit>(),
    );

    // WalletBloc? walletBloc;

    final wallet = context.read<AppWalletsRepository>().allWallets.first;
    // walletBloc = createWalletBloc(wallet);
    // walletBloc = context.read<HomeCubit>().state.walletBlocs?[0];

    send = SendCubit(
      walletTx: locator<WalletTx>(),
      barcode: locator<Barcode>(),
      defaultRBF: locator<SettingsCubit>().state.defaultRBF,
      fileStorage: locator<FileStorage>(),
      networkRepository: locator<NetworkRepository>(),
      appWalletsRepository: locator<AppWalletsRepository>(),
      // networkCubit: locator<NetworkCubit>(),
      // networkFeesCubit: locator<NetworkFeesCubit>(),
      // homeCubit: locator<HomeCubit>(),
      payjoinManager: locator<PayjoinManager>(),
      swapBoltz: locator<SwapBoltz>(),
      // currencyCubit: currency,
      openScanner: false,
      wallet: wallet,
      // walletBloc: walletBloc,
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
        BlocProvider.value(value: swap),
        BlocProvider.value(value: send),
      ],
      child: Scaffold(
        appBar: AppBar(
          flexibleSpace: const _SwapAppBar(),
          automaticallyImplyLeading: false,
        ),
        body: OnchainListeners(
          child: _Screen(fromWalletId: widget.fromWalletId),
        ),
      ),
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen({this.fromWalletId});

  final String? fromWalletId;

  @override
  Widget build(BuildContext context) {
    final network =
        context.select((NetworkCubit cubit) => cubit.state.getBBNetwork());
    final walletBlocs = context.select(
      (HomeCubit cubit) =>
          cubit.state.walletBlocsFromNetworkExcludeWatchOnly(network),
    );
    final wallets = walletBlocs.map((bloc) => bloc.state.wallet).toList();

    final generatingInv = context
        .select((CreateSwapCubit cubit) => cubit.state.generatingSwapInv);
    final sendingg = context.select((SendCubit cubit) => cubit.state.sending);
    final buildingOnChain =
        context.select((SendCubit cubit) => cubit.state.buildingOnChain);
    final sending = generatingInv || sendingg || buildingOnChain;

    final unitInSats = context.select(
      (CurrencyCubit cubit) => cubit.state.unitsInSats,
    );

    final swapTx =
        context.select((CreateSwapCubit cubit) => cubit.state.swapTx);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(
              height: 60,
            ),
            SwapWidget(
              loading: sending,
              wallets: wallets,
              fromWalletId: fromWalletId,
              swapButtonLoadingLabel: 'Creating swap',
              unitInSats: unitInSats,
              onChange: (
                Wallet fromWallet,
                Wallet toWallet,
                int amount,
                bool sweep,
              ) {
                if (swapTx != null) {
                  context.read<CreateSwapCubit>().clearSwapTx();
                  context.read<SendCubit>().reset();
                }
              },
              onSwapPressed: (
                Wallet fromWallet,
                Wallet toWallet,
                int amount,
                bool sweep,
              ) {
                final feeRate = context
                    .read<NetworkFeesCubit>()
                    .state
                    .selectedOrFirst(true);
                final unitsInSats =
                    context.read<CurrencyCubit>().state.unitsInSats;
                context.read<SendCubit>().buildChainSwap(
                      fromWallet: fromWallet,
                      toWallet: toWallet,
                      amount: amount,
                      sweep: sweep,
                      feeRate: feeRate,
                      unitsInSats: unitsInSats,
                    );
              },
            ),
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
