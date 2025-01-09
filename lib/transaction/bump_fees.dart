import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_pkg/barcode.dart';
import 'package:bb_mobile/_pkg/boltz/swap.dart';
import 'package:bb_mobile/_pkg/bull_bitcoin_api.dart';
import 'package:bb_mobile/_pkg/file_storage.dart';
import 'package:bb_mobile/_pkg/launcher.dart';
import 'package:bb_mobile/_pkg/mempool_api.dart';
import 'package:bb_mobile/_pkg/payjoin/manager.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/wallet/address.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/sensitive_create.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/transaction.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:bb_mobile/_pkg/wallet/update.dart';
import 'package:bb_mobile/_repositories/app_wallets_repository.dart';
import 'package:bb_mobile/_repositories/network_repository.dart';
import 'package:bb_mobile/_repositories/wallet/internal_wallets.dart';
import 'package:bb_mobile/_repositories/wallet/sensitive_wallet_storage.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/page_template.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network/bloc/network_bloc.dart';
import 'package:bb_mobile/network_fees/bloc/networkfees_cubit.dart';
import 'package:bb_mobile/send/bloc/send_cubit.dart';
import 'package:bb_mobile/send/send_page.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/swap/create_swap_bloc/swap_cubit.dart';
import 'package:bb_mobile/swap/watcher_bloc/watchtxs_bloc.dart';
import 'package:bb_mobile/transaction/bloc/state.dart';
import 'package:bb_mobile/transaction/bloc/transaction_cubit.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class BumpFeesButton extends StatelessWidget {
  const BumpFeesButton({super.key});

  @override
  Widget build(BuildContext context) {
    final tx = context.select((TransactionCubit x) => x.state.tx);
    final canRbf = context.select((TransactionCubit x) => x.state.tx.canRBF());
    final isReceive =
        context.select((TransactionCubit x) => x.state.tx.isReceived());
    final isBitcoin =
        context.select((TransactionCubit x) => !x.state.tx.isLiquid);

    final canBump = isBitcoin && canRbf && !isReceive;
    if (!canBump) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BBButton.big(
          label: 'Bump Fees',
          onPressed: () async {
            context.push('/bump', extra: tx);
          },
        ),
        const Gap(24),
      ],
    );
  }
}

class BumpFooterButton extends StatelessWidget {
  const BumpFooterButton({super.key});

  @override
  Widget build(BuildContext context) {
    final loading = context.select(
      (TransactionCubit x) => x.state.buildingTx || x.state.sendingTx,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BBButton.big(
          center: true,
          loading: loading,
          disabled: loading,
          label: loading ? 'Bumping' : 'Bump Fees',
          onPressed: () async {
            final fees = context.read<NetworkFeesCubit>().state.feesForBump();
            context.read<TransactionCubit>().buildRbfTx(fees);
          },
        ),
      ],
    );
  }
}

class BumpFeesPage extends StatefulWidget {
  const BumpFeesPage({super.key, required this.tx});

  final Transaction tx;

  @override
  State<BumpFeesPage> createState() => _BumpFeesPageState();
}

class _BumpFeesPageState extends State<BumpFeesPage> {
  late SendCubit send;
  late WalletBloc? walletBloc;
  late NetworkFeesCubit networkFees;
  late CurrencyCubit currency;
  late CreateSwapCubit swap;
  late TransactionCubit txCubit;

  @override
  void initState() {
    final wallet =
        context.read<AppWalletsRepository>().getWalletFromTx(widget.tx);
    if (wallet == null) return;
    walletBloc = createOrRetreiveWalletBloc(wallet.id);

    swap = CreateSwapCubit(
      walletSensitiveRepository: locator<WalletSensitiveStorageRepository>(),
      swapBoltz: locator<SwapBoltz>(),
      walletTx: locator<WalletTx>(),
      appWalletsRepository: locator<AppWalletsRepository>(),
      // homeCubit: context.read<HomeBloc>(),
      watchTxsBloc: context.read<WatchTxsBloc>(),
      // networkCubit: context.read<NetworkBloc>(),
      networkRepository: locator<NetworkRepository>(),
    )..fetchFees(context.read<NetworkBloc>().state.networkData.testnet);

    networkFees = NetworkFeesCubit(
      hiveStorage: locator<HiveStorage>(),
      mempoolAPI: locator<MempoolAPI>(),
      networkRepository: locator<NetworkRepository>(),
      defaultNetworkFeesCubit: context.read<NetworkFeesCubit>(),
    );
    networkFees.showOnlyFastest(true);
    networkFees.feeOptionSelected(0);

    txCubit = TransactionCubit(
      tx: widget.tx,
      wallet: wallet,
      walletUpdate: locator<WalletUpdate>(),
      appWalletsRepository: locator<AppWalletsRepository>(),
      walletTx: locator<WalletTx>(),
      bdkTx: locator<BDKTransactions>(),
      walletSensRepository: locator<WalletSensitiveStorageRepository>(),
      walletAddress: locator<WalletAddress>(),
      walletsRepository: locator<InternalWalletsRepository>(),
      bdkSensitiveCreate: locator<BDKSensitiveCreate>(),
    );

    currency = CurrencyCubit(
      hiveStorage: locator<HiveStorage>(),
      bbAPI: locator<BullBitcoinAPI>(),
      defaultCurrencyCubit: context.read<CurrencyCubit>(),
    );

    send = SendCubit(
      walletTx: locator<WalletTx>(),
      barcode: locator<Barcode>(),
      defaultRBF: locator<SettingsCubit>().state.defaultRBF,
      fileStorage: locator<FileStorage>(),
      networkRepository: locator<NetworkRepository>(),
      appWalletsRepository: locator<AppWalletsRepository>(),
      payjoinManager: locator<PayjoinManager>(),
      swapBoltz: locator<SwapBoltz>(),
      openScanner: false,
      swapCubit: swap,
    );
    super.initState();
  }

