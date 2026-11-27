import 'package:swaps/order_swaps.dart';
import 'package:primitives/primitives.dart';
import 'package:exchange/testing.dart';

import 'dart:collection';
import 'dart:typed_data';

import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:swaps/swaps.dart' hide Environment;
import 'package:swaps/swaps.dart' as swaps show Environment;
import 'package:transactions/testing.dart';
import 'package:primitives/primitives.dart' as bb;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bull_payjoin/bull_payjoin.dart';

class _MockSettingsRepository extends Mock implements Preferences {}

class _MockWalletTransactionRepository extends Mock
    implements WalletTransactionRepository {}

class _MockSwapStore extends Mock implements SwapStore {}

class _MockPayjoinSessions extends Mock implements PayjoinSessions {}

class _MockExchangeOrders extends Mock implements ExchangeOrders {}

class _MockLabelExchangeOrdersUsecase extends Mock
    implements LabelExchangeOrdersUsecase {}

class _MockGetTransactionOrderSwapsUsecase extends Mock
    implements GetTransactionOrderSwapsUsecase {}

class _CountingList<T> extends ListBase<T> {
  final List<T> _items;
  int accesses = 0;

  _CountingList(Iterable<T> items) : _items = [...items];

  @override
  T operator [](int index) {
    accesses++;
    return _items[index];
  }

  @override
  void operator []=(int index, T value) {
    accesses++;
    _items[index] = value;
  }

  @override
  int get length => _items.length;

  @override
  set length(int value) {
    accesses++;
    _items.length = value;
  }
}

/// Unwraps a successful Result; a failure here is a test-setup mistake.
List<Transaction> unwrap(bb.Result<TransactionHistory, TransactionFailure> r) =>
    historyOf(r).transactions;

TransactionHistory historyOf(
  bb.Result<TransactionHistory, TransactionFailure> r,
) => switch (r) {
  bb.Ok(:final value) => value,
  bb.Err(:final failure) => fail('expected transactions, got $failure'),
};

