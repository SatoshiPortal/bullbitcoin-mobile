import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/sell/domain/usecases/refresh_sell_order_usecase.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockExchangeOrderRepository extends Mock
    implements ExchangeOrderRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockSettings extends Mock implements SettingsEntity {}

class _MockSellOrder extends Mock implements SellOrder {}

class _MockFiatPaymentOrder extends Mock implements FiatPaymentOrder {}

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
    when(() => order.bitcoinAddress).thenReturn(address);
    when(() => order.liquidAddress).thenReturn(null);
    when(() => order.payinMethod).thenReturn(OrderPaymentMethod.bitcoin);
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

      expect(result, isA<Ok<Order, SellFailure>>());
    },
  );

  group('recipient payouts', () {
    for (final address in [_confirmedAddress, 'bc1changed']) {
      test('refreshPayOrder pins the bank order deposit: $address', () async {
        final order = _MockFiatPaymentOrder();
        when(() => order.bitcoinAddress).thenReturn(address);
        when(() => order.liquidAddress).thenReturn(null);
        when(() => order.payinMethod).thenReturn(OrderPaymentMethod.bitcoin);
        when(
          () => mainnet.refreshPayOrder('bank-order'),
        ).thenAnswer((_) async => order);
        final result = await usecase.execute(
          orderId: 'bank-order',
          expectedDepositAddress: _confirmedAddress,
          isRecipientPayout: true,
        );
        if (address == _confirmedAddress) {
          expect((result as Ok<Order, SellFailure>).value, same(order));
        } else {
          expect(
            (result as Err<Order, SellFailure>).failure,
            isA<SellDepositAddressChangedFailure>(),
          );
        }
        verifyNever(() => mainnet.refreshSellOrder(any()));
      });
    }

    for (final invoice in ['lnbc-confirmed', 'lnbc-changed', null]) {
      test('Lightning refresh pins its invoice: $invoice', () async {
        final order = _MockFiatPaymentOrder();
        when(() => order.payinMethod).thenReturn(OrderPaymentMethod.lnInvoice);
        when(() => order.lightningInvoice).thenReturn(invoice);
        when(
          () => mainnet.refreshPayOrder('lightning-order'),
        ).thenAnswer((_) async => order);
        final result = await usecase.execute(
          orderId: 'lightning-order',
          expectedDepositAddress: null,
          expectedLightningInvoice: 'lnbc-confirmed',
          isRecipientPayout: true,
        );
        expect(
          result,
          invoice == 'lnbc-confirmed'
              ? isA<Ok<Order, SellFailure>>()
              : isA<Err<Order, SellFailure>>(),
        );
      });
    }
  });

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
        isA<Err<Order, SellFailure>>(),
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
      (result as Err<Order, SellFailure>).failure,
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
      (result as Err<Order, SellFailure>).failure,
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

    expect(result, isA<Ok<Order, SellFailure>>());
    verifyNever(() => mainnet.refreshSellOrder(any()));
  });
}
