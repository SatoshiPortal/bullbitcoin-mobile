import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/swap.dart';
import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_pkg/clipboard.dart';
import 'package:bb_mobile/_pkg/launcher.dart';
import 'package:bb_mobile/_pkg/mempool_api.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/wallet/address.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/sensitive_create.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/transaction.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:bb_mobile/_pkg/wallet/update.dart';
import 'package:bb_mobile/_repository/app_wallets_repository.dart';
import 'package:bb_mobile/_repository/network_repository.dart';
import 'package:bb_mobile/_repository/wallet/internal_wallets.dart';
import 'package:bb_mobile/_repository/wallet/sensitive_wallet_storage.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/home/bloc/home_bloc.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network/bloc/network_bloc.dart';
import 'package:bb_mobile/network_fees/bloc/networkfees_cubit.dart';
import 'package:bb_mobile/styles.dart';
import 'package:bb_mobile/swap/fee_popup.dart';
import 'package:bb_mobile/swap/watcher_bloc/watchtxs_bloc.dart';
import 'package:bb_mobile/transaction/bloc/state.dart';
import 'package:bb_mobile/transaction/bloc/transaction_cubit.dart';
import 'package:bb_mobile/transaction/bump_fees.dart';
import 'package:bb_mobile/transaction/rename_label.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

class TxPage extends StatefulWidget {
  const TxPage({super.key, required this.tx, this.showOnchainSwap = false});

  final Transaction tx;
  final bool showOnchainSwap;

  @override
  State<TxPage> createState() => _TxPageState();
}

class _TxPageState extends State<TxPage> {
  late TransactionCubit txCubit;
  late WalletBloc walletBloc;
  late NetworkFeesCubit networkFees;

  @override
  void initState() {
    final wallet =
        context.read<AppWalletsRepository>().getWalletFromTx(widget.tx);
    if (wallet == null) {
      context.pop();
      return;
    }

    walletBloc = createOrRetreiveWalletBloc(wallet.id);

    networkFees = NetworkFeesCubit(
      hiveStorage: locator<HiveStorage>(),
      mempoolAPI: locator<MempoolAPI>(),
      networkRepository: locator<NetworkRepository>(),
      defaultNetworkFeesCubit: context.read<NetworkFeesCubit>(),
    );

    txCubit = TransactionCubit(
      tx: widget.tx,
      wallet: wallet,
      appWalletsRepository: locator<AppWalletsRepository>(),
      walletUpdate: locator<WalletUpdate>(),
      walletTx: locator<WalletTx>(),
      bdkTx: locator<BDKTransactions>(),
      walletSensRepository: locator<WalletSensitiveStorageRepository>(),
      walletAddress: locator<WalletAddress>(),
      walletsRepository: locator<InternalWalletsRepository>(),
      bdkSensitiveCreate: locator<BDKSensitiveCreate>(),
    );
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: txCubit),
        BlocProvider.value(value: walletBloc),
        BlocProvider.value(value: networkFees),
        BlocProvider.value(value: locator<WatchTxsBloc>()),
      ],
      child: BlocListener<TransactionCubit, TransactionState>(
        listenWhen: (previous, current) => previous.tx != current.tx,
        listener: (context, state) async {},
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            flexibleSpace: const _TxAppBar(),
          ),
          body: _Screen(showOnchainSwap: widget.showOnchainSwap),
        ),
      ),
    );
  }
}

class _TxAppBar extends StatelessWidget {
  const _TxAppBar();