void main() {
  late _MockSettingsRepository settingsRepository;
  late _MockWalletTransactionRepository walletTransactionRepository;
  late _MockSwapStore swapStore;
  late _MockPayjoinSessions payjoinSessions;
  late _MockExchangeOrders mainnetOrderRepository;
  late _MockExchangeOrders testnetOrderRepository;
  late _MockLabelExchangeOrdersUsecase labelExchangeOrdersUsecase;
  late List<Order> orders;
  late _MockGetTransactionOrderSwapsUsecase getOrderSwaps;
  late GetTransactionsUsecase usecase;

  PayjoinReceiverSession receiver(PayjoinStatus status) =>
      PayjoinReceiverSession(
        status: status,
        id: 'pj1',
        network: BitcoinNetwork.mainnet,
        walletId: 'w1',
        payjoinUri: 'bitcoin:bc1qtest?pj=https://payjo.in',
        createdAt: DateTime(2026),
        expiresAt: DateTime(2026).add(const Duration(minutes: 1)),
        originalTransactionId: 'original-txid',
      );

  setUpAll(() {
    registerFallbackValue(PayjoinSessionFilter());
  });

  setUp(() {
    settingsRepository = _MockSettingsRepository();
    walletTransactionRepository = _MockWalletTransactionRepository();
    swapStore = _MockSwapStore();
    payjoinSessions = _MockPayjoinSessions();
    mainnetOrderRepository = _MockExchangeOrders();
    testnetOrderRepository = _MockExchangeOrders();
    labelExchangeOrdersUsecase = _MockLabelExchangeOrdersUsecase();
    orders = [];
    getOrderSwaps = _MockGetTransactionOrderSwapsUsecase();

    when(() => settingsRepository.fetch()).thenAnswer(
      (_) async => Ok(
        const SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
        ),
      ),
    );
    when(
      () => walletTransactionRepository.getWalletTransactions(
        walletId: any(named: 'walletId'),
        sync: any(named: 'sync'),
        environment: any(named: 'environment'),
      ),
    ).thenAnswer((_) async => Ok([]));
    when(() => swapStore.all(walletId: any(named: 'walletId')))
        .thenAnswer((_) async => const bb.Ok([]));
    when(() => mainnetOrderRepository.getOrders())
        .thenAnswer((_) async => Ok(orders));
    when(() => labelExchangeOrdersUsecase.execute(orders: orders))
        .thenAnswer((_) async {});
    when(() => getOrderSwaps.execute(walletId: any(named: 'walletId')))
        .thenAnswer(
          (_) async => bb.Ok<List<OrderSwapRecord>, TransactionFailure>([]),
        );

    usecase = GetTransactionsUsecase(
      settingsRepository: settingsRepository,
      walletTransactionRepository: walletTransactionRepository,
      swapStore: swapStore,
      payjoinSessions: payjoinSessions,
      exchange: exchangeForTesting(
        orders: (environment) => environment == ExchangeEnvironment.testnet
            ? testnetOrderRepository
            : mainnetOrderRepository,
      ),
      labelExchangeOrdersUsecase: labelExchangeOrdersUsecase,
      getTransactionOrderSwapsUsecase: getOrderSwaps,
    );
  });

  test('regtest history reads only its concrete wallet transactions', () async {
    when(settingsRepository.fetch).thenAnswer(
      (_) async => Ok(
        const SettingsEntity(
          environment: Environment.regtest,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
        ),
      ),
    );
    final walletTx = _walletTransaction(
      txId: 'regtest-tx',
      walletId: 'regtest-wallet',
      isIncoming: true,
    ).copyWith(network: BitcoinNetwork.regtest);
    when(
      () => walletTransactionRepository.getWalletTransactions(
        walletId: 'regtest-wallet',
        sync: false,
        environment: Environment.regtest,
      ),
    ).thenAnswer((_) async => Ok([walletTx]));
    final history = historyOf(
      await usecase.execute(walletId: 'regtest-wallet'),
    );
    final rows = history.transactions;
    expect(history.exchangeOrders, isA<ExchangeOrdersNotOffered>());
    expect(rows.single.walletTransaction, walletTx);
    expect(rows.single.supportsPublicExplorer, false);
    verifyZeroInteractions(mainnetOrderRepository);
    verifyZeroInteractions(testnetOrderRepository);
    verifyZeroInteractions(payjoinSessions);
    verifyZeroInteractions(swapStore);
    verifyZeroInteractions(getOrderSwaps);
  });

  test(
    'credential failure removes exchange enrichment, not wallet history',
    () async {
      final tx = _walletTransaction(
        txId: 'wallet-tx',
        walletId: 'w1',
        isIncoming: true,
      );
      when(() => mainnetOrderRepository.getOrders())
          .thenAnswer((_) async => const Err(ExchangeCredentialReadFailure()));
      when(
        () => walletTransactionRepository.getWalletTransactions(
          walletId: any(named: 'walletId'),
          sync: any(named: 'sync'),
          environment: any(named: 'environment'),
        ),
      ).thenAnswer((_) async => Ok([tx]));
      when(() => payjoinSessions.list(any()))
          .thenAnswer((_) async => const Ok([]));
      when(
        () => labelExchangeOrdersUsecase.execute(orders: any(named: 'orders')),
      ).thenAnswer((_) async {});
      final history = historyOf(await usecase.execute());
      expect(history.transactions, hasLength(1));
      expect(history.transactions.single.walletTransaction?.txId, 'wallet-tx');
      expect(
        history.exchangeOrders,
        isA<ExchangeOrdersUnavailable>().having(
          (read) => read.failure,
          'failure',
          isA<ExchangeCredentialReadFailure>(),
        ),
        reason: 'a failed order read is shown, never an empty order list',
      );
      verifyNever(
        () => labelExchangeOrdersUsecase.execute(orders: any(named: 'orders')),
      );
    },
  );

  test('no stored exchange account is no account, not a failure', () async {
    when(() => mainnetOrderRepository.getOrders())
        .thenAnswer((_) async => const Err(ExchangeNotAuthenticatedFailure()));
    when(() => payjoinSessions.list(any()))
        .thenAnswer((_) async => const Ok([]));

    final history = historyOf(await usecase.execute());

    expect(history.exchangeOrders, isA<ExchangeOrdersNoAccount>());
  });

  test('a read order list is merged', () async {
    when(() => payjoinSessions.list(any()))
        .thenAnswer((_) async => const Ok([]));
    final history = historyOf(await usecase.execute());

    expect(history.exchangeOrders, isA<ExchangeOrdersMerged>());
  });

  test(
    'hides an aborted Payjoin until its original wallet tx is synced',
    () async {
      when(() => payjoinSessions.list(any()))
          .thenAnswer((_) async => Ok([receiver(PayjoinStatus.aborted)]));

      final transactions = unwrap(await usecase.execute());

      expect(transactions, isEmpty);
    },
  );

  test('keeps a genuinely pending Payjoin in the transaction list', () async {
    when(() => payjoinSessions.list(any()))
        .thenAnswer((_) async => Ok([receiver(PayjoinStatus.requested)]));

    final transactions = unwrap(await usecase.execute());

    expect(transactions, hasLength(1));
    expect(transactions.single.payjoin?.status, PayjoinStatus.requested);
  });

  test(
    'keeps ordinary transaction history available when Payjoin is unavailable',
    () async {
      when(() => payjoinSessions.list(any())).thenAnswer(
        (_) async => const Err(
          PayjoinUnavailableFailure('Payjoin failed to initialize'),
        ),
      );

      final transactions = unwrap(await usecase.execute());

      expect(
        transactions,
        isEmpty,
        reason: 'Payjoin is optional enrichment for ordinary transactions',
      );
    },
  );

  test('joins a receive swap to its payout transaction', () async {
    final payout = _walletTransaction(
      txId: 'payout-tx',
      walletId: 'destination-wallet',
      isIncoming: true,
    );
    when(
      () => walletTransactionRepository.getWalletTransactions(
        walletId: any(named: 'walletId'),
        sync: any(named: 'sync'),
        environment: any(named: 'environment'),
      ),
    ).thenAnswer((_) async => Ok([payout]));
    when(() => payjoinSessions.list(any()))
        .thenAnswer((_) async => const Ok([]));
    when(() => getOrderSwaps.execute(walletId: any(named: 'walletId')))
        .thenAnswer(
          (_) async => bb.Ok<List<OrderSwapRecord>, TransactionFailure>([
            _receiveOrderSwap(),
          ]),
        );

    final transactions = unwrap(await usecase.execute());

    expect(transactions, hasLength(1));
    expect(transactions.single.walletTransaction?.txId, 'payout-tx');
    expect(transactions.single.orderSwap?.localId, 'receive-order');
  });

  test('binds a buy the exchange still knows only by its payjoin txid', () async {
    // The exchange broadcasts the payjoin before it reports that transaction as
    // the order's payout, so the order carries no payout txid yet while the
    // wallet already sees the transaction. Both describe the same event and the
    // amounts agree; the list must show one row, not "Bitcoin" plus "Buy
    // Bitcoin".
    final payout = _walletTransaction(
      txId: 'payjoin-txid',
      walletId: 'w1',
      isIncoming: true,
      amountSat: 175906,
      address: 'bc1qmine',
    );
    when(
      () => walletTransactionRepository.getWalletTransactions(
        walletId: any(named: 'walletId'),
        sync: any(named: 'sync'),
        environment: any(named: 'environment'),
      ),
    ).thenAnswer((_) async => Ok([payout]));
    when(() => payjoinSessions.list(any()))
        .thenAnswer((_) async => const Ok([]));
    orders.add(
      _buyOrder(
        txId: null,
        address: 'bc1qmine',
        payoutAmountBtc: 0.00175906,
        payjoinTxid: 'payjoin-txid',
        orderStatus: OrderStatus.inProgress,
      ),
    );

    final transactions = unwrap(await usecase.execute());

    expect(
      transactions,
      hasLength(1),
      reason: 'the order must not be listed again beside its own payjoin',
    );
    expect(transactions.single.order?.orderId, 'buy-order');
    expect(transactions.single.walletTransaction?.txId, 'payjoin-txid');
  });

  test('keeps one canonical row for an internal chain swap', () async {
    final payin = _walletTransaction(
      txId: 'payin-tx',
      walletId: 'source-wallet',
      isIncoming: false,
    );
    final payout = _walletTransaction(
      txId: 'payout-tx',
      walletId: 'destination-wallet',
      isIncoming: true,
    );
    when(
      () => walletTransactionRepository.getWalletTransactions(
        walletId: any(named: 'walletId'),
        sync: any(named: 'sync'),
        environment: any(named: 'environment'),
      ),
    ).thenAnswer((_) async => Ok([payin, payout]));
    when(() => payjoinSessions.list(any()))
        .thenAnswer((_) async => const Ok([]));
    when(
      () => getOrderSwaps.execute(walletId: any(named: 'walletId')),
    ).thenAnswer(
      (_) async =>
          bb.Ok<List<OrderSwapRecord>, TransactionFailure>([_chainOrderSwap()]),
    );

    final transactions = unwrap(await usecase.execute());

    expect(transactions, hasLength(1));
    expect(transactions.single.walletTransaction?.txId, 'payin-tx');
    expect(transactions.single.orderSwap?.localId, 'chain-order');
  });

  group('Boltz swaps', () {
    void history({
      required List<WalletTransaction> walletTransactions,
      required List<Swap> swaps,
    }) {
      when(
        () => walletTransactionRepository.getWalletTransactions(
          walletId: any(named: 'walletId'),
          sync: any(named: 'sync'),
          environment: any(named: 'environment'),
        ),
      ).thenAnswer((_) async => Ok(walletTransactions));
      when(() => swapStore.all(walletId: any(named: 'walletId')))
          .thenAnswer((_) async => bb.Ok(swaps));
      when(() => payjoinSessions.list(any()))
          .thenAnswer((_) async => const Ok([]));
    }

    final lockup = _walletTransaction(
      txId: 'lockup-tx',
      walletId: 'bitcoin-wallet',
      isIncoming: false,
      amountSat: 50000,
      address: 'bc1qlockup',
    );
    final claim = _walletTransaction(
      txId: 'claim-tx',
      walletId: 'liquid-wallet',
      isIncoming: true,
      amountSat: 49500,
      network: LiquidNetwork.mainnet,
    );

    test('lists a chain swap between two wallets once', () async {
      history(walletTransactions: [lockup, claim], swaps: [_chainSwap()]);

      final transactions = unwrap(await usecase.execute());

      expect(transactions, hasLength(1));
      expect(transactions.single.swap?.id, 'chain-swap');
      expect(transactions.single.walletTransaction?.txId, 'lockup-tx');
    });

    test('shows the receiving wallet its claim as the swap', () async {
      history(walletTransactions: [claim], swaps: [_chainSwap()]);

      final transactions = unwrap(
        await usecase.execute(walletId: 'liquid-wallet'),
      );

      expect(transactions, hasLength(1));
      expect(transactions.single.swap?.id, 'chain-swap');
      expect(transactions.single.walletTransaction?.txId, 'claim-tx');
    });

    test('shows the sending wallet its lockup as the swap', () async {
      history(walletTransactions: [lockup], swaps: [_chainSwap()]);

      final transactions = unwrap(
        await usecase.execute(walletId: 'bitcoin-wallet'),
      );

      expect(transactions, hasLength(1));
      expect(transactions.single.swap?.id, 'chain-swap');
      expect(transactions.single.walletTransaction?.txId, 'lockup-tx');
    });

    test('lists a refunded chain swap once, on its lockup', () async {
      final refund = _walletTransaction(
        txId: 'refund-tx',
        walletId: 'bitcoin-wallet',
        isIncoming: true,
        amountSat: 49800,
        address: 'bc1qrefund',
      );
      history(
        walletTransactions: [refund, lockup],
        swaps: [
          _chainSwap(
            status: SwapStatus.refunded,
            receiveTxid: null,
            refundTxid: 'refund-tx',
          ),
        ],
      );

      final transactions = unwrap(await usecase.execute());

      expect(transactions, hasLength(1));
      expect(transactions.single.swap?.id, 'chain-swap');
      expect(transactions.single.walletTransaction?.txId, 'lockup-tx');
    });

    test('keeps a claim txid away from a wallet outside the swap', () async {
      final unrelated = _walletTransaction(
        txId: 'claim-tx',
        walletId: 'other-wallet',
        isIncoming: true,
        amountSat: 49500,
        network: LiquidNetwork.mainnet,
      );
      history(walletTransactions: [unrelated], swaps: [_chainSwap()]);

      final transactions = unwrap(await usecase.execute());

      expect(
        transactions.singleWhere((tx) => tx.walletTransaction != null).swap,
        isNull,
      );
    });

    test('keeps a claim txid away from the sending wallet', () async {
      final misplaced = _walletTransaction(
        txId: 'claim-tx',
        walletId: 'bitcoin-wallet',
        isIncoming: true,
        amountSat: 49500,
        address: 'bc1qclaim',
      );
      history(walletTransactions: [misplaced], swaps: [_chainSwap()]);

      final transactions = unwrap(await usecase.execute());

      expect(
        transactions.singleWhere((tx) => tx.walletTransaction != null).swap,
        isNull,
      );
    });

    test('keeps a swap away from a transaction larger than it', () async {
      final larger = _walletTransaction(
        txId: 'lockup-tx',
        walletId: 'bitcoin-wallet',
        isIncoming: false,
        amountSat: 50001,
        address: 'bc1qlockup',
      );
      history(walletTransactions: [larger], swaps: [_chainSwap()]);

      final transactions = unwrap(await usecase.execute());

      expect(
        transactions.singleWhere((tx) => tx.walletTransaction != null).swap,
        isNull,
      );
    });

    test('lists a Lightning send once, on its lockup', () async {
      final swap = _lnSendSwap();
      expect(swap.amountSat, 1000);
      final lnLockup = _walletTransaction(
        txId: 'ln-lockup-tx',
        walletId: 'liquid-wallet',
        isIncoming: false,
        amountSat: 1025,
        network: LiquidNetwork.mainnet,
      );
      history(walletTransactions: [lnLockup], swaps: [swap]);

      final transactions = unwrap(await usecase.execute());

      expect(transactions, hasLength(1));
      expect(transactions.single.swap?.id, 'ln-send-swap');
      expect(transactions.single.walletTransaction?.txId, 'ln-lockup-tx');
    });

    test('lists a refunded Lightning send once, on its lockup', () async {
      final lnLockup = _walletTransaction(
        txId: 'ln-lockup-tx',
        walletId: 'liquid-wallet',
        isIncoming: false,
        amountSat: 1025,
        network: LiquidNetwork.mainnet,
      );
      final lnRefund = _walletTransaction(
        txId: 'ln-refund-tx',
        walletId: 'liquid-wallet',
        isIncoming: true,
        amountSat: 1010,
        network: LiquidNetwork.mainnet,
      );
      history(
        walletTransactions: [lnRefund, lnLockup],
        swaps: [
          _lnSendSwap(status: SwapStatus.refunded, refundTxid: 'ln-refund-tx'),
        ],
      );

      final transactions = unwrap(await usecase.execute());

      expect(transactions, hasLength(1));
      expect(transactions.single.swap?.id, 'ln-send-swap');
      expect(transactions.single.walletTransaction?.txId, 'ln-lockup-tx');
    });

    test('lists a Lightning receive once, on its claim', () async {
      final swap = _lnReceiveSwap();
      expect(swap.amountSat, 1000);
      final lnClaim = _walletTransaction(
        txId: 'ln-claim-tx',
        walletId: 'liquid-wallet',
        isIncoming: true,
        amountSat: 975,
        network: LiquidNetwork.mainnet,
      );
      history(walletTransactions: [lnClaim], swaps: [swap]);

      final transactions = unwrap(await usecase.execute());

      expect(transactions, hasLength(1));
      expect(transactions.single.swap?.id, 'ln-receive-swap');
      expect(transactions.single.walletTransaction?.txId, 'ln-claim-tx');
    });
  });

  test(
    'matches unique order txids with linearly bounded source accesses',
    () async {
      const count = 1000;
      final walletTransactions = [
        for (var i = 0; i < count; i++)
          _walletTransaction(
            txId: 'tx-$i',
            walletId: 'wallet-$i',
            isIncoming: false,
          ),
      ];
      final countedOrders = _CountingList<Order>([
        for (var i = 0; i < count; i++) _sellOrder('tx-$i'),
      ]);
      orders = countedOrders;
      when(
        () => labelExchangeOrdersUsecase.execute(orders: any(named: 'orders')),
      ).thenAnswer((_) async {});
      when(
        () => walletTransactionRepository.getWalletTransactions(
          walletId: any(named: 'walletId'),
          sync: any(named: 'sync'),
          environment: any(named: 'environment'),
        ),
      ).thenAnswer((_) async => Ok(walletTransactions));
      when(() => payjoinSessions.list(any()))
          .thenAnswer((_) async => const Ok([]));

      final transactions = unwrap(await usecase.execute());

      expect(transactions, hasLength(count));
      expect(
        transactions.every((transaction) => transaction.order != null),
        isTrue,
      );
      expect(
        countedOrders.accesses,
        lessThanOrEqualTo(count * 30),
        reason:
            'unique txids should not scan the source order list quadratically',
      );
    },
  );

  test('consumes exchange orders independently from order swaps', () async {
    final walletTransaction = _walletTransaction(
      txId: 'exchange-tx',
      walletId: 'wallet-1',
      isIncoming: false,
    );

    orders = [_sellOrder('exchange-tx')];
    when(() => labelExchangeOrdersUsecase.execute(orders: any(named: 'orders')))
        .thenAnswer((_) async {});
    when(() => payjoinSessions.list(any()))
        .thenAnswer((_) async => const Ok([]));
    when(() => getOrderSwaps.execute(walletId: any(named: 'walletId')))
        .thenAnswer(
          (_) async => bb.Ok<List<OrderSwapRecord>, TransactionFailure>([]),
        );
    when(
      () => walletTransactionRepository.getWalletTransactions(
        walletId: any(named: 'walletId'),
        sync: any(named: 'sync'),
        environment: any(named: 'environment'),
      ),
    ).thenAnswer((_) async => Ok([walletTransaction]));
    when(() => payjoinSessions.list(any()))
        .thenAnswer((_) async => const Ok([]));
    when(() => getOrderSwaps.execute(walletId: any(named: 'walletId')))
        .thenAnswer(
          (_) async => bb.Ok<List<OrderSwapRecord>, TransactionFailure>([
            _receiveOrderSwap(),
          ]),
        );

    final transactions = unwrap(await usecase.execute());

    expect(transactions, hasLength(2));
    expect(transactions.singleWhere((tx) => tx.order != null).order, orders[0]);
    expect(
      transactions.singleWhere((tx) => tx.orderSwap != null).orderSwap?.localId,
      'receive-order',
    );
  });

  test(
    'does not let a non-finite BTC amount abort valid associations',
    () async {
      final malformed = _sellOrder(
        'malformed-tx',
        payinAmount: double.infinity,
      );
      final valid = _sellOrder('valid-tx', payinAmount: 0.000005);
      orders = [malformed, valid];
      when(
        () => labelExchangeOrdersUsecase.execute(orders: any(named: 'orders')),
      ).thenAnswer((_) async {});
      when(() => payjoinSessions.list(any()))
          .thenAnswer((_) async => const Ok([]));
      when(() => getOrderSwaps.execute(walletId: any(named: 'walletId')))
          .thenAnswer(
            (_) async => bb.Ok<List<OrderSwapRecord>, TransactionFailure>([]),
          );
      final validTransaction = _walletTransaction(
        txId: 'valid-tx',
        walletId: 'wallet-1',
        isIncoming: false,
      );
      final malformedTransaction = _walletTransaction(
        txId: 'malformed-tx',
        walletId: 'wallet-1',
        isIncoming: false,
      );
      when(
        () => walletTransactionRepository.getWalletTransactions(
          walletId: any(named: 'walletId'),
          sync: any(named: 'sync'),
          environment: any(named: 'environment'),
        ),
      ).thenAnswer((_) async => Ok([malformedTransaction, validTransaction]));

      final transactions = unwrap(await usecase.execute());

      expect(transactions, hasLength(3));
      expect(transactions.singleWhere((tx) => tx.order == valid).order, valid);
      expect(
        transactions
            .singleWhere((tx) => tx.order == malformed)
            .walletTransaction,
        isNull,
      );
      expect(
        transactions
            .singleWhere((tx) => tx.walletTransaction == malformedTransaction)
            .order,
        isNull,
      );
    },
  );

  test(
    'returns an aggregation failure instead of throwing when a source fails',
    () async {
      // Both callers switch on the result and have no try/catch: a throw here
      // strands the list on "syncing" and the export screen on "loading".
      when(
        () => walletTransactionRepository.getWalletTransactions(
          walletId: any(named: 'walletId'),
          sync: any(named: 'sync'),
          environment: any(named: 'environment'),
        ),
      ).thenThrow(StateError('electrum connection reset by peer'));

      final result = await usecase.execute();

      expect(result, isA<bb.Err<TransactionHistory, TransactionFailure>>());
      final failure = (result as bb.Err).failure as TransactionFailure;
      expect(failure, isA<TransactionAggregationFailure>());
      // The raw reason belongs in the log, not in a value the UI can reach.
      expect(failure.logMessage, isNot(contains('connection reset')));
    },
  );
}

