import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/swap_history_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_transaction_order_swaps_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_transactions_by_tx_id_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockWalletTransactionRepository extends Mock
    implements WalletTransactionRepository {}

class _MockSwapHistoryRepository extends Mock
    implements SwapHistoryRepository {}

class _MockPayjoinSessions extends Mock implements PayjoinSessions {}

class _MockExchangeOrderRepository extends Mock
    implements ExchangeOrderRepository {}

class _MockGetTransactionOrderSwapsUsecase extends Mock
    implements GetTransactionOrderSwapsUsecase {}

const _txId = 'tx-1';

void main() {
  late _MockSettingsRepository settingsRepository;
  late _MockWalletTransactionRepository walletTransactionRepository;
  late _MockSwapHistoryRepository swapHistoryRepository;
  late _MockPayjoinSessions payjoinSessions;
  late _MockExchangeOrderRepository mainnetOrderRepository;
  late _MockExchangeOrderRepository testnetOrderRepository;
  late _MockGetTransactionOrderSwapsUsecase getTransactionOrderSwapsUsecase;
  late GetTransactionsByTxIdUsecase usecase;

  setUp(() {
    settingsRepository = _MockSettingsRepository();
    walletTransactionRepository = _MockWalletTransactionRepository();
    swapHistoryRepository = _MockSwapHistoryRepository();
    payjoinSessions = _MockPayjoinSessions();
    mainnetOrderRepository = _MockExchangeOrderRepository();
    testnetOrderRepository = _MockExchangeOrderRepository();
    getTransactionOrderSwapsUsecase = _MockGetTransactionOrderSwapsUsecase();
    usecase = GetTransactionsByTxIdUsecase(
      settingsRepository: settingsRepository,
      walletTransactionRepository: walletTransactionRepository,
      boltzSwapRepository: swapHistoryRepository,
      payjoinSessions: payjoinSessions,
      mainnetExchangeOrderRepository: mainnetOrderRepository,
      testnetExchangeOrderRepository: testnetOrderRepository,
      getTransactionOrderSwapsUsecase: getTransactionOrderSwapsUsecase,
    );

    when(() => settingsRepository.fetch()).thenAnswer((_) async => _settings());
    when(
      () => walletTransactionRepository.getWalletTransactions(
        txId: any(named: 'txId'),
      ),
    ).thenAnswer((_) async => []);
    when(
      () => swapHistoryRepository.getSwapByTxId(any()),
    ).thenAnswer((_) async => null);
    when(
      () => getTransactionOrderSwapsUsecase.execute(),
    ).thenAnswer((_) async => []);
  });

  test(
    'keeps the order when only a payjoin session is found for the txid',
    () async {
      final payjoin = _payjoinSession();
      final order = _buyOrder();
      when(
        () => payjoinSessions.byTransactionId(_txId),
      ).thenAnswer((_) async => Ok([payjoin]));
      when(
        () => mainnetOrderRepository.getOrderByTxId(_txId),
      ).thenAnswer((_) async => order);

      final transactions = await usecase.execute(_txId);

      expect(transactions, hasLength(1));
      expect(transactions.single.payjoin, payjoin);
      // Without this the order-anchored details screen renders as a payjoin
      // session until the wallet indexes the broadcast.
      expect(transactions.single.order, order);
    },
  );

  test('still returns the payjoin when no order matches the txid', () async {
    final payjoin = _payjoinSession();
    when(
      () => payjoinSessions.byTransactionId(_txId),
    ).thenAnswer((_) async => Ok([payjoin]));
    when(
      () => mainnetOrderRepository.getOrderByTxId(_txId),
    ).thenAnswer((_) async => null);

    final transactions = await usecase.execute(_txId);

    expect(transactions, hasLength(1));
    expect(transactions.single.payjoin, payjoin);
    expect(transactions.single.order, isNull);
  });
}

SettingsEntity _settings() => const SettingsEntity(
  environment: Environment.mainnet,
  bitcoinUnit: BitcoinUnit.btc,
  currencyCode: 'CAD',
);

PayjoinSession _payjoinSession() => PayjoinReceiverSession(
  status: PayjoinStatus.completed,
  id: 'payjoin-1',
  network: BitcoinNetwork.mainnet,
  walletId: 'wallet-1',
  createdAt: DateTime.utc(2026, 8, 19),
  expiresAt: DateTime.utc(2026, 8, 20),
  payjoinUri: 'bitcoin:address?pj=https://payjoin.example',
  transactionId: _txId,
);

Order _buyOrder() => Order.buy(
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
  payjoinDetails: OrderPayjoinDetails(txid: _txId),
  isTestnet: false,
);
