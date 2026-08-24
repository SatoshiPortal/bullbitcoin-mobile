import 'dart:async';

import 'package:bb_mobile/core/entities/signer_entity.dart' show SignerEntity;
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_order_usercase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/watch_swap_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_transaction_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_transaction_by_tx_id_usecase.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_transaction_order_swap_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_transactions_by_tx_id_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/broadcast_original_transaction_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_payjoin_by_id_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_payjoin_by_tx_id_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/watch_payjoin_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/watch_transaction_order_swap_usecase.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_error.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transaction_details/transaction_details_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork, Sats;

class _MockGetWalletUsecase extends Mock implements GetWalletUsecase {}

class _MockGetTransactionsByTxIdUsecase extends Mock
    implements GetTransactionsByTxIdUsecase {}

class _MockGetWalletTransactionUsecase extends Mock
    implements GetWalletTransactionUsecase {}

class _MockWatchWalletTransactionByTxIdUsecase extends Mock
    implements WatchWalletTransactionByTxIdUsecase {}

class _MockGetSwapUsecase extends Mock implements GetSwapUsecase {}

class _MockGetPayjoinByIdUsecase extends Mock
    implements GetPayjoinByIdUsecase {}

class _MockGetPayjoinByTxIdUsecase extends Mock
    implements GetPayjoinByTxIdUsecase {}

class _MockGetOrderUsecase extends Mock implements GetOrderUsecase {}

class _MockWatchSwapUsecase extends Mock implements WatchSwapUsecase {}

class _MockWatchPayjoinUsecase extends Mock implements WatchPayjoinUsecase {}

class _MockLabelsFacade extends Mock implements LabelsFacade {}

class _MockBroadcastOriginalTransactionUsecase extends Mock
    implements BroadcastOriginalTransactionUsecase {}

class _MockGetTransactionOrderSwapUsecase extends Mock
    implements GetTransactionOrderSwapUsecase {}

class _MockWatchTransactionOrderSwapUsecase extends Mock
    implements WatchTransactionOrderSwapUsecase {}

Wallet _testWallet({String origin = 'w1'}) => Wallet(
  origin: origin,
  network: Network.bitcoinMainnet,
  xpubFingerprint: '00000000',
  scriptType: ScriptType.bip84,
  xpub: '',
  externalPublicDescriptor: '',
  internalPublicDescriptor: '',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.zero,
);

WalletTransaction _walletTx({
  required String txId,
  String walletId = 'w1',
  Network network = Network.bitcoinMainnet,
  WalletTransactionDirection direction = WalletTransactionDirection.outgoing,
  int amountSat = 50000,
  List<Label> labels = const [],
}) => WalletTransaction(
  walletId: walletId,
  network: network,
  direction: direction,
  status: WalletTransactionStatus.pending,
  txId: txId,
  amountSat: amountSat,
  feeSat: 500,
  vsize: 150,
  inputs: const [],
  outputs: const [],
  labels: labels,
  isRbf: false,
);

PayjoinSenderSession _sender({
  required PayjoinStatus status,
  String? txId,
  String? proposalPsbt,
}) => PayjoinSenderSession(
  status: status,
  uri: 'bitcoin:tb1qsender?pj=https://payjo.in',
  network: BitcoinNetwork.testnet,
  walletId: 'w1',
  originalTransactionId: 'sender-orig-txid',
  amount: Sats.fromInt(50000),
  createdAt: DateTime(2026),
  expiresAt: DateTime(2026).add(const Duration(minutes: 1)),
  transactionId: txId,
  hasProposal: proposalPsbt != null,
);

PayjoinReceiverSession _receiver({
  PayjoinStatus status = PayjoinStatus.requested,
  String? txId,
  bool hasProposal = false,
}) => PayjoinReceiverSession(
  status: status,
  id: 'receiver-session',
  network: BitcoinNetwork.testnet,
  walletId: 'w1',
  payjoinUri: 'bitcoin:tb1qreceiver?pj=https://payjo.in/receiver-session',
  createdAt: DateTime(2026),
  expiresAt: DateTime(2026).add(const Duration(minutes: 1)),
  originalTransactionId: 'receiver-orig-txid',
  hasOriginalTransaction: true,
  transactionId: txId,
  hasProposal: hasProposal,
);