WalletTransaction _walletTransaction({
  required String txId,
  required String walletId,
  required bool isIncoming,
  int amountSat = 1000,
  String? address,
  bb.Network network = BitcoinNetwork.mainnet,
}) {
  return WalletTransaction(
    walletId: walletId,
    network: network,
    direction: isIncoming
        ? WalletTransactionDirection.incoming
        : WalletTransactionDirection.outgoing,
    status: WalletTransactionStatus.confirmed,
    txId: txId,
    amountSat: amountSat,
    feeSat: 1,
    vsize: 100,
    inputs: const [],
    outputs: [
      if (address != null)
        TransactionOutput.bitcoin(
          txId: txId,
          vout: 0,
          isOwn: isIncoming,
          scriptPubkey: Uint8List(0),
          address: address,
        ),
    ],
    isRbf: false,
  );
}

const _invoiceFor1000Sats =
    'lnbc10u1p59tufasp53yuqahahgct058zglxvhezp9nyz5fvt2kn2lsl6mg9qgsts8c72spp56hym2dpcyy0878h7q5h4t30cwclp9vd0tqpn4dns0a3mmspzkh9qdqqxqyp2xqcqz95rzjqg2n4jluz7ty6mn96krzje43zm7ylttjvcxcccg99tmm30s6lm4d6zzxeyqq28qqqqqqqqqqqqqqq9gq2y9qyysgqpmw883kkclyxpr2u8mg9pl47909yhtt83pjvt3qz3s9puyf39vdp4ar7zu47r4mfawkc2s99vm292udx9n3s5fnrjyngnsxkxn2l60qpn65s0t';

