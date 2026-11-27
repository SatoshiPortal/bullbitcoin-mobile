import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:transactions/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// The failure an [Err] carries, typed by the [Result]; an [Ok] fails the test.
F _failureOf<T, F extends Failure>(Result<T, F> result) => switch (result) {
  Ok() => fail('expected an Err, got Ok'),
  Err(:final failure) => failure,
};

/// The value an [Ok] carries; an [Err] fails the test, naming the failure.
T _valueOf<T, F extends Failure>(Result<T, F> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => fail('expected an Ok, got ${failure.runtimeType}'),
};

class _MockOrdersRepository extends Mock implements OrdersRepository {}

class _MockPreferences extends Mock implements Preferences {}

Order _order() => Order.buy(
  orderId: 'order-1',
  orderType: OrderType.buy,
  message: OrderMessage(code: '', message: ''),
  orderNumber: 1,
  payinAmount: 100,
  payinCurrency: 'CAD',
  payoutAmount: 0.001,
  payoutCurrency: 'BTC',
  payinMethod: OrderPaymentMethod.eTransfer,
  payoutMethod: OrderPaymentMethod.bitcoin,
  orderStatus: OrderStatus.inProgress,
  payinStatus: OrderPayinStatus.completed,
  payoutStatus: OrderPayoutStatus.completed,
  createdAt: DateTime.utc(2026, 8, 19),
  isTestnet: false,
);

void main() {
  late _MockOrdersRepository getOrder;
  late GetTransactionOrderUsecase usecase;
  late _MockPreferences preferences;
  late List<ExchangeEnvironment> requestedEnvironments;

  setUp(() {
    getOrder = _MockOrdersRepository();
    preferences = _MockPreferences();
    requestedEnvironments = [];
    when(preferences.fetch).thenAnswer(
      (_) async => const Ok(
        SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
        ),
      ),
    );
    usecase = GetTransactionOrderUsecase(
      exchangeForTesting(
        orders: (environment) {
          requestedEnvironments.add(environment);
          return getOrder;
        },
      ),
      preferences,
    );
  });

  test('forwards the order on success', () async {
    final order = _order();
    when(() => getOrder.getOrder('order-1')).thenAnswer((_) async => Ok(order));

    expect(_valueOf(await usecase.execute('order-1')), order);
  });

  test('regtest does not request either exchange backend', () async {
    when(preferences.fetch).thenAnswer(
      (_) async => const Ok(
        SettingsEntity(
          environment: Environment.regtest,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
        ),
      ),
    );

    expect(
      _failureOf(await usecase.execute('order-1')),
      isA<TransactionUnexpectedFailure>(),
    );
    expect(requestedEnvironments, isEmpty);
  });

  test('sanitizes an exchange API error', () async {
    when(() => getOrder.getOrder('order-1'))
        .thenAnswer((_) async => const Err(ExchangeOrderLoadFailure()));

    final result = await usecase.execute('order-1');

    final failure = _failureOf(result);
    expect(failure, isA<TransactionUnexpectedFailure>());
    // An API key in an error body is the worst case of a raw leak (#2140).
    expect(failure.logMessage, isNot(contains('bb_live')));
    expect(failure.logMessage, isNot(contains('api key')));
  });
}
