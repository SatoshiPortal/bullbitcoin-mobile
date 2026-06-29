import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/errors/sell_error.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sell/domain/create_sell_order_usecase.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockExchangeOrderRepository extends Mock
    implements ExchangeOrderRepository {}

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockSellOrder extends Mock implements SellOrder {}

void main() {
  setUpAll(() {
    registerFallbackValue(const FiatAmount(100));
    registerFallbackValue(FiatCurrency.cad);
    registerFallbackValue(OrderBitcoinNetwork.bitcoin);
  });

  late MockExchangeOrderRepository mainnetRepo;
  late MockExchangeOrderRepository testnetRepo;
  late MockSettingsRepository settingsRepository;
  late CreateSellOrderUsecase usecase;

  final fakeSettings = SettingsEntity(
    environment: Environment.mainnet,
    bitcoinUnit: BitcoinUnit.sats,
    currencyCode: 'CAD',
  );

  setUp(() {
    mainnetRepo = MockExchangeOrderRepository();
    testnetRepo = MockExchangeOrderRepository();
    settingsRepository = MockSettingsRepository();
    usecase = CreateSellOrderUsecase(
      mainnetExchangeOrderRepository: mainnetRepo,
      testnetExchangeOrderRepository: testnetRepo,
      settingsRepository: settingsRepository,
    );
    when(() => settingsRepository.fetch())
        .thenAnswer((_) async => fakeSettings);
  });

  group('CreateSellOrderUsecase', () {
    test('returns Ok(order) on success', () async {
      final fakeOrder = MockSellOrder();
      when(() => mainnetRepo.placeSellOrder(
            orderAmount: any(named: 'orderAmount'),
            currency: any(named: 'currency'),
            network: any(named: 'network'),
          )).thenAnswer((_) async => fakeOrder);

      final result = await usecase.execute(
        orderAmount: const FiatAmount(100),
        currency: FiatCurrency.cad,
        network: OrderBitcoinNetwork.bitcoin,
      );

      expect(result, isA<Ok<SellOrder, SellFailure>>());
      expect((result as Ok).value, fakeOrder);
    });

    test('returns Err(SellUnauthenticatedFailure) — no raw leak', () async {
      when(() => mainnetRepo.placeSellOrder(
            orderAmount: any(named: 'orderAmount'),
            currency: any(named: 'currency'),
            network: any(named: 'network'),
          )).thenThrow(const SellError.unauthenticated());

      final result = await usecase.execute(
        orderAmount: const FiatAmount(100),
        currency: FiatCurrency.cad,
        network: OrderBitcoinNetwork.bitcoin,
      );

      expect(result, isA<Err<SellOrder, SellFailure>>());
      expect((result as Err).failure, isA<SellUnauthenticatedFailure>());
    });

    test('returns Err(SellBelowMinAmountFailure) with correct sat amount',
        () async {
      when(() => mainnetRepo.placeSellOrder(
            orderAmount: any(named: 'orderAmount'),
            currency: any(named: 'currency'),
            network: any(named: 'network'),
          )).thenThrow(
        const SellError.belowMinAmount(minAmountSat: 10000),
      );

      final result = await usecase.execute(
        orderAmount: const FiatAmount(1),
        currency: FiatCurrency.cad,
        network: OrderBitcoinNetwork.bitcoin,
      );

      expect(result, isA<Err<SellOrder, SellFailure>>());
      final failure = (result as Err).failure as SellBelowMinAmountFailure;
      expect(failure.minAmountSat, 10000);
    });

    test('returns Err(SellAboveMaxAmountFailure) with correct sat amount',
        () async {
      when(() => mainnetRepo.placeSellOrder(
            orderAmount: any(named: 'orderAmount'),
            currency: any(named: 'currency'),
            network: any(named: 'network'),
          )).thenThrow(
        const SellError.aboveMaxAmount(maxAmountSat: 500000),
      );

      final result = await usecase.execute(
        orderAmount: const FiatAmount(999),
        currency: FiatCurrency.cad,
        network: OrderBitcoinNetwork.bitcoin,
      );

      expect(result, isA<Err<SellOrder, SellFailure>>());
      final failure = (result as Err).failure as SellAboveMaxAmountFailure;
      expect(failure.maxAmountSat, 500000);
    });

    test(
      'returns Err(SellUnexpectedFailure) on generic exception — raw message in logMessage only',
      () async {
        when(() => mainnetRepo.placeSellOrder(
              orderAmount: any(named: 'orderAmount'),
              currency: any(named: 'currency'),
              network: any(named: 'network'),
            )).thenThrow(Exception('network timeout'));

        final result = await usecase.execute(
          orderAmount: const FiatAmount(100),
          currency: FiatCurrency.cad,
          network: OrderBitcoinNetwork.bitcoin,
        );

        expect(result, isA<Err<SellOrder, SellFailure>>());
        final failure = (result as Err).failure;
        expect(failure, isA<SellUnexpectedFailure>());
        expect(
          (failure as SellUnexpectedFailure).logMessage,
          contains('network timeout'),
        );
      },
    );
  });
}