Swap _chainSwap({
  SwapStatus status = SwapStatus.completed,
  String? receiveTxid = 'claim-tx',
  String? refundTxid,
}) => Swap.chain(
  id: 'chain-swap',
  keyIndex: 0,
  type: SwapType.bitcoinToLiquid,
  status: status,
  environment: swaps.Environment.mainnet,
  creationTime: DateTime.utc(2026),
  completionTime: DateTime.utc(2026, 1, 1, 1),
  sendWalletId: 'bitcoin-wallet',
  paymentAddress: 'bc1qlockup',
  paymentAmount: 50000,
  sendTxid: 'lockup-tx',
  receiveWalletId: 'liquid-wallet',
  receiveAddress: 'lq1claim',
  receiveTxid: receiveTxid,
  refundAddress: 'bc1qrefund',
  refundTxid: refundTxid,
);

Swap _lnSendSwap({
  SwapStatus status = SwapStatus.completed,
  String? refundTxid,
}) => Swap.lnSend(
  id: 'ln-send-swap',
  keyIndex: 1,
  type: SwapType.liquidToLightning,
  status: status,
  environment: swaps.Environment.mainnet,
  creationTime: DateTime.utc(2026),
  completionTime: DateTime.utc(2026, 1, 1, 1),
  sendWalletId: 'liquid-wallet',
  invoice: _invoiceFor1000Sats,
  paymentAddress: 'lq1lockup',
  paymentAmount: 1025,
  sendTxid: 'ln-lockup-tx',
  refundAddress: 'lq1refund',
  refundTxid: refundTxid,
);

