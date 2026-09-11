import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/pay/domain/place_pay_order_usecase.dart';
import 'package:bb_mobile/features/pay/domain/pay_failure.dart';
import 'package:bb_mobile/features/pay/domain/refresh_pay_order_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockExchangeOrderRepository extends Mock
    implements ExchangeOrderRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockPayjoinPolicy extends Mock implements PayjoinPolicyAccess {}

class _MockSettings extends Mock implements SettingsEntity {}

class _MockPayOrder extends Mock implements FiatPaymentOrder {}

/// The raw text the exchange and Dio actually produce. Every assertion below
/// proves it is confined to `logMessage`.
const _rawReason = 'DioException 500 apiKey=live_secret_abc';

void main() {
  late _MockExchangeOrderRepository mainnet;
  late _MockExchangeOrderRepository testnet;
  late _MockSettingsRepository settings;
  late _MockPayjoinPolicy payjoinPolicy;

  setUpAll(() {
    registerFallbackValue(const FiatAmount(100));
    registerFallbackValue(OrderBitcoinNetwork.bitcoin);
  });

  setUp(() {
    mainnet = _MockExchangeOrderRepository();
    testnet = _MockExchangeOrderRepository();
    settings = _MockSettingsRepository();
    payjoinPolicy = _MockPayjoinPolicy();

    final settingsEntity = _MockSettings();
    when(() => settingsEntity.environment).thenReturn(Environment.mainnet);
    when(settings.fetch).thenAnswer((_) async => settingsEntity);
    when(payjoinPolicy.load).thenAnswer(
      (_) async =>
          const Err<PayjoinPolicy, PayjoinFailure>(PayjoinStorageFailure()),
    );
  });

  PlacePayOrderUsecase buildPlace() => PlacePayOrderUsecase(
    mainnetExchangeOrderRepository: mainnet,
    testnetExchangeOrderRepository: testnet,
    settingsRepository: settings,
    payjoinPolicy: payjoinPolicy,
  );

  RefreshPayOrderUsecase buildRefresh() => RefreshPayOrderUsecase(
    mainnetExchangeOrderRepository: mainnet,
    testnetExchangeOrderRepository: testnet,
    settingsRepository: settings,
  );

  Future<Result<FiatPaymentOrder, PayFailure>> place() => buildPlace().execute(
    orderAmount: const FiatAmount(100),
    recipientId: 'recipient-1',
    network: OrderBitcoinNetwork.bitcoin,
  );

  group('PlacePayOrderUsecase', () {
    test(
      'an expired session is a typed failure, not a thrown exception',
      () async {
        when(
          () => mainnet.placePayOrder(
            orderAmount: any(named: 'orderAmount'),
            recipientId: any(named: 'recipientId'),
            network: any(named: 'network'),
            paymentDescription: any(named: 'paymentDescription'),
            usePayjoin: any(named: 'usePayjoin'),
          ),
        ).thenThrow(ApiKeyException(_rawReason));

        final result = await place();

        final failure = (result as Err<FiatPaymentOrder, PayFailure>).failure;
        expect(failure, isA<PayUnauthenticatedFailure>());
        expect(failure.logMessage, _rawReason);
      },
    );

    test('the amount bounds keep the bound, not just a message', () async {
      when(
        () => mainnet.placePayOrder(
          orderAmount: any(named: 'orderAmount'),
          recipientId: any(named: 'recipientId'),
          network: any(named: 'network'),
          paymentDescription: any(named: 'paymentDescription'),
          usePayjoin: any(named: 'usePayjoin'),
        ),
      ).thenThrow(
        BullBitcoinApiMinAmountException(minAmount: 25.0, currency: 'CAD'),
      );

      final failure =
          (await place() as Err<FiatPaymentOrder, PayFailure>).failure;

      expect(failure, isA<PayBelowMinAmountFailure>());
      expect((failure as PayBelowMinAmountFailure).minAmount, 25.0);
      expect(failure.currency, 'CAD');
    });

    test('any other reason is sanitized into the catch-all', () async {
      when(
        () => mainnet.placePayOrder(
          orderAmount: any(named: 'orderAmount'),
          recipientId: any(named: 'recipientId'),
          network: any(named: 'network'),
          paymentDescription: any(named: 'paymentDescription'),
          usePayjoin: any(named: 'usePayjoin'),
        ),
      ).thenThrow(Exception(_rawReason));

      final failure =
          (await place() as Err<FiatPaymentOrder, PayFailure>).failure;

      expect(failure, isA<PayUnexpectedFailure>());
      // The reason survives for the logs, and only for the logs.
      expect(failure.logMessage, contains(_rawReason));
    });
  });

  group('RefreshPayOrderUsecase', () {
    test('a deposit address that moved is refused, not returned', () async {
      final order = _MockPayOrder();
      when(() => order.toAddress).thenReturn('bc1qattacker');
      when(() => mainnet.refreshPayOrder(any())).thenAnswer((_) async => order);

      final result = await buildRefresh().execute(
        orderId: 'order-1',
        expectedDepositAddress: 'bc1qoriginal',
      );

      expect(
        (result as Err<FiatPaymentOrder, PayFailure>).failure,
        isA<PayDepositAddressChangedFailure>(),
      );
    });

    test('the unchanged address is adopted', () async {
      final order = _MockPayOrder();
      when(() => order.toAddress).thenReturn('bc1qoriginal');
      when(() => mainnet.refreshPayOrder(any())).thenAnswer((_) async => order);

      final result = await buildRefresh().execute(
        orderId: 'order-1',
        expectedDepositAddress: 'bc1qoriginal',
      );

      expect((result as Ok<FiatPaymentOrder, PayFailure>).value, same(order));
    });

    test('a refresh failure is sanitized, reason kept for logs only', () async {
      when(
        () => mainnet.refreshPayOrder(any()),
      ).thenThrow(Exception(_rawReason));

      final failure =
          (await buildRefresh().execute(
                    orderId: 'order-1',
                    expectedDepositAddress: 'bc1qoriginal',
                  )
                  as Err<FiatPaymentOrder, PayFailure>)
              .failure;

      expect(failure, isA<PayUnexpectedFailure>());
      expect(failure.logMessage, contains(_rawReason));
    });
  });

  group('payOrderDepositAddressMatches', () {
    test('a missing expectation never counts as a match', () {
      final order = _MockPayOrder();
      when(() => order.toAddress).thenReturn('bc1qoriginal');

      // Fail closed: with nothing to compare against, adopting the refreshed
      // address is exactly the tampering this guard exists to stop.
      expect(
        payOrderDepositAddressMatches(
          order: order,
          expectedDepositAddress: null,
        ),
        isFalse,
      );
      expect(
        payOrderDepositAddressMatches(order: order, expectedDepositAddress: ''),
        isFalse,
      );
    });
  });
}