void main() {
  late _MockGetWalletUsecase getWallet;
  late _MockGetTransactionsByTxIdUsecase getTransactionsByTxId;
  late _MockGetWalletTransactionUsecase getWalletTransaction;
  late _MockGetPayjoinByIdUsecase getPayjoinById;
  late _MockGetPayjoinByTxIdUsecase getPayjoinByTxId;
  late _MockWatchPayjoinUsecase watchPayjoin;
  late _MockWatchWalletTransactionByTxIdUsecase watchWalletTransactionByTxId;
  late _MockBroadcastOriginalTransactionUsecase broadcastOriginalTransaction;
  late _MockGetTransactionOrderSwapUsecase getTransactionOrderSwap;
  late _MockWatchTransactionOrderSwapUsecase watchTransactionOrderSwap;
  late _MockGetOrderUsecase getOrder;

  TransactionDetailsCubit buildCubit() => TransactionDetailsCubit(
    getWalletUsecase: getWallet,
    getTransactionsByTxIdUsecase: getTransactionsByTxId,
    getWalletTransactionUsecase: getWalletTransaction,
    getTransactionOrderSwapUsecase: getTransactionOrderSwap,
    watchWalletTransactionByTxIdUsecase: watchWalletTransactionByTxId,
    getSwapUsecase: _MockGetSwapUsecase(),
    getPayjoinByIdUsecase: getPayjoinById,
    getPayjoinByTxIdUsecase: getPayjoinByTxId,
    getOrderUsecase: getOrder,
    watchSwapUsecase: _MockWatchSwapUsecase(),
    watchPayjoinUsecase: watchPayjoin,
    watchTransactionOrderSwapUsecase: watchTransactionOrderSwap,
    labelsFacade: _MockLabelsFacade(),
    broadcastOriginalTransactionUsecase: broadcastOriginalTransaction,
  );

  setUpAll(() {
    registerFallbackValue(_sender(status: PayjoinStatus.requested));
  });

  setUp(() {
    getWallet = _MockGetWalletUsecase();
    getTransactionsByTxId = _MockGetTransactionsByTxIdUsecase();
    getWalletTransaction = _MockGetWalletTransactionUsecase();
    getPayjoinById = _MockGetPayjoinByIdUsecase();
    getPayjoinByTxId = _MockGetPayjoinByTxIdUsecase();
    watchPayjoin = _MockWatchPayjoinUsecase();
    watchWalletTransactionByTxId = _MockWatchWalletTransactionByTxIdUsecase();
    broadcastOriginalTransaction = _MockBroadcastOriginalTransactionUsecase();
    getTransactionOrderSwap = _MockGetTransactionOrderSwapUsecase();
    watchTransactionOrderSwap = _MockWatchTransactionOrderSwapUsecase();
    getOrder = _MockGetOrderUsecase();

    when(() => broadcastOriginalTransaction.canExecute(any())).thenAnswer((
      invocation,
    ) async {
      final payjoin = invocation.positionalArguments.single as PayjoinSession;
      return payjoin.canManuallyBroadcastOriginal;
    });

    when(
      () => getWallet.execute(any(), sync: any(named: 'sync')),
    ).thenAnswer((_) async => _testWallet());
    // By default the forced sync'd lookup finds nothing — individual tests
    // override it to simulate the broadcast becoming visible on demand. The
    // usecase returns a Result now, so the "nothing" case is Ok(null).
    when(
      () => getWalletTransaction.execute(
        txId: any(named: 'txId'),
        walletId: any(named: 'walletId'),
        sync: any(named: 'sync'),
      ),
    ).thenAnswer(
      (_) async =>
          const Ok<WalletTransaction?, WalletTransactionLookupFailure>(null),
    );
    when(
      () => watchPayjoin.execute(ids: any(named: 'ids')),
    ).thenAnswer((_) => const Stream.empty());
    // _loadDetailsByPayjoinId always arms a watcher for both payjoin.txId
    // (when set) and payjoin.originalTxId (always set on our fixtures) —
    // an unstubbed call here throws synchronously (mocktail returns null,
    // and .listen() on null throws), silently short-circuiting
    // _loadDetailsByPayjoinId's try/catch before state.transaction is ever
    // populated, which would make every guard test a false positive (the
    // guard never actually runs because state.payjoin stayed null).
    when(
      () => watchWalletTransactionByTxId.execute(
        txId: any(named: 'txId'),
        walletId: any(named: 'walletId'),
      ),
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => watchTransactionOrderSwap.execute(any()),
    ).thenAnswer((_) => const Stream.empty());
  });

  test(
    'loads the destination wallet transaction for a Lightning receive',
    () async {
      final orderSwap = _receiveOrderSwap();
      final walletTransaction = _walletTx(
        txId: 'liquid-payout-txid',
        walletId: 'liquid-wallet',
        network: Network.liquidMainnet,
        direction: WalletTransactionDirection.incoming,
        amountSat: 19800,
        labels: [
          Label.tx(id: 1, transactionId: 'liquid-payout-txid', label: 'coffee'),
        ],
      );
      when(
        () => getTransactionOrderSwap.execute(orderSwap.localId),
      ).thenAnswer((_) async => orderSwap);
      when(
        () => getWalletTransaction.execute(
          txId: 'liquid-payout-txid',
          walletId: 'liquid-wallet',
          sync: false,
        ),
      ).thenAnswer(
        (_) async => Ok<WalletTransaction?, WalletTransactionLookupFailure>(
          walletTransaction,
        ),
      );
      when(
        () => getWallet.execute('liquid-wallet', sync: false),
      ).thenAnswer((_) async => _testWallet(origin: 'liquid-wallet'));

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.initByOrderSwapLocalId(orderSwap.localId);

      expect(cubit.state.transaction?.orderSwap, orderSwap);
      expect(cubit.state.wallet?.id, 'liquid-wallet');
      expect(cubit.state.transaction?.walletTransaction, walletTransaction);
      expect(cubit.state.transaction?.txId, 'liquid-payout-txid');
      expect(cubit.state.transaction?.labels?.single.label, 'coffee');
      expect(
        cubit.state.transaction?.orderSwapDestinationAddress,
        'liquid-address',
      );
      expect(cubit.state.getAmountReceived(), 19800);
    },
  );

  test(
    'loads both wallets before exposing internal transfer details',
    () async {
      final sourceWallet = Completer<Wallet?>();
      final destinationWallet = Completer<Wallet?>();
      final walletTransaction =
          Completer<
            Result<WalletTransaction?, WalletTransactionLookupFailure>
          >();
      final orderSwap = OrderSwapRecord(
        localId: 'transfer-local',
        purpose: OrderSwapPurpose.transfer,
        environment: OrderSwapEnvironment.mainnet,
        inNetwork: OrderSwapNetwork.bitcoin,
        outNetwork: OrderSwapNetwork.liquid,
        isInAmountFixed: true,
        requestedAmountSat: BigInt.from(20000),
        sourceWalletId: 'source-wallet',
        destinationWalletId: 'destination-wallet',
        destination: 'liquid-address',
        fallback: 'bitcoin-address',
        localPayinTransactionId: 'bitcoin-payin-txid',
        order: OrderSwap(
          orderId: 'transfer-order',
          orderNumber: 2,
          inNetwork: OrderSwapNetwork.bitcoin,
          outNetwork: OrderSwapNetwork.liquid,
          payinAmountSat: BigInt.from(20000),
          payoutAmountSat: BigInt.from(19800),
          payinCurrency: 'BTC',
          payoutCurrency: 'LBTC',
          payinMethod: 'Bitcoin',
          payoutMethod: 'Liquid',
          orderType: 'Swap',
          orderStatus: 'Pending',
          payinStatus: 'Pending',
          payoutStatus: 'Pending',
          messageCode: 'PENDING',
          createdAt: DateTime.utc(2026),
          confirmationDeadline: DateTime.utc(2026, 1, 1, 0, 5),
        ),
        createdAt: DateTime.utc(2026),
        localStatus: OrderSwapLocalStatus.awaitingUserConfirmation,
      );
      when(
        () => getTransactionOrderSwap.execute(orderSwap.localId),
      ).thenAnswer((_) async => orderSwap);
      when(
        () => getWallet.execute('source-wallet', sync: false),
      ).thenAnswer((_) => sourceWallet.future);
      when(
        () => getWallet.execute('destination-wallet', sync: false),
      ).thenAnswer((_) => destinationWallet.future);
      when(
        () => getWalletTransaction.execute(
          txId: any(named: 'txId'),
          walletId: 'source-wallet',
          sync: false,
        ),
      ).thenAnswer((_) => walletTransaction.future);

      final cubit = buildCubit();
      addTearDown(cubit.close);
      final load = cubit.initByOrderSwapLocalId(orderSwap.localId);
      await pumpEventQueue();

      verify(() => getWallet.execute('source-wallet', sync: false)).called(1);
      verify(
        () => getWallet.execute('destination-wallet', sync: false),
      ).called(1);
      verify(
        () => getWalletTransaction.execute(
          txId: any(named: 'txId'),
          walletId: 'source-wallet',
          sync: false,
        ),
      ).called(1);
      expect(cubit.state.isLoading, isTrue);

      sourceWallet.complete(_testWallet(origin: 'source-wallet'));
      destinationWallet.complete(_testWallet(origin: 'destination-wallet'));
      walletTransaction.complete(
        Ok(_walletTx(txId: orderSwap.canonicalWalletTransactionId!)),
      );
      await load;

      expect(cubit.state.wallet?.id, 'source-wallet');
      expect(cubit.state.counterpartWallet?.id, 'destination-wallet');
      expect(cubit.state.transaction?.orderSwap, orderSwap);
      expect(cubit.state.walletTransaction, isNotNull);
      expect(cubit.state.isLoading, isFalse);
    },
  );

  test('order swap updates preserve the initial detail row data', () async {
    final initial = _receiveOrderSwap();
    final walletTransaction = _walletTx(
      txId: initial.canonicalWalletTransactionId!,
      walletId: initial.canonicalWalletId!,
      network: Network.liquidMainnet,
      direction: WalletTransactionDirection.incoming,
      labels: [
        Label.tx(
          id: 1,
          transactionId: initial.canonicalWalletTransactionId!,
          label: 'coffee',
        ),
      ],
    );
    final updates = StreamController<OrderSwapRecord>.broadcast();
    addTearDown(updates.close);
    when(
      () => getTransactionOrderSwap.execute(initial.localId),
    ).thenAnswer((_) async => initial);
    when(
      () => getWalletTransaction.execute(
        txId: initial.canonicalWalletTransactionId!,
        walletId: initial.canonicalWalletId!,
        sync: false,
      ),
    ).thenAnswer(
      (_) async => Ok<WalletTransaction?, WalletTransactionLookupFailure>(
        walletTransaction,
      ),
    );
    when(
      () => watchTransactionOrderSwap.execute(initial.localId),
    ).thenAnswer((_) => updates.stream);

    final cubit = buildCubit();
    addTearDown(cubit.close);
    await cubit.initByOrderSwapLocalId(initial.localId);
    clearInteractions(getWallet);
    clearInteractions(getWalletTransaction);
    final updating = _copyOrderSwap(
      initial,
      localStatus: OrderSwapLocalStatus.payoutInProgress,
    );
    final completed = _copyOrderSwap(
      initial,
      localStatus: OrderSwapLocalStatus.completed,
    );

    updates.add(updating);
    updates.add(completed);
    await pumpEventQueue();

    expect(cubit.state.transaction?.orderSwap, completed);
    expect(cubit.state.walletTransaction, walletTransaction);
    expect(cubit.state.transaction?.labels?.single.label, 'coffee');
    verifyNever(() => getWallet.execute(any(), sync: any(named: 'sync')));
    verifyNever(
      () => getWalletTransaction.execute(
        txId: any(named: 'txId'),
        walletId: any(named: 'walletId'),
        sync: any(named: 'sync'),
      ),
    );
  });

  test(
    'order swap update clears a stale canonical wallet transaction',
    () async {
      final initial = _receiveOrderSwap();
      final walletTransaction = _walletTx(
        txId: initial.canonicalWalletTransactionId!,
        walletId: initial.canonicalWalletId!,
        network: Network.liquidMainnet,
        direction: WalletTransactionDirection.incoming,
      );
      final updates = StreamController<OrderSwapRecord>.broadcast();
      addTearDown(updates.close);
      when(
        () => getTransactionOrderSwap.execute(initial.localId),
      ).thenAnswer((_) async => initial);
      when(
        () => getWalletTransaction.execute(
          txId: initial.canonicalWalletTransactionId!,
          walletId: initial.canonicalWalletId!,
          sync: false,
        ),
      ).thenAnswer(
        (_) async => Ok<WalletTransaction?, WalletTransactionLookupFailure>(
          walletTransaction,
        ),
      );
      when(
        () => watchTransactionOrderSwap.execute(initial.localId),
      ).thenAnswer((_) => updates.stream);

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.initByOrderSwapLocalId(initial.localId);
      final updated = _copyOrderSwap(
        initial,
        localStatus: OrderSwapLocalStatus.completed,
        order: _copyOrderSwapOrder(
          initial.order!,
          liquidTransactionId: 'replacement-txid',
        ),
      );

      updates.add(updated);
      await pumpEventQueue();

      expect(cubit.state.transaction?.orderSwap, updated);
      expect(cubit.state.walletTransaction, isNull);
      expect(cubit.state.transaction?.txId, 'replacement-txid');
    },
  );

  test('adds the wallet transaction after background sync completes', () async {
    final orderSwap = _receiveOrderSwap();
    final walletTransactions = StreamController<WalletTransaction>.broadcast();
    addTearDown(walletTransactions.close);
    when(
      () => getTransactionOrderSwap.execute(orderSwap.localId),
    ).thenAnswer((_) async => orderSwap);
    when(
      () => watchWalletTransactionByTxId.execute(
        txId: orderSwap.canonicalWalletTransactionId!,
        walletId: orderSwap.canonicalWalletId!,
      ),
    ).thenAnswer((_) => walletTransactions.stream);

    final cubit = buildCubit();
    addTearDown(cubit.close);
    await cubit.initByOrderSwapLocalId(orderSwap.localId);
    expect(cubit.state.walletTransaction, isNull);

    final walletTransaction = _walletTx(
      txId: orderSwap.canonicalWalletTransactionId!,
      walletId: orderSwap.canonicalWalletId!,
      network: Network.liquidMainnet,
      direction: WalletTransactionDirection.incoming,
    );
    walletTransactions.add(walletTransaction);
    await pumpEventQueue();

    expect(cubit.state.walletTransaction, walletTransaction);
    expect(cubit.state.transaction?.orderSwap, orderSwap);
  });

  test('keeps a wallet sync result emitted during the initial load', () async {
    final orderSwap = _receiveOrderSwap();
    final walletTransactionLookup =
        Completer<Result<WalletTransaction?, WalletTransactionLookupFailure>>();
    final walletTransactions = StreamController<WalletTransaction>.broadcast();
    addTearDown(walletTransactions.close);
    when(
      () => getTransactionOrderSwap.execute(orderSwap.localId),
    ).thenAnswer((_) async => orderSwap);
    when(
      () => getWalletTransaction.execute(
        txId: orderSwap.canonicalWalletTransactionId!,
        walletId: orderSwap.canonicalWalletId!,
        sync: false,
      ),
    ).thenAnswer((_) => walletTransactionLookup.future);
    when(
      () => watchWalletTransactionByTxId.execute(
        txId: orderSwap.canonicalWalletTransactionId!,
        walletId: orderSwap.canonicalWalletId!,
      ),
    ).thenAnswer((_) => walletTransactions.stream);

    final cubit = buildCubit();
    addTearDown(cubit.close);
    final load = cubit.initByOrderSwapLocalId(orderSwap.localId);
    await pumpEventQueue();

    final walletTransaction = _walletTx(
      txId: orderSwap.canonicalWalletTransactionId!,
      walletId: orderSwap.canonicalWalletId!,
      network: Network.liquidMainnet,
      direction: WalletTransactionDirection.incoming,
    );
    walletTransactions.add(walletTransaction);
    await pumpEventQueue();
    walletTransactionLookup.complete(
      Ok(
        _walletTx(
          txId: orderSwap.canonicalWalletTransactionId!,
          walletId: orderSwap.canonicalWalletId!,
          network: Network.liquidMainnet,
          direction: WalletTransactionDirection.incoming,
          amountSat: 1,
        ),
      ),
    );
    await load;

    expect(cubit.state.walletTransaction, walletTransaction);
    expect(cubit.state.transaction?.orderSwap, orderSwap);
  });

  test('watches a replacement canonical wallet transaction', () async {
    final initial = _receiveOrderSwap();
    final orderUpdates = StreamController<OrderSwapRecord>.broadcast();
    final replacementTransactions =
        StreamController<WalletTransaction>.broadcast();
    addTearDown(orderUpdates.close);
    addTearDown(replacementTransactions.close);
    when(
      () => getTransactionOrderSwap.execute(initial.localId),
    ).thenAnswer((_) async => initial);
    when(
      () => watchTransactionOrderSwap.execute(initial.localId),
    ).thenAnswer((_) => orderUpdates.stream);
    when(
      () => watchWalletTransactionByTxId.execute(
        txId: 'replacement-txid',
        walletId: initial.canonicalWalletId!,
      ),
    ).thenAnswer((_) => replacementTransactions.stream);

    final cubit = buildCubit();
    addTearDown(cubit.close);
    await cubit.initByOrderSwapLocalId(initial.localId);
    final updated = _copyOrderSwap(
      initial,
      localStatus: OrderSwapLocalStatus.completed,
      order: _copyOrderSwapOrder(
        initial.order!,
        liquidTransactionId: 'replacement-txid',
      ),
    );
    orderUpdates.add(updated);
    await pumpEventQueue();

    final replacement = _walletTx(
      txId: 'replacement-txid',
      walletId: initial.canonicalWalletId!,
      network: Network.liquidMainnet,
      direction: WalletTransactionDirection.incoming,
    );
    replacementTransactions.add(replacement);
    await pumpEventQueue();

    expect(cubit.state.walletTransaction, replacement);
    expect(cubit.state.transaction?.orderSwap, updated);
  });

  test('recovers a failed initial load from an order update', () async {
    final orderSwap = _receiveOrderSwap();
    final updates = StreamController<OrderSwapRecord>.broadcast();
    addTearDown(updates.close);
    var attempts = 0;
    when(() => getTransactionOrderSwap.execute(orderSwap.localId)).thenAnswer((
      _,
    ) async {
      if (attempts++ == 0) throw TransactionNotFoundError();
      return orderSwap;
    });
    when(
      () => watchTransactionOrderSwap.execute(orderSwap.localId),
    ).thenAnswer((_) => updates.stream);

    final cubit = buildCubit();
    addTearDown(cubit.close);
    await cubit.initByOrderSwapLocalId(orderSwap.localId);
    expect(cubit.state.transaction, isNull);

    updates.add(orderSwap);
    await pumpEventQueue();

    expect(cubit.state.transaction?.orderSwap, orderSwap);
    expect(cubit.state.err, isNull);
    expect(cubit.state.notFoundError, isNull);
  });

  test('retries the wallet transaction watcher after a stream error', () async {
    final orderSwap = _receiveOrderSwap();
    final orderUpdates = StreamController<OrderSwapRecord>.broadcast();
    final firstWatcher = StreamController<WalletTransaction>.broadcast();
    addTearDown(orderUpdates.close);
    addTearDown(firstWatcher.close);
    when(
      () => getTransactionOrderSwap.execute(orderSwap.localId),
    ).thenAnswer((_) async => orderSwap);
    when(
      () => watchTransactionOrderSwap.execute(orderSwap.localId),
    ).thenAnswer((_) => orderUpdates.stream);
    var watcherCalls = 0;
    when(
      () => watchWalletTransactionByTxId.execute(
        txId: orderSwap.canonicalWalletTransactionId!,
        walletId: orderSwap.canonicalWalletId!,
      ),
    ).thenAnswer((_) {
      watcherCalls++;
      return watcherCalls == 1 ? firstWatcher.stream : const Stream.empty();
    });

    final cubit = buildCubit();
    addTearDown(cubit.close);
    await cubit.initByOrderSwapLocalId(orderSwap.localId);
    firstWatcher.addError(StateError('watch failed'));
    await pumpEventQueue();

    orderUpdates.add(orderSwap);
    await pumpEventQueue();

    expect(watcherCalls, 2);
  });

  test('reports the underlying error from parallel wallet loading', () async {
    final orderSwap = _receiveOrderSwap();
    final failure = StateError('wallet unavailable');
    when(
      () => getTransactionOrderSwap.execute(orderSwap.localId),
    ).thenAnswer((_) async => orderSwap);
    when(
      () => getWallet.execute(orderSwap.canonicalWalletId!, sync: false),
    ).thenThrow(failure);

    final cubit = buildCubit();
    addTearDown(cubit.close);
    await cubit.initByOrderSwapLocalId(orderSwap.localId);

    expect(cubit.state.err, same(failure));
  });

  group('TransactionDetailsCubit.broadcastPayjoinOriginalTx guard', () {
    test(
      'does NOT broadcast once the session already completed via a real '
      'payjoin: re-broadcasting the lower-fee original would race an '
      'already-broadcast payjoin transaction spending the same inputs',
      () async {
        final payjoin = _sender(
          status: PayjoinStatus.completed,
          txId: 'real-payjoin-txid',
          proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
        );
        when(
          () => getPayjoinById.execute(payjoin.uri),
        ).thenAnswer((_) async => payjoin);

        final cubit = buildCubit();
        addTearDown(cubit.close);
        await cubit.initByPayjoinId(payjoin.uri);

        expect(await cubit.canBroadcastPayjoinOriginalTx(), isFalse);

        expect(cubit.broadcastPayjoinOriginalTx(), isFalse);

        verifyNever(() => broadcastOriginalTransaction.execute(any()));
        expect(cubit.state.isBroadcastingPayjoinOriginalTx, isFalse);
      },
    );

    test('does not broadcast once marked aborted', () async {
      final payjoin = _sender(status: PayjoinStatus.aborted);
      when(
        () => getPayjoinById.execute(payjoin.uri),
      ).thenAnswer((_) async => payjoin);

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.initByPayjoinId(payjoin.uri);

      expect(await cubit.canBroadcastPayjoinOriginalTx(), isFalse);

      expect(cubit.broadcastPayjoinOriginalTx(), isFalse);

      verifyNever(() => broadcastOriginalTransaction.execute(any()));
    });

    test('broadcasts while a proposal is not yet visible', () async {
      final payjoin = _sender(
        status: PayjoinStatus.proposed,
        proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
      );
      when(
        () => getPayjoinById.execute(payjoin.uri),
      ).thenAnswer((_) async => payjoin);

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.initByPayjoinId(payjoin.uri);

      expect(await cubit.canBroadcastPayjoinOriginalTx(), isTrue);

      final completed = _sender(status: PayjoinStatus.aborted);
      when(
        () => broadcastOriginalTransaction.execute(any()),
      ).thenAnswer((_) async => completed);

      expect(cubit.broadcastPayjoinOriginalTx(), isTrue);
      await pumpEventQueue();

      verify(() => broadcastOriginalTransaction.execute(payjoin)).called(1);
      expect(cubit.state.payjoin, completed);
    });

    test('broadcasts while waiting for a proposal (the legitimate manual '
        'fallback)', () async {
      final payjoin = _sender(status: PayjoinStatus.requested);
      when(
        () => getPayjoinById.execute(payjoin.uri),
      ).thenAnswer((_) async => payjoin);
      final completed = _sender(status: PayjoinStatus.aborted);
      when(
        () => broadcastOriginalTransaction.execute(any()),
      ).thenAnswer((_) async => completed);

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.initByPayjoinId(payjoin.uri);

      expect(await cubit.canBroadcastPayjoinOriginalTx(), isTrue);

      expect(cubit.broadcastPayjoinOriginalTx(), isTrue);
      await pumpEventQueue();

      verify(() => broadcastOriginalTransaction.execute(payjoin)).called(1);
      expect(cubit.state.payjoin, completed);
    });

    test(
      'loads full wallet transaction details after fallback broadcast',
      () async {
        final payjoin = _sender(status: PayjoinStatus.requested);
        final completed = _sender(status: PayjoinStatus.aborted);
        final walletTx = _walletTx(txId: completed.originalTxId);
        var broadcasted = false;
        when(
          () => getPayjoinById.execute(payjoin.uri),
        ).thenAnswer((_) async => broadcasted ? completed : payjoin);
        when(() => broadcastOriginalTransaction.execute(payjoin)).thenAnswer((
          _,
        ) async {
          broadcasted = true;
          return completed;
        });
        when(
          () => getWalletTransaction.execute(
            txId: completed.originalTxId,
            walletId: completed.walletId,
            sync: true,
          ),
        ).thenAnswer(
          (_) async =>
              Ok<WalletTransaction?, WalletTransactionLookupFailure>(walletTx),
        );
        when(
          () => getTransactionsByTxId.execute(completed.originalTxId),
        ).thenAnswer(
          (_) async => broadcasted
              ? [Transaction(walletTransaction: walletTx, payjoin: completed)]
              : [Transaction(payjoin: payjoin)],
        );

        final cubit = buildCubit();
        addTearDown(cubit.close);
        await cubit.initByPayjoinId(payjoin.uri);

        expect(cubit.broadcastPayjoinOriginalTx(), isTrue);
        await pumpEventQueue();

        expect(cubit.state.walletTransaction, walletTx);
        expect(cubit.state.payjoin, completed);
        expect(cubit.state.payjoin?.isAborted, isTrue);
      },
    );

    test('broadcasts the receiver fallback when it is available', () async {
      final payjoin = _receiver();
      when(
        () => getPayjoinById.execute(payjoin.id),
      ).thenAnswer((_) async => payjoin);
      final completed = _receiver(status: PayjoinStatus.aborted);
      when(
        () => broadcastOriginalTransaction.execute(any()),
      ).thenAnswer((_) async => completed);

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.initByPayjoinId(payjoin.id);

      expect(await cubit.canBroadcastPayjoinOriginalTx(), isTrue);
      expect(cubit.broadcastPayjoinOriginalTx(), isTrue);
      await pumpEventQueue();

      verify(() => broadcastOriginalTransaction.execute(payjoin)).called(1);
      expect(cubit.state.payjoin, completed);
    });

    test(
      'reloads without an error when fallback becomes unavailable',
      () async {
        final payjoin = _sender(status: PayjoinStatus.requested);
        final completed = _sender(
          status: PayjoinStatus.completed,
          txId: 'payjoin-txid',
        );
        var fetches = 0;
        when(
          () => getPayjoinById.execute(payjoin.id),
        ).thenAnswer((_) async => fetches++ == 0 ? payjoin : completed);
        when(
          () => broadcastOriginalTransaction.execute(payjoin),
        ).thenThrow(BroadcastOriginalTransactionUnavailableException());
        when(
          () => getWalletTransaction.execute(
            txId: completed.txId!,
            walletId: completed.walletId,
            sync: true,
          ),
        ).thenAnswer(
          (_) async =>
              const Ok<WalletTransaction?, WalletTransactionLookupFailure>(
                null,
              ),
        );
        when(
          () => getTransactionsByTxId.execute(any()),
        ).thenAnswer((_) async => [Transaction(payjoin: completed)]);

        final cubit = buildCubit();
        addTearDown(cubit.close);
        await cubit.initByPayjoinId(payjoin.id);

        expect(cubit.broadcastPayjoinOriginalTx(), isTrue);
        await pumpEventQueue();

        expect(cubit.state.payjoin, completed);
        expect(cubit.state.err, isNull);
        expect(cubit.state.isBroadcastingPayjoinOriginalTx, isFalse);
      },
    );

    test('allows a manual retry once the repository\'s own internal '
        'fallback also gave up (expired, proposalPsbt still set)', () async {
      final payjoin = _sender(
        status: PayjoinStatus.expired,
        proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
      );
      when(
        () => getPayjoinById.execute(payjoin.uri),
      ).thenAnswer((_) async => payjoin);
      final completed = _sender(status: PayjoinStatus.aborted);
      when(
        () => broadcastOriginalTransaction.execute(any()),
      ).thenAnswer((_) async => completed);

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.initByPayjoinId(payjoin.uri);

      expect(cubit.broadcastPayjoinOriginalTx(), isTrue);
      await pumpEventQueue();

      verify(() => broadcastOriginalTransaction.execute(payjoin)).called(1);
    });
  });

  group('TransactionDetailsCubit.initByPayjoinId broadcast resolution', () {
    test('refresh retries a failed init by Payjoin transaction id', () async {
      final payjoin = _sender(status: PayjoinStatus.requested);
      var attempts = 0;
      when(() => getPayjoinByTxId.execute('payjoin-txid')).thenAnswer((
        _,
      ) async {
        if (attempts++ == 0) throw Exception('storage unavailable');
        return payjoin;
      });
      when(
        () => getPayjoinById.execute(payjoin.id),
      ).thenAnswer((_) async => payjoin);
      when(
        () => getTransactionsByTxId.execute(any()),
      ).thenAnswer((_) async => [Transaction(payjoin: payjoin)]);

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.initByPayjoinTxId('payjoin-txid');

      expect(cubit.state.err, isNotNull);

      await cubit.refresh();

      verify(() => getPayjoinByTxId.execute('payjoin-txid')).called(2);
      expect(cubit.state.err, isNull);
      expect(cubit.state.payjoin, payjoin);
    });

    test(
      'resolves straight to the wallet transaction when the broadcast is '
      'already visible locally — the screen must show the pending bitcoin '
      'transaction, not payjoin-session-only data (observed live: a '
      'fallback-completed send showing a stale "requested" session)',
      () async {
        // Session row still lagging on requested, but the ORIGINAL
        // transaction (the fallback broadcast) is already in the wallet.
        final payjoin = _sender(status: PayjoinStatus.requested);
        when(
          () => getPayjoinById.execute(payjoin.uri),
        ).thenAnswer((_) async => payjoin);
        when(
          () => getTransactionsByTxId.execute('sender-orig-txid'),
        ).thenAnswer(
          (_) async => [
            Transaction(
              walletTransaction: _walletTx(txId: 'sender-orig-txid'),
              payjoin: payjoin,
            ),
          ],
        );

        final cubit = buildCubit();
        addTearDown(cubit.close);
        await cubit.initByPayjoinId(payjoin.uri);

        expect(cubit.state.transaction?.walletTransaction, isNotNull);
        expect(
          cubit.state.transaction?.walletTransaction?.txId,
          'sender-orig-txid',
        );
        // And the displayed payjoin status derives "aborted" (fallback)
        // from the original transaction being the one on-chain, despite
        // the stale session row.
        expect(
          cubit.state.transaction?.displayPayjoinStatus,
          PayjoinStatus.aborted,
        );
      },
    );

    test('prefers the payjoin transaction over the original when the session '
        'completed for real', () async {
      final payjoin = _sender(
        status: PayjoinStatus.completed,
        txId: 'real-payjoin-txid',
        proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
      );
      when(
        () => getPayjoinById.execute(payjoin.uri),
      ).thenAnswer((_) async => payjoin);
      when(() => getTransactionsByTxId.execute('real-payjoin-txid')).thenAnswer(
        (_) async => [
          Transaction(
            walletTransaction: _walletTx(txId: 'real-payjoin-txid'),
            payjoin: payjoin,
          ),
        ],
      );

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.initByPayjoinId(payjoin.uri);

      expect(
        cubit.state.transaction?.walletTransaction?.txId,
        'real-payjoin-txid',
      );
      expect(
        cubit.state.transaction?.displayPayjoinStatus,
        PayjoinStatus.completed,
      );
    });

    test('receiver with a published proposal syncs the negotiated transaction '
        'and converges from in progress to completed', () async {
      final payjoin = _receiver(
        status: PayjoinStatus.proposed,
        txId: 'receiver-payjoin-txid',
        hasProposal: true,
      );
      final completed = _receiver(
        status: PayjoinStatus.completed,
        txId: 'receiver-payjoin-txid',
        hasProposal: true,
      );
      var visible = false;
      when(
        () => getPayjoinById.execute(payjoin.id),
      ).thenAnswer((_) async => visible ? completed : payjoin);
      when(
        () => getTransactionsByTxId.execute('receiver-payjoin-txid'),
      ).thenAnswer(
        (_) async => [
          if (visible)
            Transaction(
              walletTransaction: _walletTx(txId: 'receiver-payjoin-txid'),
              payjoin: payjoin,
            )
          else
            Transaction(payjoin: payjoin),
        ],
      );
      when(
        () => getTransactionsByTxId.execute('receiver-orig-txid'),
      ).thenAnswer((_) async => [Transaction(payjoin: payjoin)]);
      when(
        () => getWalletTransaction.execute(
          txId: 'receiver-payjoin-txid',
          walletId: 'w1',
          sync: true,
        ),
      ).thenAnswer((_) async {
        visible = true;
        return Ok<WalletTransaction?, WalletTransactionLookupFailure>(
          _walletTx(txId: 'receiver-payjoin-txid'),
        );
      });

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.initByPayjoinId(payjoin.id);

      expect(cubit.state.walletTransaction?.txId, 'receiver-payjoin-txid');
      expect(
        cubit.state.transaction?.displayPayjoinStatus,
        PayjoinStatus.completed,
      );
      expect(cubit.state.payjoin, completed);
      expect(await cubit.canBroadcastPayjoinOriginalTx(), isFalse);
    });

    test('stays on payjoin-session data while nothing is broadcast, without '
        'firing a targeted sync for a still-ongoing session', () async {
      final payjoin = _sender(status: PayjoinStatus.requested);
      when(
        () => getPayjoinById.execute(payjoin.uri),
      ).thenAnswer((_) async => payjoin);
      // Nothing visible in any wallet for either txid.
      when(
        () => getTransactionsByTxId.execute(any()),
      ).thenAnswer((_) async => [Transaction(payjoin: payjoin)]);

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.initByPayjoinId(payjoin.uri);

      expect(cubit.state.transaction?.walletTransaction, isNull);
      expect(cubit.state.payjoin, payjoin);
      verifyNever(() => getWallet.execute(any(), sync: true));
    });

    test('waits for a forced sync\'d lookup and lands DIRECTLY on the wallet '
        'transaction when the broadcast was not visible locally yet — no '
        'payjoin-session placeholder that swaps out moments later '
        '(observed live on the receiver side of an aborted payjoin)', () async {
      final payjoin = _sender(status: PayjoinStatus.aborted);
      when(
        () => getPayjoinById.execute(payjoin.uri),
      ).thenAnswer((_) async => payjoin);

      // Invisible locally until the forced sync'd lookup pulls it in.
      var visible = false;
      when(() => getTransactionsByTxId.execute('sender-orig-txid')).thenAnswer(
        (_) async => [
          if (visible)
            Transaction(
              walletTransaction: _walletTx(txId: 'sender-orig-txid'),
              payjoin: payjoin,
            )
          else
            Transaction(payjoin: payjoin),
        ],
      );
      when(
        () => getWalletTransaction.execute(
          txId: 'sender-orig-txid',
          walletId: 'w1',
          sync: true,
        ),
      ).thenAnswer((_) async {
        visible = true;
        return Ok<WalletTransaction?, WalletTransactionLookupFailure>(
          _walletTx(txId: 'sender-orig-txid'),
        );
      });

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.initByPayjoinId(payjoin.uri);

      expect(
        cubit.state.transaction?.walletTransaction?.txId,
        'sender-orig-txid',
      );
      expect(
        cubit.state.transaction?.displayPayjoinStatus,
        PayjoinStatus.aborted,
      );
    });

    test(
      'does not force a sync\'d lookup for a still-ongoing session',
      () async {
        final payjoin = _sender(status: PayjoinStatus.requested);
        when(
          () => getPayjoinById.execute(payjoin.uri),
        ).thenAnswer((_) async => payjoin);
        when(
          () => getTransactionsByTxId.execute(any()),
        ).thenAnswer((_) async => [Transaction(payjoin: payjoin)]);

        final cubit = buildCubit();
        addTearDown(cubit.close);
        await cubit.initByPayjoinId(payjoin.uri);

        verifyNever(
          () => getWalletTransaction.execute(
            txId: any(named: 'txId'),
            walletId: any(named: 'walletId'),
            sync: any(named: 'sync'),
          ),
        );
      },
    );

    test('fires a targeted wallet sync when the session is resolved but its '
        'broadcast transaction is not visible locally yet', () async {
      final payjoin = _sender(status: PayjoinStatus.aborted);
      when(
        () => getPayjoinById.execute(payjoin.uri),
      ).thenAnswer((_) async => payjoin);
      when(
        () => getTransactionsByTxId.execute(any()),
      ).thenAnswer((_) async => [Transaction(payjoin: payjoin)]);

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.initByPayjoinId(payjoin.uri);
      await pumpEventQueue();

      expect(cubit.state.transaction?.walletTransaction, isNull);
      verify(() => getWallet.execute('w1', sync: true)).called(1);
    });
  });

  group('TransactionDetailsCubit payjoin reactivity on the by-tx-id path', () {
    test(
      'a payjoin event reloads the details immediately — the manual-broadcast '
      'guard flips the moment the repository resolves the session, without '
      'waiting for a wallet sync (observed live: a stale "Send without '
      'payjoin" button lingering after the fallback had already broadcast)',
      () async {
        final ongoing = _sender(status: PayjoinStatus.requested);
        final completedViaFallback = _sender(status: PayjoinStatus.aborted);
        final payjoinEvents = StreamController<PayjoinSession>.broadcast();
        addTearDown(payjoinEvents.close);

        var loadCount = 0;
        when(() => getTransactionsByTxId.execute(any())).thenAnswer(
          (_) async => [
            Transaction(
              payjoin: loadCount++ == 0 ? ongoing : completedViaFallback,
            ),
          ],
        );
        when(
          () => watchPayjoin.execute(ids: [ongoing.id]),
        ).thenAnswer((_) => payjoinEvents.stream);

        final cubit = buildCubit();
        addTearDown(cubit.close);
        await cubit.initByWalletTxId('sender-orig-txid', walletId: 'w1');

        expect(cubit.state.payjoin?.canManuallyBroadcastOriginal, isTrue);
        when(
          () => broadcastOriginalTransaction.canExecute(completedViaFallback),
        ).thenAnswer((_) async => false);

        payjoinEvents.add(completedViaFallback);
        await pumpEventQueue();

        // The aborted event hides the action immediately, without waiting for
        // the fallback transaction to appear in the wallet transaction list.
        expect(cubit.state.payjoin?.isAborted, isTrue);
        expect(cubit.state.payjoin?.isOngoing, isFalse);
        expect(await cubit.canBroadcastPayjoinOriginalTx(), isFalse);
      },
    );

    test('a TERMINAL payjoin event with no wallet transaction on screen yet '
        'fires a targeted sync of the wallet, so the broadcast transaction '
        'shows up promptly instead of at the next scheduled sync', () async {
      final ongoing = _sender(status: PayjoinStatus.requested);
      final completedViaFallback = _sender(status: PayjoinStatus.aborted);
      final payjoinEvents = StreamController<PayjoinSession>.broadcast();
      addTearDown(payjoinEvents.close);

      var loadCount = 0;
      when(() => getTransactionsByTxId.execute(any())).thenAnswer(
        (_) async => [
          Transaction(
            payjoin: loadCount++ == 0 ? ongoing : completedViaFallback,
          ),
        ],
      );
      when(
        () => watchPayjoin.execute(ids: [ongoing.id]),
      ).thenAnswer((_) => payjoinEvents.stream);

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.initByWalletTxId('sender-orig-txid', walletId: 'w1');

      payjoinEvents.add(completedViaFallback);
      await pumpEventQueue();

      verify(() => getWallet.execute('w1', sync: true)).called(1);
    });

    test(
      'a NON-terminal payjoin event does not fire the targeted sync',
      () async {
        final ongoing = _sender(status: PayjoinStatus.requested);
        final proposed = _sender(
          status: PayjoinStatus.proposed,
          proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
        );
        final payjoinEvents = StreamController<PayjoinSession>.broadcast();
        addTearDown(payjoinEvents.close);

        var loadCount = 0;
        when(() => getTransactionsByTxId.execute(any())).thenAnswer(
          (_) async => [
            Transaction(payjoin: loadCount++ == 0 ? ongoing : proposed),
          ],
        );
        when(
          () => watchPayjoin.execute(ids: [ongoing.id]),
        ).thenAnswer((_) => payjoinEvents.stream);

        final cubit = buildCubit();
        addTearDown(cubit.close);
        await cubit.initByWalletTxId('sender-orig-txid', walletId: 'w1');

        payjoinEvents.add(proposed);
        await pumpEventQueue();

        expect(cubit.state.payjoin?.status, PayjoinStatus.proposed);
        verifyNever(() => getWallet.execute(any(), sync: true));
      },
    );
  });

  group('TransactionDetailsCubit.initByOrderId transaction resolution', () {
    // _loadDetailsByOrderId looks the txid up, then hands it to
    // initByWalletTxId, which looks it up again — so the usecase is called
    // more than once per init. What matters is which txid was asked for, not
    // how often, hence capture over a call count.
    void expectResolvedTxIds(String txId) {
      final resolved = verify(
        () => getTransactionsByTxId.execute(captureAny()),
      ).captured;
      expect(resolved, isNotEmpty);
      expect(resolved, everyElement(txId));
    }

    test('resolves the payjoin txid when the order has no txid yet', () async {
      // The exchange can know the payjoin it broadcast before it reports its
      // own payout txid. Without the fallback the screen stays on order-only
      // details, with no payjoin shown and no watcher armed.
      final order = _buyOrder(payjoinTxId: 'payjoin-txid');
      when(
        () => getOrder.execute(orderId: 'order-1'),
      ).thenAnswer((_) async => order);
      when(() => getTransactionsByTxId.execute(any())).thenAnswer(
        (_) async => [Transaction(payjoin: _receiver(), order: order)],
      );

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.initByOrderId('order-1');

      expectResolvedTxIds('payjoin-txid');
    });

    test('prefers the order txid when both are known', () async {
      final order = _buyOrder(
        bitcoinTransactionId: 'payout-txid',
        payjoinTxId: 'payjoin-txid',
      );
      when(
        () => getOrder.execute(orderId: 'order-1'),
      ).thenAnswer((_) async => order);
      when(() => getTransactionsByTxId.execute(any())).thenAnswer(
        (_) async => [Transaction(payjoin: _receiver(), order: order)],
      );

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.initByOrderId('order-1');

      expectResolvedTxIds('payout-txid');
    });

    test('falls back to order-only details when no txid is known', () async {
      final order = _buyOrder();
      when(
        () => getOrder.execute(orderId: 'order-1'),
      ).thenAnswer((_) async => order);

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.initByOrderId('order-1');

      verifyNever(() => getTransactionsByTxId.execute(any()));
      expect(cubit.state.transaction?.order, order);
    });
  });
}

