import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/label_exchange_orders_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_transactions_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockWalletTransactionRepository extends Mock
    implements WalletTransactionRepository {}

class _MockBoltzSwapRepository extends Mock implements BoltzSwapRepository {}

class _MockPayjoinRepository extends Mock implements PayjoinRepository {}

class _MockExchangeOrderRepository extends Mock
    implements ExchangeOrderRepository {}

class _MockLabelExchangeOrdersUsecase extends Mock
    implements LabelExchangeOrdersUsecase {}

void main() {
  late _MockSettingsRepository settingsRepository;
  late _MockWalletTransactionRepository walletTransactionRepository;
  late _MockBoltzSwapRepository boltzSwapRepository;
  late _MockPayjoinRepository payjoinRepository;
  late _MockExchangeOrderRepository mainnetOrderRepository;
  late _MockExchangeOrderRepository testnetOrderRepository;
  late _MockLabelExchangeOrdersUsecase labelExchangeOrdersUsecase;
  late List<Order> orders;
  late GetTransactionsUsecase usecase;

  PayjoinReceiver receiver(PayjoinStatus status) =>
      Payjoin.receiver(
            status: status,
            id: 'pj1',
            isTestnet: false,
            walletId: 'w1',
            pjUri: 'bitcoin:bc1qtest?pj=https://payjo.in',
            createdAt: DateTime(2026),
            expiresAt: DateTime(2026).add(const Duration(minutes: 1)),
            originalTxId: 'original-txid',
          )
          as PayjoinReceiver;

  setUp(() {
    settingsRepository = _MockSettingsRepository();
    walletTransactionRepository = _MockWalletTransactionRepository();
    boltzSwapRepository = _MockBoltzSwapRepository();
    payjoinRepository = _MockPayjoinRepository();
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
      payjoinRepository: payjoinRepository,
      mainnetExchangeOrderRepository: mainnetOrderRepository,
      testnetExchangeOrderRepository: testnetOrderRepository,
      labelExchangeOrdersUsecase: labelExchangeOrdersUsecase,
    );
  });

  test(
    'hides an aborted Payjoin until its original wallet tx is synced',
    () async {
      when(
        () => payjoinRepository.getPayjoins(
          walletId: any(named: 'walletId'),
          environment: any(named: 'environment'),
        ),
      ).thenAnswer((_) async => [receiver(PayjoinStatus.aborted)]);

      final transactions = await usecase.execute();

      expect(transactions, isEmpty);
    },
  );

  test('keeps a genuinely pending Payjoin in the transaction list', () async {
    when(
      () => payjoinRepository.getPayjoins(
        walletId: any(named: 'walletId'),
        environment: any(named: 'environment'),
      ),
    ).thenAnswer((_) async => [receiver(PayjoinStatus.requested)]);

    final transactions = await usecase.execute();

    expect(transactions, hasLength(1));
    expect(transactions.single.payjoin?.status, PayjoinStatus.requested);
  });

  test('labels exchange orders before loading wallet transactions', () async {
    when(
      () => payjoinRepository.getPayjoins(
        walletId: any(named: 'walletId'),
        environment: any(named: 'environment'),
      ),
    ).thenAnswer((_) async => []);

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
}
