import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/buy/domain/accelerate_buy_order_usecase.dart';
import 'package:bb_mobile/features/buy/domain/buy_failure.dart';
import 'package:bb_mobile/features/buy/domain/confirm_buy_order_usecase.dart';
import 'package:bb_mobile/features/buy/domain/refresh_buy_order_usecase.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockExchangeOrderRepository extends Mock
    implements ExchangeOrderRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockSettings extends Mock implements SettingsEntity {}

class _MockLabelsFacade extends Mock implements LabelsFacade {}

class _MockBuyOrder extends Mock implements BuyOrder {}

class _FakeNewLabel extends Fake implements NewLabel {}

class _FakeLabel extends Fake implements Label {}

/// A reason of the shape the exchange API produces, quoting a key.
const _rawReason = 'DioException 500 apikey=secret123';

void main() {
  late _MockExchangeOrderRepository mainnet;
  late _MockExchangeOrderRepository testnet;
  late _MockSettingsRepository settingsRepository;

  setUpAll(() => registerFallbackValue(_FakeNewLabel()));

  setUp(() {
    mainnet = _MockExchangeOrderRepository();
    testnet = _MockExchangeOrderRepository();
    settingsRepository = _MockSettingsRepository();
    final settings = _MockSettings();
    when(() => settings.environment).thenReturn(Environment.mainnet);
    when(settingsRepository.fetch).thenAnswer((_) async => settings);
  });

  group('RefreshBuyOrderUsecase', () {
    RefreshBuyOrderUsecase build() => RefreshBuyOrderUsecase(
      mainnetExchangeOrderRepository: mainnet,
      testnetExchangeOrderRepository: testnet,
      settingsRepository: settingsRepository,
    );

    test('returns the refreshed order', () async {
      final order = _MockBuyOrder();
      when(
        () => mainnet.refreshBuyOrder('order-1'),
      ).thenAnswer((_) async => order);

      final result = await build().execute(orderId: 'order-1');

      expect((result as Ok<BuyOrder, BuyFailure>).value, order);
    });

    test('sanitizes a failure, keeping the reason for logs only', () async {
      when(
        () => mainnet.refreshBuyOrder('order-1'),
      ).thenThrow(Exception(_rawReason));

      final result = await build().execute(orderId: 'order-1');

      switch (result) {
        case Ok():
          fail('a failed refresh must not report an order');
        case Err(:final failure):
          expect(failure, isA<BuyUnexpectedFailure>());
          expect(failure.logMessage, contains('secret123'));
      }
    });

    test('maps a missing or inactive API key to unauthenticated', () async {
      for (final exception in [
        ApiKeyNotFoundException(),
        ApiKeyInactiveException(),
      ]) {
        when(() => mainnet.refreshBuyOrder('order-1')).thenThrow(exception);

        final result = await build().execute(orderId: 'order-1');

        expect(
          (result as Err<BuyOrder, BuyFailure>).failure,
          isA<BuyUnauthenticatedFailure>(),
        );
      }
    });

    test('uses the testnet repository on testnet', () async {
      final settings = _MockSettings();
      when(() => settings.environment).thenReturn(Environment.testnet);
      when(settingsRepository.fetch).thenAnswer((_) async => settings);
      when(
        () => testnet.refreshBuyOrder('order-1'),
      ).thenAnswer((_) async => _MockBuyOrder());

      expect(
        await build().execute(orderId: 'order-1'),
        isA<Ok<BuyOrder, BuyFailure>>(),
      );
      verifyNever(() => mainnet.refreshBuyOrder(any()));
    });
  });

  group('ConfirmBuyOrderUsecase', () {
    late _MockLabelsFacade labels;

    ConfirmBuyOrderUsecase build() => ConfirmBuyOrderUsecase(
      mainnetExchangeOrderRepository: mainnet,
      testnetExchangeOrderRepository: testnet,
      settingsRepository: settingsRepository,
      labelsFacade: labels,
    );

    setUp(() {
      labels = _MockLabelsFacade();
      when(
        () => labels.store(any()),
      ).thenAnswer((_) async => Ok<Label, LabelFailure>(_FakeLabel()));
    });

    test('confirms and labels the payout address', () async {
      final order = _MockBuyOrder();
      when(() => order.toAddress).thenReturn('bc1qpayoutaddress');
      when(
        () => mainnet.confirmBuyOrder('order-1'),
      ).thenAnswer((_) async => order);

      final result = await build().execute(orderId: 'order-1');

      expect(result, isA<Ok<BuyOrder, BuyFailure>>());
      verify(() => labels.store(any())).called(1);
    });

    test('labels nothing when the order has no payout address', () async {
      final order = _MockBuyOrder();
      when(() => order.toAddress).thenReturn(null);
      when(
        () => mainnet.confirmBuyOrder('order-1'),
      ).thenAnswer((_) async => order);

      expect(
        await build().execute(orderId: 'order-1'),
        isA<Ok<BuyOrder, BuyFailure>>(),
      );
      verifyNever(() => labels.store(any()));
    });

    test('sanitizes a failure', () async {
      when(
        () => mainnet.confirmBuyOrder('order-1'),
      ).thenThrow(Exception(_rawReason));

      final result = await build().execute(orderId: 'order-1');

      switch (result) {
        case Ok():
          fail('a failed confirmation must not report a confirmed order');
        case Err(:final failure):
          expect(failure, isA<BuyUnexpectedFailure>());
      }
    });
  });

  group('AccelerateBuyOrderUsecase', () {
    AccelerateBuyOrderUsecase build() => AccelerateBuyOrderUsecase(
      mainnetExchangeOrderRepository: mainnet,
      testnetExchangeOrderRepository: testnet,
      settingsRepository: settingsRepository,
    );

    test('returns the accelerated order', () async {
      final order = _MockBuyOrder();
      when(
        () => mainnet.accelerateBuyOrder('order-1'),
      ).thenAnswer((_) async => order);

      expect(
        (await build().execute('order-1') as Ok<BuyOrder, BuyFailure>).value,
        order,
      );
    });

    test('sanitizes a failure', () async {
      when(
        () => mainnet.accelerateBuyOrder('order-1'),
      ).thenThrow(Exception(_rawReason));

      final result = await build().execute('order-1');

      switch (result) {
        case Ok():
          fail('a failed acceleration must not report an order');
        case Err(:final failure):
          expect(failure, isA<BuyUnexpectedFailure>());
      }
    });
  });
}