Order _buyOrder({String? bitcoinTransactionId, String? payjoinTxId}) =>
    Order.buy(
      orderId: 'order-1',
      orderType: OrderType.buy,
      message: OrderMessage(code: '', message: ''),
      orderNumber: 1,
      payinAmount: 100,
      payinCurrency: 'CAD',
      payoutAmount: 0.001,
      payoutCurrency: 'BTC',
      payinMethod: OrderPaymentMethod.eTransfer,
      payoutMethod: OrderPaymentMethod.bitcoin,
      orderStatus: OrderStatus.inProgress,
      payinStatus: OrderPayinStatus.completed,
      payoutStatus: OrderPayoutStatus.completed,
      createdAt: DateTime.utc(2026, 8, 19),
      bitcoinTransactionId: bitcoinTransactionId,
      payjoinDetails: payjoinTxId == null
          ? null
          : OrderPayjoinDetails(txid: payjoinTxId),
      isTestnet: false,
    );

OrderSwapRecord _receiveOrderSwap() {
  final createdAt = DateTime.utc(2026, 8, 10);
  return OrderSwapRecord(
    localId: 'receive-local',
    purpose: OrderSwapPurpose.receiveLightning,
    environment: OrderSwapEnvironment.mainnet,
    inNetwork: OrderSwapNetwork.lightning,
    outNetwork: OrderSwapNetwork.liquid,
    isInAmountFixed: true,
    requestedAmountSat: BigInt.from(20000),
    destinationWalletId: 'liquid-wallet',
    destination: 'liquid-address',
    fallback: 'atomic-refund',
    order: OrderSwap(
      orderId: 'receive-order',
      orderNumber: 1,
      inNetwork: OrderSwapNetwork.lightning,
      outNetwork: OrderSwapNetwork.liquid,
      payinAmountSat: BigInt.from(20000),
      payoutAmountSat: BigInt.from(19800),
      payinCurrency: 'BTCLN',
      payoutCurrency: 'LBTC',
      payinMethod: 'Lightning',
      payoutMethod: 'Liquid',
      orderType: 'Swap',
      orderStatus: 'Completed',
      payinStatus: 'Completed',
      payoutStatus: 'Completed',
      messageCode: 'COMPLETED',
      liquidTransactionId: 'liquid-payout-txid',
      createdAt: createdAt,
      confirmationDeadline: createdAt.add(const Duration(minutes: 5)),
    ),
    createdAt: createdAt,
    localStatus: OrderSwapLocalStatus.completed,
  );
}