Swap _lnReceiveSwap() => Swap.lnReceive(
  id: 'ln-receive-swap',
  keyIndex: 2,
  type: SwapType.lightningToLiquid,
  status: SwapStatus.completed,
  environment: swaps.Environment.mainnet,
  creationTime: DateTime.utc(2026),
  completionTime: DateTime.utc(2026, 1, 1, 1),
  receiveWalletId: 'liquid-wallet',
  invoice: _invoiceFor1000Sats,
  receiveAddress: 'lq1claim',
  receiveTxid: 'ln-claim-tx',
);

Order _buyOrder({
  required String? txId,
  required String address,
  required double payoutAmountBtc,
  String? payjoinTxid,
  OrderStatus orderStatus = OrderStatus.completed,
}) => Order.buy(
  orderId: 'buy-order',
  orderType: OrderType.buy,
  message: OrderMessage(code: '', message: ''),
  orderNumber: 1,
  payinAmount: 100,
  payinCurrency: 'CAD',
  payoutAmount: payoutAmountBtc,
  payoutCurrency: 'BTC',
  payinMethod: OrderPaymentMethod.cadBalance,
  payoutMethod: OrderPaymentMethod.bitcoin,
  orderStatus: orderStatus,
  payinStatus: OrderPayinStatus.completed,
  payoutStatus: OrderPayoutStatus.completed,
  createdAt: DateTime.utc(2026),
  bitcoinAddress: address,
  bitcoinTransactionId: txId,
  payjoinDetails: payjoinTxid == null
      ? null
      : OrderPayjoinDetails(txid: payjoinTxid),
  isTestnet: false,
);