  @override
  Widget build(BuildContext context) {
    var label =
        context.select((TransactionCubit cubit) => cubit.state.tx.label ?? '');

    label = (label.length > 20) ? '${label.substring(0, 20)}...' : label;

    return BBAppBar(
      text: label.isNotEmpty ? label : 'Transaction',
      onBack: () {
        context.pop();
      },
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen({required this.showOnchainSwap});

  final bool showOnchainSwap;

  @override
  Widget build(BuildContext context) {
    final tx = context.select((TransactionCubit _) => _.state.tx);
    final swap = tx.swapTx;

    if (swap != null && !swap.isChainSwap()) {
      return const _CombinedTxAndSwapPage();
    }
    if (swap != null && swap.isChainSwap() && showOnchainSwap == true) {
      return const _CombinedTxAndOnchainSwapPage();
    }
    return const _OnlyTxPage();
  }
}

class _OnlyTxPage extends StatelessWidget {
  const _OnlyTxPage();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(child: _TxDetails());
  }
}

class _CombinedTxAndSwapPage extends StatelessWidget {
  const _CombinedTxAndSwapPage();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _TxDetails(),
          Container(
            padding: const EdgeInsets.only(left: 16.0),
            color: context.colour.surface.withValues(alpha: 0.1),
            child: const Column(
              children: [
                Gap(8),
                BBText.title('Swap Details'),
                _SwapDetails(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CombinedTxAndOnchainSwapPage extends StatelessWidget {
  const _CombinedTxAndOnchainSwapPage();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.only(left: 16.0),
            color: context.colour.surface.withValues(alpha: 0.1),
            child: const Column(
              children: [
                Gap(24),
                _OnchainSwapDetails(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TxDetails extends StatelessWidget {
  const _TxDetails();

  @override
  Widget build(BuildContext context) {
    final tx = context.select((TransactionCubit _) => _.state.tx);
    final isLiq = tx.isLiquid;
    final isSwapPending = tx.swapIdisTxid();

    final err = context
        .select((TransactionCubit cubit) => cubit.state.errLoadingAddresses);

    final txid = tx.txid;
    final unblindedUrl = tx.unblindedUrl;
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
      (CurrencyCubit cubit) => cubit.state.getUnitString(isLiquid: isLiq),
    );

    final statuss = tx.height == null || tx.height == 0 || tx.timestamp == 0;
    final status = statuss ? 'Pending' : 'Confirmed';
    final time = statuss
        ? 'Waiting for confirmations'
        : timeago.format(tx.getDateTime());
    final broadcastTime = tx.getBroadcastDateTime();

    final recipients = tx.outAddrs;
    final recipientAddress = isReceived
        ? tx.outAddrs.firstWhere(
            (element) => element.kind == AddressKind.deposit,
            orElse: () => Address(
              address: '',
              kind: AddressKind.deposit,
              state: AddressStatus.used,
            ),
          )
        : tx.outAddrs.firstWhere(
            (element) => element.kind == AddressKind.external,
            orElse: () => Address(
              address: '',
              kind: AddressKind.external,
              state: AddressStatus.used,
            ),
          );

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 800),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Gap(24),
            const BumpFeesButton(),
            BBText.title(
              isReceived ? 'Amount received' : 'Amount sent',
            ),
            const Gap(4),
            AmountValue(isReceived: isReceived, amtStr: amtStr, units: units),
            const Gap(24),
            if (!isSwapPending) ...[
              const BBText.title('Transaction ID'),
              const Gap(4),
              TxLink(txid: txid, tx: tx, unblindedUrl: unblindedUrl),
              const Gap(24),
            ],
            if (recipients.isNotEmpty &&
                recipientAddress.address.isNotEmpty) ...[
              const BBText.title('Recipient Bitcoin Address'),
              InkWell(
                onTap: () {
                  final url =
                      context.read<NetworkBloc>().state.explorerAddressUrl(
                            recipientAddress.address,
                            isLiquid: tx.isLiquid,
                          );
                  locator<Launcher>().launchApp(url);
                },
                child: BBText.body(recipientAddress.address, isBlue: true),
              ),
              const Gap(24),
            ],
            if (status.isNotEmpty && !isSwapPending) ...[
              const BBText.title(
                'Status',
              ),
              const Gap(4),
              BBText.titleLarge(
                status,
                isBold: true,
              ),
              const Gap(24),
            ],
            const BBText.title(
              'Network Fee',
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
                if (tx.feeRate != null) ...[
                  const Gap(4),
                  BBText.title(
                    '(${tx.feeRate?.toStringAsFixed(2)} sats/vB)',
                  ),
                ],
              ],
            ),
            const Gap(24),
            if (!isSwapPending) ...[
              BBText.title(
                isReceived ? 'Transaction received' : 'Transaction sent',
              ),
              const Gap(4),
              BBText.titleLarge(
                time,
                isBold: true,
              ),
              if (broadcastTime != null) ...[
                const Gap(24),
                const BBText.title(
                  'Sent Time',
                ),
                BBText.titleLarge(
                  timeago.format(broadcastTime),
                  isBold: true,
                ),
              ],
              const Gap(24),
            ],
            const BBText.title(
              'Change Label',
            ),
            const Gap(4),
            const TxLabelTextField(),
            const Gap(24),
            if (err.isNotEmpty) ...[
              const Gap(32),
              BBText.errorSmall(
                err,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class TxLink extends StatelessWidget {
  const TxLink({
    super.key,
    required this.txid,
    required this.tx,
    required this.unblindedUrl,
  });

  final String txid;
  final Transaction tx;
  final String unblindedUrl;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        final url = context.read<NetworkBloc>().state.explorerTxUrl(
              txid,
              isLiquid: tx.isLiquid,
              unblindedUrl: unblindedUrl,
            );
        locator<Launcher>().launchApp(url);
      },
      child: BBText.body(txid, isBlue: true),
    );
  }
}

class AmountValue extends StatelessWidget {
  const AmountValue({
    super.key,
    required this.isReceived,
    required this.amtStr,
    required this.units,
  });

  final bool isReceived;
  final String amtStr;
  final String units;

  @override
  Widget build(BuildContext context) {
    return Row(
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
    );
  }
}

class _SwapDetails extends StatelessWidget {
  const _SwapDetails();

  @override
  Widget build(BuildContext context) {
    final tx = context.select((TransactionCubit cubit) => cubit.state.tx);
    final status = context.select(
      (TransactionCubit cubit) => cubit.state.tx.swapTx?.status?.status,
    );
    final isLiq = tx.isLiquid;

    final swap = tx.swapTx;
    if (swap == null) return const SizedBox.shrink();
    final statusStr = swap.isChainSwap()
        ? status.getOnChainStr(swap.chainSwapDetails!.onChainType)
        : status.getStr(swap.isSubmarine());

    final amt = swap.amountForDisplay() ?? 0;
    final amount = context.select(
      (CurrencyCubit x) => x.state.getAmountInUnits(amt, removeText: true),
    );
    final isReceive = swap.isReverse();

    final date = tx.getDateTimeStr();

    final id = swap.id;
    final fees = swap.totalFees() ?? 0;
    final feesAmount = context.select(
      (CurrencyCubit x) => x.state.getAmountInUnits(fees, removeText: true),
    );

    final units = context.select(
      (CurrencyCubit cubit) => cubit.state.getUnitString(isLiquid: isLiq),
    );

    final isRefundedSend = swap.isSubmarine() && swap.refundedAny();

    final refundChildren = [
      const Gap(24),
      const BBText.title('Refund Tx ID'),
      const Gap(4),
      TxLink(
        txid: swap.claimTxid ?? tx.txid,
        tx: tx,
        unblindedUrl: tx.unblindedUrl,
      ),
    ];

    final lockupFee = swap.isReverse() ? 0 : tx.fee;
    final claimFee = swap.isReverse() ? tx.fee : swap.claimFees;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 800),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BBText.title(
              'Swap Amount',
            ),
            const Gap(4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Container(
                  transformAlignment: Alignment.center,
                  transform: Matrix4.identity()..rotateZ(isReceive ? 1 : -1),
                  child: const FaIcon(
                    FontAwesomeIcons.arrowRight,
                    size: 12,
                  ),
                ),
                const Gap(8),
                BBText.titleLarge(
                  amount,
                  isBold: true,
                ),
                const Gap(4),
                BBText.title(
                  units,
                  isBold: true,
                ),
              ],
            ),
            if (fees != 0) ...[
              const Gap(24),
              Row(
                children: [
                  const BBText.title('Total fees'),
                  IconButton(
                    icon: const Icon(Icons.info_outline),
                    iconSize: 22.0,
                    padding: EdgeInsets.zero,
                    color: context.colour.onPrimaryContainer,
                    onPressed: () {
                      FeePopUp.openPopup(
                        context,
                        lockupFee ?? 0,
                        claimFee ?? 0,
                        swap.boltzFees ?? 0,
                      );
                    },
                  ),
                ],
              ),
              const Gap(4),
              Row(
                children: [
                  BBText.titleLarge(feesAmount, isBold: true),
                  const Gap(4),
                  BBText.title(units, isBold: true),
                ],
              ),
            ],
            const Gap(24),
            if (id.isNotEmpty) ...[
              const BBText.title('Swap ID'),
              const Gap(4),
              Row(
                children: [
                  BBText.titleLarge(
                    id,
                    isBold: true,
                  ),
                  IconButton(
                    onPressed: () async {
                      if (locator.isRegistered<Clippboard>()) {
                        await locator<Clippboard>().copy(id);
                      }

                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard')),
                      );
                    },
                    iconSize: 16,
                    color: Colors.blue,
                    icon: const Icon(Icons.copy),
                  ),
                ],
              ),
            ],
            const Gap(16),
            if (statusStr != null) ...[
              const BBText.title('Status'),
              const Gap(4),
              BBText.titleLarge(
                statusStr.$1,
                isBold: true,
              ),
              const Gap(4),
              BBText.bodySmall(
                statusStr.$2,
              ),
            ],
            if (isRefundedSend) ...refundChildren,
            const Gap(24),
            if (date.isNotEmpty) ...[
              BBText.title(
                isReceive ? 'Tranaction received' : 'Transaction sent',
              ),
              const Gap(4),
              BBText.titleLarge(date, isBold: true),
              const Gap(32),
            ],
            const Gap(24),
          ],
        ),
      ),
    );
  }
}

class _OnchainSwapDetails extends StatelessWidget {
  const _OnchainSwapDetails();

