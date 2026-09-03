import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/sell/domain/refresh_sell_order_usecase.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockExchangeOrderRepository extends Mock
    implements ExchangeOrderRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockSettings extends Mock implements SettingsEntity {}

class _MockSellOrder extends Mock implements SellOrder {}

const _confirmedAddress = 'bc1qtheaddressuserconfirmed';

void main() {
  late _MockExchangeOrderRepository mainnet;
  late _MockExchangeOrderRepository testnet;
  late _MockSettingsRepository settingsRepository;
  late RefreshSellOrderUsecase usecase;

  setUp(() {
    mainnet = _MockExchangeOrderRepository();
    testnet = _MockExchangeOrderRepository();
    settingsRepository = _MockSettingsRepository();
    final settings = _MockSettings();
    when(() => settings.environment).thenReturn(Environment.mainnet);
    when(settingsRepository.fetch).thenAnswer((_) async => settings);

    usecase = RefreshSellOrderUsecase(
      mainnetExchangeOrderRepository: mainnet,
      testnetExchangeOrderRepository: testnet,
      settingsRepository: settingsRepository,
    );
  });

  SellOrder orderPaying(String address) {
    final order = _MockSellOrder();
    when(() => order.toAddress).thenReturn(address);
    return order;
  }

  test(
    'returns the refreshed order when the deposit address is stable',
    () async {
      final order = orderPaying(_confirmedAddress);
      when(
        () => mainnet.refreshSellOrder('order-1'),
      ).thenAnswer((_) async => order);

      final result = await usecase.execute(
        orderId: 'order-1',
        expectedDepositAddress: _confirmedAddress,
      );

      expect(result, isA<Ok<SellOrder, SellFailure>>());
    },
  );

  // Security-critical: a price-lock refresh that comes back paying somewhere
  // else would send the user's funds to an address they never confirmed.
  test('refuses an order whose deposit address moved', () async {
    final order = orderPaying('bc1qattackercontrolledaddress');
    when(
      () => mainnet.refreshSellOrder('order-1'),
    ).thenAnswer((_) async => order);

    final result = await usecase.execute(
      orderId: 'order-1',
      expectedDepositAddress: _confirmedAddress,
    );

    switch (result) {
      case Ok():
        fail('an order paying a different address must never be returned');
      case Err(:final failure):
        expect(failure, isA<SellDepositAddressChangedFailure>());
    }
  });

  test('refuses when there is no address to compare against', () async {
    final order = orderPaying(_confirmedAddress);
    when(
      () => mainnet.refreshSellOrder('order-1'),
    ).thenAnswer((_) async => order);

    for (final expected in [null, '']) {
      final result = await usecase.execute(
        orderId: 'order-1',
        expectedDepositAddress: expected,
      );

      expect(
        result,
        isA<Err<SellOrder, SellFailure>>(),
        reason: 'fail closed rather than trust an unverifiable address',
      );
    }
  });

  test('maps an unauthenticated API to its own failure', () async {
    when(
      () => mainnet.refreshSellOrder('order-1'),
    ).thenThrow(ApiKeyException('API key not found or inactive'));

    final result = await usecase.execute(
      orderId: 'order-1',
      expectedDepositAddress: _confirmedAddress,
    );

    expect(
      (result as Err<SellOrder, SellFailure>).failure,
      isA<SellUnauthenticatedFailure>(),
    );
  });

  test('sanitizes any other error into the catch-all', () async {
    when(
      () => mainnet.refreshSellOrder('order-1'),
    ).thenThrow(Exception('Dio 500: {"token":"secret"}'));

    final result = await usecase.execute(
      orderId: 'order-1',
      expectedDepositAddress: _confirmedAddress,
    );

    expect(
      (result as Err<SellOrder, SellFailure>).failure,
      isA<SellUnexpectedFailure>(),
    );
  });

  test('uses the testnet repository on testnet', () async {
    final settings = _MockSettings();
    when(() => settings.environment).thenReturn(Environment.testnet);
    when(settingsRepository.fetch).thenAnswer((_) async => settings);
    final order = orderPaying(_confirmedAddress);
    when(
      () => testnet.refreshSellOrder('order-1'),
    ).thenAnswer((_) async => order);

    final result = await usecase.execute(
      orderId: 'order-1',
      expectedDepositAddress: _confirmedAddress,
    );

    expect(result, isA<Ok<SellOrder, SellFailure>>());
    verifyNever(() => mainnet.refreshSellOrder(any()));
  });
}