OrderSwapRecord _copyOrderSwap(
  OrderSwapRecord record, {
  required OrderSwapLocalStatus localStatus,
  OrderSwap? order,
}) => OrderSwapRecord(
  localId: record.localId,
  requestId: record.requestId,
  purpose: record.purpose,
  environment: record.environment,
  inNetwork: record.inNetwork,
  outNetwork: record.outNetwork,
  isInAmountFixed: record.isInAmountFixed,
  requestedAmountSat: record.requestedAmountSat,
  sourceWalletId: record.sourceWalletId,
  destinationWalletId: record.destinationWalletId,
  destination: record.destination,
  fallback: record.fallback,
  note: record.note,
  localPayinTransactionId: record.localPayinTransactionId,
  order: order ?? record.order,
  createdAt: record.createdAt,
  localStatus: localStatus,
);

OrderSwap _copyOrderSwapOrder(
  OrderSwap order, {
  required String liquidTransactionId,
}) => OrderSwap(
  orderId: order.orderId,
  orderNumber: order.orderNumber,
  inNetwork: order.inNetwork,
  outNetwork: order.outNetwork,
  payinAmountSat: order.payinAmountSat,
  payoutAmountSat: order.payoutAmountSat,
  payinCurrency: order.payinCurrency,
  payoutCurrency: order.payoutCurrency,
  payinMethod: order.payinMethod,
  payoutMethod: order.payoutMethod,
  orderType: order.orderType,
  orderStatus: order.orderStatus,
  payinStatus: order.payinStatus,
  payoutStatus: order.payoutStatus,
  messageCode: order.messageCode,
  bitcoinAddress: order.bitcoinAddress,
  liquidAddress: order.liquidAddress,
  lightningInvoice: order.lightningInvoice,
  bitcoinTransactionId: order.bitcoinTransactionId,
  liquidTransactionId: liquidTransactionId,
  createdAt: order.createdAt,
  confirmationDeadline: order.confirmationDeadline,
  completedAt: order.completedAt,
  sentAt: order.sentAt,
);