  @override
  void dispose() {
    networkFees.showOnlyFastest(false);
    send.close();
    txCubit.close();
    networkFees.close();
    currency.close();
    swap.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (walletBloc == null) {
      context.pop();
      return const SizedBox.shrink();
    }

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: send),
        BlocProvider.value(value: txCubit),
        BlocProvider.value(value: walletBloc!),
        BlocProvider.value(value: networkFees),
        BlocProvider.value(value: locator<WatchTxsBloc>()),
      ],
      child: BlocListener<TransactionCubit, TransactionState>(
        listenWhen: (previous, current) => previous.sentTx != current.sentTx,
        listener: (context, state) async {
          if (state.sentTx) {
            await Future.delayed(const Duration(microseconds: 200));
            context
              ..pop()
              ..pop();
          }
        },
        child: Scaffold(
          appBar: AppBar(
            flexibleSpace: BBAppBar(
              text: 'Bump Tx',
              onBack: () {
                context.pop();
              },
            ),
            automaticallyImplyLeading: false,
          ),
          body: const StackedPage(
            bottomChild: BumpFooterButton(),
            child: _Screen(),
          ),
        ),
      ),
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) {
    final tx = context.select((TransactionCubit _) => _.state.tx);

    final isSwapPending = tx.swapIdisTxid();

    final txid = tx.txid;
    final amt = tx.getNetAmountToPayee().abs();
    final isReceived = tx.isReceived();
    final fees = tx.fee ?? 0;
    final amtStr = context.select(
      (CurrencyCubit cubit) =>
          cubit.state.getAmountInUnits(amt, removeText: true),
    );
    final feeStr = context.select(
      (CurrencyCubit cubit) =>
          cubit.state.getAmountInUnits(fees, removeText: true),
    );
    final units = context.select(
      (CurrencyCubit cubit) => cubit.state.getUnitString(),
    );

    final feeRate = (tx.feeRate ?? 1).toStringAsFixed(2);

    final er = context.select((TransactionCubit x) => x.state.errSendingTx);
    final err = context.select((TransactionCubit x) => x.state.errBuildingTx);

    final errr = err.isNotEmpty ? err : er;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Gap(24),
              BBText.title(
                isReceived ? 'Amount received' : 'Amount sent',
              ),
              const Gap(4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Container(
                    transformAlignment: Alignment.center,
                    transform: Matrix4.identity()..rotateZ(isReceived ? 1 : -1),
                    child: const FaIcon(
                      FontAwesomeIcons.arrowRight,
                      size: 12,
                    ),
                  ),
                  const Gap(8),
                  BBText.titleLarge(
                    amtStr,
                    isBold: true,
                  ),
                  const Gap(4),
                  BBText.title(
                    units,
                    isBold: true,
                  ),
                ],
              ),
              const Gap(24),
              if (!isSwapPending) ...[
                const BBText.title('Transaction ID'),
                const Gap(4),
                InkWell(
                  onTap: () {
                    final url = context.read<NetworkBloc>().state.explorerTxUrl(
                          txid,
                          isLiquid: tx.isLiquid,
                        );
                    locator<Launcher>().launchApp(url);
                  },
                  child: BBText.body(txid, isBlue: true),
                ),
                const Gap(24),
              ],
              const BBText.title(
                'Current Fee',
              ),
              const Gap(4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  BBText.titleLarge(
                    feeStr,
                    isBold: true,
                  ),
                  const Gap(4),
                  BBText.title(
                    units,
                    isBold: true,
                  ),
                  const Gap(4),
                  BBText.title(
                    '($feeRate sats/vB)',
                  ),
                ],
              ),
              const Gap(24),
              const NetworkFees(label: 'Set new fee rate'),
              const Gap(24),
              if (errr.isNotEmpty) BBText.errorSmall(errr),
            ],
          ),
        ),
      ),
    );
  }
}