OrderSwapRecord _receiveOrderSwap() => OrderSwapRecord(
  localId: 'receive-order',
  requestId: 'receive-request',
  purpose: OrderSwapPurpose.receiveLightning,
  environment: OrderSwapEnvironment.mainnet,
  inNetwork: OrderSwapNetwork.lightning,
  outNetwork: OrderSwapNetwork.liquid,
  isInAmountFixed: true,
  requestedAmountSat: BigInt.from(1000),
  destinationWalletId: 'destination-wallet',
  destination: 'liquid-address',
  fallback: 'liquid-address',
  order: _order(
    orderId: 'receive-server-order',
    inNetwork: OrderSwapNetwork.lightning,
    outNetwork: OrderSwapNetwork.liquid,
    payinAmountSat: 1000,
    payoutAmountSat: 990,
    liquidTransactionId: 'payout-tx',
  ),
  createdAt: DateTime.utc(2026),
  localStatus: OrderSwapLocalStatus.completed,
);

Order _sellOrder(String txId, {double payinAmount = 0}) => Order.sell(
  orderId: 'order-$txId',
  orderType: OrderType.sell,
  message: OrderMessage(code: '', message: ''),
  orderNumber: 1,
  payinAmount: payinAmount,
  payinCurrency: 'BTC',
  payoutAmount: 1,
  payoutCurrency: 'CAD',
  payinMethod: OrderPaymentMethod.bitcoin,
  payoutMethod: OrderPaymentMethod.cadBalance,
  orderStatus: OrderStatus.completed,
  payinStatus: OrderPayinStatus.completed,
  payoutStatus: OrderPayoutStatus.completed,
  createdAt: DateTime.utc(2026),
  bitcoinTransactionId: txId,
  isTestnet: false,
);

