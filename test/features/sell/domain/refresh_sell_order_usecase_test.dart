import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sell/domain/refresh_sell_order_usecase.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockExchangeOrderRepository extends Mock
    implements ExchangeOrderRepository {}

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockSellOrder extends Mock implements SellOrder {}

void main() {
  late MockExchangeOrderRepository mainnetRepo;
  late MockExchangeOrderRepository testnetRepo;
  late MockSettingsRepository settingsRepository;
  late RefreshSellOrderUsecase usecase;

  final fakeSettings = SettingsEntity(
    environment: Environment.mainnet,
    bitcoinUnit: BitcoinUnit.sats,
    currencyCode: 'CAD',
  );

  setUp(() {
    mainnetRepo = MockExchangeOrderRepository();
    testnetRepo = MockExchangeOrderRepository();
    settingsRepository = MockSettingsRepository();
    usecase = RefreshSellOrderUsecase(
      mainnetExchangeOrderRepository: mainnetRepo,
      testnetExchangeOrderRepository: testnetRepo,
      settingsRepository: settingsRepository,
    );
    when(() => settingsRepository.fetch())
        .thenAnswer((_) async => fakeSettings);
  });

  group('RefreshSellOrderUsecase', () {
    test('returns Ok(order) on success', () async {
      final fakeOrder = MockSellOrder();
      when(() => mainnetRepo.refreshSellOrder(any()))
          .thenAnswer((_) async => fakeOrder);

      final result = await usecase.execute(orderId: 'order-123');

      expect(result, isA<Ok<SellOrder, SellFailure>>());
      expect((result as Ok).value, fakeOrder);
    });

    test(
      'returns Err(SellUnexpectedFailure) on exception — raw message in logMessage only',
      () async {
        when(() => mainnetRepo.refreshSellOrder(any()))
            .thenThrow(Exception('server error'));

        final result = await usecase.execute(orderId: 'order-123');

        expect(result, isA<Err<SellOrder, SellFailure>>());
        final failure = (result as Err).failure;
        expect(failure, isA<SellUnexpectedFailure>());
        expect(
          (failure as SellUnexpectedFailure).logMessage,
          contains('server error'),
        );
      },
    );

    test('uses testnet repo when environment is testnet', () async {
      final testnetSettings = SettingsEntity(
        environment: Environment.testnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      );
      when(() => settingsRepository.fetch())
          .thenAnswer((_) async => testnetSettings);

      final fakeOrder = MockSellOrder();
      when(() => testnetRepo.refreshSellOrder(any()))
          .thenAnswer((_) async => fakeOrder);

      final result = await usecase.execute(orderId: 'test-order-456');

      expect(result, isA<Ok<SellOrder, SellFailure>>());
      verifyNever(() => mainnetRepo.refreshSellOrder(any()));
    });
  });
}
