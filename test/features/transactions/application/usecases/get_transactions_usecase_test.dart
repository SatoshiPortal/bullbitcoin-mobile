import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
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

void main() {
  late _MockSettingsRepository settingsRepository;
  late _MockWalletTransactionRepository walletTransactionRepository;
  late _MockBoltzSwapRepository boltzSwapRepository;
  late _MockPayjoinSessions payjoinSessions;
  late _MockExchangeOrderRepository mainnetOrderRepository;
  late _MockExchangeOrderRepository testnetOrderRepository;
  late _MockLabelExchangeOrdersUsecase labelExchangeOrdersUsecase;
  late List<Order> orders;
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

    usecase = GetTransactionsUsecase(
      settingsRepository: settingsRepository,
      walletTransactionRepository: walletTransactionRepository,
      boltzSwapRepository: boltzSwapRepository,
      payjoinSessions: payjoinSessions,
      mainnetExchangeOrderRepository: mainnetOrderRepository,
      testnetExchangeOrderRepository: testnetOrderRepository,
      labelExchangeOrdersUsecase: labelExchangeOrdersUsecase,
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

  test('labels exchange orders before loading wallet transactions', () async {
    when(
      () => payjoinSessions.list(any()),
    ).thenAnswer((_) async => const Ok([]));

    await usecase.execute();

    verifyInOrder([
      () => mainnetOrderRepository.getOrders(),
      () => labelExchangeOrdersUsecase.execute(orders: orders),
      () => walletTransactionRepository.getWalletTransactions(
        walletId: any(named: 'walletId'),
        sync: any(named: 'sync'),
        environment: any(named: 'environment'),
      ),
    ]);
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
}