OrderSwapRecord _chainOrderSwap() => OrderSwapRecord(
  localId: 'chain-order',
  requestId: 'chain-request',
  purpose: OrderSwapPurpose.transfer,
  environment: OrderSwapEnvironment.mainnet,
  inNetwork: OrderSwapNetwork.liquid,
  outNetwork: OrderSwapNetwork.bitcoin,
  isInAmountFixed: true,
  requestedAmountSat: BigInt.from(1000),
  sourceWalletId: 'source-wallet',
  destinationWalletId: 'destination-wallet',
  destination: 'bitcoin-address',
  fallback: 'liquid-address',
  order: _order(
    orderId: 'chain-server-order',
    inNetwork: OrderSwapNetwork.liquid,
    outNetwork: OrderSwapNetwork.bitcoin,
    payinAmountSat: 1000,
    payoutAmountSat: 990,
    liquidTransactionId: 'payin-tx',
    bitcoinTransactionId: 'payout-tx',
  ),
  localPayinTransactionId: 'payin-tx',
  createdAt: DateTime.utc(2026),
  localStatus: OrderSwapLocalStatus.completed,
);

OrderSwap _order({
  required String orderId,
  required OrderSwapNetwork inNetwork,
  required OrderSwapNetwork outNetwork,
  required int payinAmountSat,
  required int payoutAmountSat,
  String? bitcoinTransactionId,
  String? liquidTransactionId,
}) => OrderSwap(
  orderId: orderId,
  orderNumber: 1,
  inNetwork: inNetwork,
  outNetwork: outNetwork,
  payinAmountSat: BigInt.from(payinAmountSat),
  payoutAmountSat: BigInt.from(payoutAmountSat),
  payinCurrency: 'IN',
  payoutCurrency: 'OUT',
  payinMethod: 'in',
  payoutMethod: 'out',
  orderType: 'Swap',
  orderStatus: 'Completed',
  payinStatus: 'Completed',
  payoutStatus: 'Completed',
  messageCode: 'COMPLETED',
  bitcoinTransactionId: bitcoinTransactionId,
  liquidTransactionId: liquidTransactionId,
  createdAt: DateTime.utc(2026),
  confirmationDeadline: DateTime.utc(2026, 1, 1, 0, 5),
);
