import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/sell/domain/create_sell_order_usecase.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockExchangeOrderRepository extends Mock
    implements ExchangeOrderRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockSettings extends Mock implements SettingsEntity {}

class _MockPayjoinPolicy extends Mock implements PayjoinPolicyAccess {}

class _MockSellOrder extends Mock implements SellOrder {}

void main() {
  late _MockExchangeOrderRepository mainnet;
  late CreateSellOrderUsecase usecase;

  setUpAll(() {
    registerFallbackValue(const FiatAmount(1));
    registerFallbackValue(FiatCurrency.cad);
    registerFallbackValue(OrderBitcoinNetwork.bitcoin);
  });

  setUp(() {
    mainnet = _MockExchangeOrderRepository();
    final settingsRepository = _MockSettingsRepository();
    final settings = _MockSettings();
    when(() => settings.environment).thenReturn(Environment.mainnet);
    when(settingsRepository.fetch).thenAnswer((_) async => settings);

    final payjoinPolicy = _MockPayjoinPolicy();
    when(payjoinPolicy.load).thenAnswer(
      (_) async =>
          const Err<PayjoinPolicy, PayjoinFailure>(PayjoinStorageFailure()),
    );

    usecase = CreateSellOrderUsecase(
      mainnetExchangeOrderRepository: mainnet,
      testnetExchangeOrderRepository: _MockExchangeOrderRepository(),
      settingsRepository: settingsRepository,
      payjoinPolicy: payjoinPolicy,
    );
  });

  Future<Result<SellOrder, SellFailure>> run() => usecase.execute(
    orderAmount: const FiatAmount(100),
    currency: FiatCurrency.cad,
    network: OrderBitcoinNetwork.bitcoin,
  );

  void stubThrow(Object error) {
    when(
      () => mainnet.placeSellOrder(
        orderAmount: any(named: 'orderAmount'),
        currency: any(named: 'currency'),
        network: any(named: 'network'),
        usePayjoin: any(named: 'usePayjoin'),
      ),
    ).thenThrow(error);
  }

  test('returns the placed order', () async {
    final order = _MockSellOrder();
    when(
      () => mainnet.placeSellOrder(
        orderAmount: any(named: 'orderAmount'),
        currency: any(named: 'currency'),
        network: any(named: 'network'),
        usePayjoin: any(named: 'usePayjoin'),
      ),
    ).thenAnswer((_) async => order);

    expect(await run(), isA<Ok<SellOrder, SellFailure>>());
  });

  // These three used to be translated inside the shared exchange repository,
  // which is why SellError lived in core. The mapping now happens here.
  test('maps a below-minimum API rejection with its bound', () async {
    stubThrow(BullBitcoinApiMinAmountException(minAmount: 25, currency: 'CAD'));

    final failure = (await run() as Err<SellOrder, SellFailure>).failure;

    expect(failure, isA<SellBelowMinAmountFailure>());
    expect((failure as SellBelowMinAmountFailure).minAmount, 25);
    expect(failure.currency, 'CAD');
  });

  test('maps an above-maximum API rejection with its bound', () async {
    stubThrow(
      BullBitcoinApiMaxAmountException(maxAmount: 5000, currency: 'CAD'),
    );

    final failure = (await run() as Err<SellOrder, SellFailure>).failure;

    expect(failure, isA<SellAboveMaxAmountFailure>());
    expect((failure as SellAboveMaxAmountFailure).maxAmount, 5000);
  });

  test('maps an unauthenticated API to its own failure', () async {
    stubThrow(ApiKeyException('API key not found or inactive'));

    expect(
      (await run() as Err<SellOrder, SellFailure>).failure,
      isA<SellUnauthenticatedFailure>(),
    );
  });

  test(
    'sanitizes an unexpected error and keeps the reason for logs only',
    () async {
      stubThrow(Exception('Dio 500 apikey=secret123'));

      final failure = (await run() as Err<SellOrder, SellFailure>).failure;

      expect(failure, isA<SellUnexpectedFailure>());
      expect(
        failure.logMessage,
        contains('secret123'),
        reason: 'the reason belongs in the log, not in the user message',
      );
    },
  );
}
