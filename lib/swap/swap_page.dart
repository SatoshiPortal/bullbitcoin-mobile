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
import 'package:bb_mobile/_ui/organisms/swap_widget2.dart';
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
import 'package:bb_mobile/swap/swap_page_progress.dart';
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
        BlocProvider.value(value: swap),
        BlocProvider.value(value: send),
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

    final sent = context.select((SendCubit cubit) => cubit.state.sent);
    if (sent) return const SendingOnChainTx();

    // final watchOnly = context.select(
    //   (SendCubit cubit) =>
    //       cubit.state.selectedWalletBloc?.state.wallet?.watchOnly() ?? false,
    // );

    final generatingInv = context
        .select((CreateSwapCubit cubit) => cubit.state.generatingSwapInv);
    final sendingg = context.select((SendCubit cubit) => cubit.state.sending);
    final buildingOnChain =
        context.select((SendCubit cubit) => cubit.state.buildingOnChain);
    final sending = generatingInv || sendingg || buildingOnChain;

    final signed = context.select((SendCubit cubit) => cubit.state.signed);

    final unitInSats = context.select(
      (CurrencyCubit cubit) => cubit.state.unitsInSats,
    );

    final swapTx =
        context.select((CreateSwapCubit cubit) => cubit.state.swapTx);

    final fee = swapTx?.totalFees() ?? 0;
    final feeStr = context
        .select((CurrencyCubit cubit) => cubit.state.getAmountInUnits(fee));

    final currency =
        context.select((CurrencyCubit _) => _.state.defaultFiatCurrency);
    final feeFiat = context.select(
      (NetworkCubit cubit) => cubit.state.calculatePrice(fee, currency),
    );

    final fiatCurrency = context.select(
      (CurrencyCubit cubit) => cubit.state.defaultFiatCurrency?.shortName ?? '',
    );

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(
              height: 60,
            ),
            SwapWidget2(
              loading: sending,
              wallets: wallets,
              swapButtonLabel: signed == true ? 'Broadcast' : 'Swap',
              swapButtonLoadingLabel:
                  signed == true ? 'Broadcasting' : 'Creating swap',
              unitInSats: unitInSats,
              fee: swapTx != null ? feeStr : null,
              feeFiat: swapTx != null ? '~ $feeFiat $fiatCurrency' : null,
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
                _swapButtonPressed(
                  context,
                  fromWallet,
                  toWallet,
                  amount,
                  sweep,
                  signed,
                );
              },
            ),
            const SendErrDisplay(),
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
    bool sweep,
    bool toBroadcast,
  ) async {
    print('swap button pressed $toBroadcast');
    if (toBroadcast) {
      context.read<SendCubit>().sendSwapClicked();
      return;
    }

    if (amount > fromWallet.balance!) {
      context.read<CreateSwapCubit>().setValidationError(
            'Not enough balance.\nWallet balance is: ${fromWallet.balance!}.',
          );
      return;
    }

    print('Swap $amount from ${fromWallet.name} to ${toWallet.name}');

    final walletBloc =
        context.read<HomeCubit>().state.getWalletBlocById(fromWallet.id);
    context.read<SendCubit>().updateWalletBloc(walletBloc!);

    final recipientAddress = toWallet.lastGeneratedAddress?.address ?? '';
    final refundAddress = fromWallet.lastGeneratedAddress?.address ?? '';

    final liqNetworkurl =
        context.read<NetworkCubit>().state.getLiquidNetworkUrl();
    final btcNetworkUrl = context.read<NetworkCubit>().state.getNetworkUrl();
    final btcNetworkUrlWithoutSSL = btcNetworkUrl.startsWith('ssl://')
        ? btcNetworkUrl.split('//')[1]
        : btcNetworkUrl;

    await Future.delayed(Duration.zero);

    context.read<CreateSwapCubit>().createOnChainSwap(
          wallet: fromWallet,
          amount: amount, //20000, // 1010000, // amount,
          sweep: sweep,
          isTestnet: context.read<NetworkCubit>().state.testnet,
          btcElectrumUrl:
              btcNetworkUrlWithoutSSL, // 'electrum.blockstream.info:60002',
          lbtcElectrumUrl: liqNetworkurl, // 'blockstream.info:465',
          toAddress: recipientAddress, // recipientAddress.address;
          refundAddress: refundAddress,
          direction: fromWallet.baseWalletType == BaseWalletType.Bitcoin
              ? ChainSwapDirection.btcToLbtc
              : ChainSwapDirection.lbtcToBtc,
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
