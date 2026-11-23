import 'package:exchange/testing.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/pay/domain/place_pay_order_usecase.dart';
import 'package:bb_mobile/features/pay/domain/pay_failure.dart';
import 'package:bb_mobile/features/pay/domain/refresh_pay_order_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockExchangeOrders extends Mock implements ExchangeOrders {}

class _MockSettingsRepository extends Mock implements Preferences {}

class _MockPayjoinPolicy extends Mock implements PayjoinPolicyAccess {}

class _MockSettings extends Mock implements SettingsEntity {}

class _MockPayOrder extends Mock implements FiatPaymentOrder {}

/// The raw text the exchange and Dio actually produce. Every assertion below
/// proves it is confined to `logMessage`.

void main() {
  var spendStatus = BitcoinSpendStatus.ready;
  late _MockExchangeOrders mainnet;
  late _MockExchangeOrders testnet;
  late _MockSettingsRepository settings;
  late _MockPayjoinPolicy payjoinPolicy;

  setUpAll(() {
    registerFallbackValue(const FiatAmount(100));
    registerFallbackValue(OrderBitcoinNetwork.bitcoin);
  });

  setUp(() {
    spendStatus = BitcoinSpendStatus.ready;
    mainnet = _MockExchangeOrders();
    testnet = _MockExchangeOrders();
    settings = _MockSettingsRepository();
    payjoinPolicy = _MockPayjoinPolicy();

    final settingsEntity = _MockSettings();
    when(() => settingsEntity.environment).thenReturn(Environment.mainnet);
    when(settings.fetch).thenAnswer((_) async => Ok(settingsEntity));
    when(payjoinPolicy.load).thenAnswer(
      (_) async =>
          const Err<PayjoinPolicy, PayjoinFailure>(PayjoinStorageFailure()),
    );
  });

  PlacePayOrderUsecase buildPlace() => PlacePayOrderUsecase(
    wallet: WalletFacade(
      const Stream.empty(),
      spendStatus: (_, {replacing}) async => spendStatus,
    ),
    exchange: exchangeForTesting(
      orders: (environment) =>
          environment == ExchangeEnvironment.testnet ? testnet : mainnet,
    ),
    settingsRepository: settings,
    payjoinPolicy: payjoinPolicy,
  );

  RefreshPayOrderUsecase buildRefresh() => RefreshPayOrderUsecase(
    exchange: exchangeForTesting(
      orders: (environment) =>
          environment == ExchangeEnvironment.testnet ? testnet : mainnet,
    ),
    settingsRepository: settings,
  );

  Future<Result<FiatPaymentOrder, PayFailure>> place() => buildPlace().execute(
    walletId: 'wallet-1',
    orderAmount: const FiatAmount(100),
    recipientId: 'recipient-1',
    network: OrderBitcoinNetwork.bitcoin,
  );

  test('gated Bitcoin wallet creates no exchange order', () async {
    spendStatus = BitcoinSpendStatus.pending;
    final result = await place();
    expect(
      result,
      isA<Err>().having(
        (result) => result.failure,
        'failure',
        isA<PaySpendBlockedFailure>().having((f) => f.busy, 'busy', isFalse),
      ),
    );
    verifyZeroInteractions(mainnet);
    verifyZeroInteractions(payjoinPolicy);
  });

  test('a busy wallet is not reported as awaiting a payment', () async {
    spendStatus = BitcoinSpendStatus.busy;
    final result = await place();
    expect(
      result,
      isA<Err>().having(
        (result) => result.failure,
        'failure',
        isA<PaySpendBlockedFailure>().having((f) => f.busy, 'busy', isTrue),
      ),
    );
    verifyZeroInteractions(mainnet);
  });

  for (final refresh in [false, true]) {
    test(
      'regtest refuses pay ${refresh ? 'refresh' : 'creation'} before backend IO',
      () async {
        when(settings.fetch).thenAnswer(
          (_) async => Ok(
            const SettingsEntity(
              environment: Environment.regtest,
              bitcoinUnit: BitcoinUnit.sats,
              currencyCode: 'CAD',
            ),
          ),
        );
        final result = refresh
            ? await buildRefresh().execute(
                orderId: 'order-1',
                expectedDepositAddress: 'address',
              )
            : await place();
        expect(
          result,
          isA<Err>().having(
            (result) => result.failure,
            'failure',
            isA<PayUnsupportedNetworkFailure>(),
          ),
        );
        verifyZeroInteractions(mainnet);
        verifyZeroInteractions(testnet);
        verifyZeroInteractions(payjoinPolicy);
      },
    );
  }

  group('PlacePayOrderUsecase', () {
    // A bill payment pays the exchange like a sell order does.
    Future<bool> requestedPayjoin(PayjoinPolicy policy) async {
      when(payjoinPolicy.load)
          .thenAnswer((_) async => Ok<PayjoinPolicy, PayjoinFailure>(policy));
      when(
        () => mainnet.placePayOrder(
          orderAmount: any(named: 'orderAmount'),
          recipientId: any(named: 'recipientId'),
          network: any(named: 'network'),
          paymentDescription: any(named: 'paymentDescription'),
          usePayjoin: any(named: 'usePayjoin'),
        ),
      ).thenAnswer((_) async => Ok(_MockPayOrder()));

      final _ = await buildPlace().execute(
        walletId: 'wallet-1',
        orderAmount: const FiatAmount(100),
        recipientId: 'recipient-1',
        network: OrderBitcoinNetwork.bitcoin,
        usePayjoin: true,
      );

      return verify(
            () => mainnet.placePayOrder(
              orderAmount: any(named: 'orderAmount'),
              recipientId: any(named: 'recipientId'),
              network: any(named: 'network'),
              paymentDescription: any(named: 'paymentDescription'),
              usePayjoin: captureAny(named: 'usePayjoin'),
            ),
          ).captured.single
          as bool;
    }

    test('payjoin is on by default, with receiving for users off', () async {
      expect(await requestedPayjoin(PayjoinPolicy.defaults()), isTrue);
    });

    test('payjoin follows the sell switch, not the user switches', () async {
      expect(
        await requestedPayjoin(
          PayjoinPolicy.defaults().copyWith(
            sendEnabled: true,
            receiveEnabled: true,
            sellEnabled: false,
          ),
        ),
        isFalse,
      );
    });

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
        ).thenAnswer((_) async => const Err(ExchangeSessionRejectedFailure()));

        final result = await place();

        final failure = (result as Err<FiatPaymentOrder, PayFailure>).failure;
        expect(failure, isA<PayUnauthenticatedFailure>());
        expect(
          failure.logMessage,
          isNull,
          reason: 'authentication failures must not retain credential-bearing exception messages',
        );
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
      ).thenAnswer(
        (_) async => const Err(
          ExchangeOrderLimitFailure(
            ExchangeOrderAmountBound.minimum,
            25.0,
            'CAD',
          ),
        ),
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
      ).thenAnswer((_) async => const Err(ExchangeOrderLoadFailure()));

      final failure =
          (await place() as Err<FiatPaymentOrder, PayFailure>).failure;

      expect(failure, isA<PayUnexpectedFailure>());
      expect(failure.logMessage, isNull);
    });
  });

  group('RefreshPayOrderUsecase', () {
    test('a deposit address that moved is refused, not returned', () async {
      final order = _MockPayOrder();
      when(() => order.toAddress).thenReturn('bc1qattacker');
      when(() => mainnet.refreshPayOrder(any()))
          .thenAnswer((_) async => Ok(order));

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
      when(() => mainnet.refreshPayOrder(any()))
          .thenAnswer((_) async => Ok(order));

      final result = await buildRefresh().execute(
        orderId: 'order-1',
        expectedDepositAddress: 'bc1qoriginal',
      );

      expect((result as Ok<FiatPaymentOrder, PayFailure>).value, same(order));
    });

    test('a refresh failure contains no foreign diagnostic text', () async {
      when(() => mainnet.refreshPayOrder(any()))
          .thenAnswer((_) async => const Err(ExchangeOrderLoadFailure()));

      final failure = (await buildRefresh().execute(
        orderId: 'order-1',
        expectedDepositAddress: 'bc1qoriginal',
      ) as Err<FiatPaymentOrder, PayFailure>).failure;

      expect(failure, isA<PayUnexpectedFailure>());
      expect(failure.logMessage, isNull);
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