  @override
  Widget build(BuildContext context) {
    final tx = context.select((TransactionCubit cubit) => cubit.state.tx);
    final status = context.select(
      (TransactionCubit cubit) => cubit.state.tx.swapTx?.status?.status,
    );
    final isLiq = tx.isLiquid;

    final swap = tx.swapTx;
    if (swap == null) return const SizedBox.shrink();
    final statusStr = swap.isChainSwap()
        ? status.getOnChainStr(swap.chainSwapDetails!.onChainType)
        : status.getStr(swap.isSubmarine());

    final amt = swap.amountForDisplay() ?? 0;
    context.select(
      (CurrencyCubit x) => x.state.getAmountInUnits(amt, removeText: true),
    );
    swap.isReverse();

    final date = tx.getDateTimeStr();

    final id = swap.id;
    final fees = swap.totalFees() ?? 0;
    final feesAmount = context.select(
      (CurrencyCubit x) => x.state.getAmountInUnits(fees, removeText: true),
    );

    final units = context.select(
      (CurrencyCubit cubit) => cubit.state.getUnitString(isLiquid: isLiq),
    );

    final fromWallet =
        context.select((HomeBloc cubit) => cubit.state.getWalletFromTx(tx));
    final fromStatus = tx.height == null || tx.height == 0 || tx.timestamp == 0;
    final fromStatusStr = fromStatus ? 'Pending' : 'Confirmed';
    final fromAmtStr = context.select(
      (CurrencyCubit cubit) => cubit.state
          .getAmountInUnits(tx.getNetAmountIncludingFees(), removeText: true),
    );
    final fromUnits = context.select(
      (CurrencyCubit cubit) => cubit.state.getUnitString(isLiquid: isLiq),
    );

    final toWallet = context.select(
      (HomeBloc cubit) =>
          cubit.state.getWalletById(swap.chainSwapDetails!.toWalletId),
    );
    final isRefundedReceive = swap.isChainReceive() && swap.refundedOnchain();

    final walletReceiveRefundedTo =
        isRefundedReceive && swap.isLiquid() ? 'Instant' : 'Secure';
    final isRefundedChainSend =
        (swap.isChainSelf() || swap.isChainSend()) && swap.refundedOnchain();

    Transaction? receiveTx;
    String? toAmtStr;
    String? toUnits;
    String? toStatusStr;

    if (swap.claimTxid != null && toWallet != null) {
      receiveTx = toWallet.getTxWithId(swap.claimTxid!);
      if (receiveTx != null) {
        toAmtStr = context.select(
          (CurrencyCubit cubit) => cubit.state.getAmountInUnits(
            receiveTx!.getNetAmountIncludingFees().abs(),
            removeText: true,
          ),
        );
        toUnits = context.select(
          (CurrencyCubit cubit) => cubit.state.getUnitString(isLiquid: isLiq),
        );

        final toStatus = receiveTx.height == null ||
            receiveTx.height == 0 ||
            receiveTx.timestamp == 0;
        toStatusStr = toStatus ? 'Pending' : 'Confirmed';
      }
    }

    final selfFromWalletChildren = [
      const BBText.body(
        'From wallet',
        textAlign: TextAlign.center,
      ),
      const Gap(24),
      const BBText.title(
        'From wallet',
      ),
      const Gap(4),
      BBText.titleLarge(
        fromWallet?.name ?? '',
        isBold: true,
      ),
      const Gap(24),
      const BBText.title(
        'From: Amount',
      ),
      const Gap(4),
      AmountValue(
        isReceived: tx.isReceived(),
        amtStr: fromAmtStr,
        units: fromUnits,
      ),
      const Gap(24),
      const BBText.title('From: Tx ID'),
      const Gap(4),
      TxLink(
        txid: swap.lockupTxid ?? tx.txid,
        tx: tx,
        unblindedUrl: tx.unblindedUrl,
      ),
      const Gap(24),
      const BBText.title(
        'From: Status',
      ),
      const Gap(4),
      BBText.titleLarge(
        fromStatusStr,
        isBold: true,
      ),
      const Gap(24),
    ];

    final externalFromWalletChildren = [
      const BBText.body(
        'From wallet',
        textAlign: TextAlign.center,
      ),
      const Gap(24),
      const BBText.title(
        'Swap is from an external wallet',
      ),
      const Gap(24),
    ];

    final refundedReceiveChildren = [
      BBText.bodySmall(
        'to $walletReceiveRefundedTo wallet.',
        isBold: true,
      ),
      const Gap(24),
      const BBText.bodySmall(
        'External wallet may have sent the wrong amount.',
        isBold: true,
      ),
      const Gap(24),
      const BBText.title('Refund Tx ID'),
      const Gap(4),
      TxLink(
        txid: swap.claimTxid ?? tx.txid,
        tx: tx,
        unblindedUrl: tx.unblindedUrl,
      ),
    ];

    final refundedSendChildren = [
      const Gap(24),
      const BBText.title('Refund Tx ID'),
      const Gap(4),
      TxLink(
        txid: swap.claimTxid ?? tx.txid,
        tx: tx,
        unblindedUrl: tx.unblindedUrl,
      ),
    ];

    final selfToWalletChildren = [
      const BBText.body(
        'To wallet',
        textAlign: TextAlign.center,
      ),
      const Gap(24),
      const BBText.title(
        'To wallet',
      ),
      const Gap(4),
      BBText.titleLarge(
        toWallet?.name ?? '',
        isBold: true,
      ),
      const Gap(24),
      const BBText.title(
        'To: Amount',
      ),
      const Gap(4),
      if (receiveTx == null)
        const BBText.titleLarge(
          'Not claimed yet',
          isBold: true,
        ),
      if (receiveTx != null)
        AmountValue(
          isReceived: receiveTx.isReceived(),
          amtStr: toAmtStr!,
          units: toUnits!,
        ),
      const Gap(24),
      const BBText.title(
        'To: Tx ID',
      ),
      const Gap(4),
      if (receiveTx == null)
        const BBText.titleLarge(
          'Not claimed yet',
          isBold: true,
        ),
      if (receiveTx != null)
        TxLink(
          txid: receiveTx.txid,
          tx: receiveTx,
          unblindedUrl: receiveTx.unblindedUrl,
        ),
      const Gap(24),
      const BBText.title(
        'To: Status',
      ),
      const Gap(4),
      if (receiveTx == null)
        const BBText.titleLarge(
          'Not claimed yet',
          isBold: true,
        ),
      if (receiveTx != null)
        BBText.titleLarge(
          toStatusStr!,
          isBold: true,
        ),
      const Gap(24),
    ];

    final externalToWalletChildren = [
      const BBText.body(
        'To wallet',
        textAlign: TextAlign.center,
      ),
      const Gap(24),
      const BBText.title(
        'Swap is paying to an external wallet',
      ),
      const Gap(24),
    ];

    final lockupFee = swap.isChainReceive() ? 0 : tx.fee;
    final claimFee = swap.isChainReceive() ? tx.fee : swap.claimFees;

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 800),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (tx.timestamp == 0 && tx.isLiquid == false) ...[
              const BumpFeesButton(),
              const Gap(24),
            ],
            if (swap.chainSwapDetails?.onChainType ==
                    OnChainSwapType.selfSwap ||
                swap.chainSwapDetails?.onChainType == OnChainSwapType.sendSwap)
              ...selfFromWalletChildren,
            if (swap.chainSwapDetails?.onChainType ==
                    OnChainSwapType.receiveSwap &&
                !isRefundedReceive)
              ...externalFromWalletChildren,
            if (swap.chainSwapDetails?.onChainType ==
                    OnChainSwapType.selfSwap ||
                swap.chainSwapDetails?.onChainType ==
                        OnChainSwapType.receiveSwap &&
                    !isRefundedReceive)
              ...selfToWalletChildren,
            if (swap.chainSwapDetails?.onChainType == OnChainSwapType.sendSwap)
              ...externalToWalletChildren,
            const BBText.body(
              'Swap details',
              textAlign: TextAlign.center,
            ),
            const BBText.title(
              'Swap time',
            ),
            const Gap(4),
            BBText.titleLarge(
              date,
              isBold: true,
            ),
            const Gap(24),
            if (fees != 0) ...[
              Row(
                children: [
                  const BBText.title('Total fees'),
                  IconButton(
                    icon: const Icon(Icons.info_outline),
                    iconSize: 22.0,
                    padding: EdgeInsets.zero,
                    color: context.colour.onPrimaryContainer,
                    onPressed: () {
                      FeePopUp.openPopup(
                        context,
                        lockupFee ?? 0,
                        claimFee ?? 0,
                        swap.boltzFees ?? 0,
                      );
                    },
                  ),
                ],
              ),
              const Gap(4),
              Row(
                children: [
                  BBText.titleLarge(feesAmount, isBold: true),
                  const Gap(4),
                  BBText.title(units, isBold: true),
                ],
              ),
              const Gap(24),
            ],
            if (id.isNotEmpty) ...[
              const BBText.title('Swap ID'),
              const Gap(4),
              Row(
                children: [
                  BBText.titleLarge(
                    id,
                    isBold: true,
                  ),
                  IconButton(
                    onPressed: () async {
                      if (locator.isRegistered<Clippboard>()) {
                        await locator<Clippboard>().copy(id);
                      }

                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard')),
                      );
                    },
                    iconSize: 16,
                    color: Colors.blue,
                    icon: const Icon(Icons.copy),
                  ),
                ],
              ),
              const Gap(24),
            ],
            if (statusStr != null) ...[
              const BBText.title('Status'),
              const Gap(4),
              BBText.titleLarge(
                statusStr.$1,
                isBold: true,
              ),
              const Gap(4),
              BBText.bodySmall(
                statusStr.$2,
              ),
            ],
            if (isRefundedReceive) ...refundedReceiveChildren,
            if (isRefundedChainSend) ...refundedSendChildren,
          ],
        ),
      ),
    );
  }
}
