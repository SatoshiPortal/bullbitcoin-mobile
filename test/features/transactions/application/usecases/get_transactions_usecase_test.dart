import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_transaction_order_swaps_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_transactions_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/label_exchange_orders_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork, Err, Ok;

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockWalletTransactionRepository extends Mock
    implements WalletTransactionRepository {}

class _MockBoltzSwapRepository extends Mock implements BoltzSwapRepository {}

class _MockPayjoinSessions extends Mock implements PayjoinSessions {}

class _MockExchangeOrderRepository extends Mock
    implements ExchangeOrderRepository {}

class _MockLabelExchangeOrdersUsecase extends Mock
    implements LabelExchangeOrdersUsecase {}

class _MockGetTransactionOrderSwapsUsecase extends Mock
    implements GetTransactionOrderSwapsUsecase {}

void main() {
  late _MockSettingsRepository settingsRepository;
  late _MockWalletTransactionRepository walletTransactionRepository;
  late _MockBoltzSwapRepository boltzSwapRepository;
  late _MockPayjoinSessions payjoinSessions;
  late _MockExchangeOrderRepository mainnetOrderRepository;
  late _MockExchangeOrderRepository testnetOrderRepository;
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
    boltzSwapRepository = _MockBoltzSwapRepository();
    payjoinSessions = _MockPayjoinSessions();
    mainnetOrderRepository = _MockExchangeOrderRepository();
    testnetOrderRepository = _MockExchangeOrderRepository();
    labelExchangeOrdersUsecase = _MockLabelExchangeOrdersUsecase();
    orders = [];
    getOrderSwaps = _MockGetTransactionOrderSwapsUsecase();

    when(() => settingsRepository.fetch()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
      ),
    );
    when(
      () => walletTransactionRepository.getWalletTransactions(
        walletId: any(named: 'walletId'),
        sync: any(named: 'sync'),
        environment: any(named: 'environment'),
      ),
    ).thenAnswer((_) async => []);
    when(
      () => boltzSwapRepository.getAllSwaps(walletId: any(named: 'walletId')),
    ).thenAnswer((_) async => []);
    when(
      () => mainnetOrderRepository.getOrders(),
    ).thenAnswer((_) async => orders);
    when(
      () => labelExchangeOrdersUsecase.execute(orders: orders),
    ).thenAnswer((_) async {});
    when(
      () => getOrderSwaps.execute(walletId: any(named: 'walletId')),
    ).thenAnswer((_) async => []);

    usecase = GetTransactionsUsecase(
      settingsRepository: settingsRepository,
      walletTransactionRepository: walletTransactionRepository,
      boltzSwapRepository: boltzSwapRepository,
      payjoinSessions: payjoinSessions,
      mainnetExchangeOrderRepository: mainnetOrderRepository,
      testnetExchangeOrderRepository: testnetOrderRepository,
      labelExchangeOrdersUsecase: labelExchangeOrdersUsecase,
      getTransactionOrderSwapsUsecase: getOrderSwaps,
    );
  });

  test(
    'hides an aborted Payjoin until its original wallet tx is synced',
    () async {
      when(
        () => payjoinSessions.list(any()),
      ).thenAnswer((_) async => Ok([receiver(PayjoinStatus.aborted)]));

      final transactions = await usecase.execute();

      expect(transactions, isEmpty);
    },
  );

  test('keeps a genuinely pending Payjoin in the transaction list', () async {
    when(
      () => payjoinSessions.list(any()),
    ).thenAnswer((_) async => Ok([receiver(PayjoinStatus.requested)]));

    final transactions = await usecase.execute();

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

      final transactions = await usecase.execute();

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
    ).thenAnswer((_) async => [payout]);
    when(
      () => payjoinSessions.list(any()),
    ).thenAnswer((_) async => const Ok([]));
    when(
      () => getOrderSwaps.execute(walletId: any(named: 'walletId')),
    ).thenAnswer((_) async => [_receiveOrderSwap()]);

    final transactions = await usecase.execute();

    expect(transactions, hasLength(1));
    expect(transactions.single.walletTransaction?.txId, 'payout-tx');
    expect(transactions.single.orderSwap?.localId, 'receive-order');
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
    ).thenAnswer((_) async => [payin, payout]);
    when(
      () => payjoinSessions.list(any()),
    ).thenAnswer((_) async => const Ok([]));
    when(
      () => getOrderSwaps.execute(walletId: any(named: 'walletId')),
    ).thenAnswer((_) async => [_chainOrderSwap()]);

    final transactions = await usecase.execute();

    expect(transactions, hasLength(1));
    expect(transactions.single.walletTransaction?.txId, 'payin-tx');
    expect(transactions.single.orderSwap?.localId, 'chain-order');
  });
}

WalletTransaction _walletTransaction({
  required String txId,
  required String walletId,
  required bool isIncoming,
}) {
  return WalletTransaction(
    walletId: walletId,
    network: Network.bitcoinMainnet,
    direction: isIncoming
        ? WalletTransactionDirection.incoming
        : WalletTransactionDirection.outgoing,
    status: WalletTransactionStatus.confirmed,
    txId: txId,
    amountSat: 1000,
    feeSat: 1,
    vsize: 100,
    inputs: const [],
    outputs: const [],
    isRbf: false,
  );
}

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
