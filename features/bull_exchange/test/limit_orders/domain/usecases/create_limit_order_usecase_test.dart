import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';
import 'package:bull_exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../limit_order_fixtures.dart';

class MockLimitOrderRepository extends Mock implements ExchangeLimitOrders {}

void main() {
  late MockLimitOrderRepository repository;
  late CreateLimitOrderUsecase usecase;

  setUpAll(
    () => registerFallbackValue(
      LimitOrderDraft(
        limitPrice: 1,
        fiatAmount: 1,
        currency: FiatCurrency.cad,
        address: 'bc1qfallback',
      ),
    ),
  );

  LimitOrdersFailure failureOf(Result<LimitOrder, LimitOrdersFailure> r) =>
      (r as Err<LimitOrder, LimitOrdersFailure>).failure;

  void stubRate({double indexPrice = 100000}) {
    when(() => repository.getRate(any()))
        .thenAnswer((_) async => Ok(limitOrderRate(indexPrice: indexPrice)));
  }

  setUp(() {
    repository = MockLimitOrderRepository();
    usecase = CreateLimitOrderUsecase(repository);
  });

  test('rejects a blank address before the rate call', () async {
    final result = await usecase.execute(
      limitPrice: 90000,
      fiatAmount: 100,
      currency: FiatCurrency.cad,
      address: '   ',
    );

    expect(failureOf(result), isA<LimitOrderInvalidAddressFailure>());
    verifyZeroInteractions(repository);
  });

  test('rejects a non-positive amount', () async {
    final result = await usecase.execute(
      limitPrice: 90000,
      fiatAmount: 0,
      currency: FiatCurrency.cad,
      address: 'bc1qexample',
    );

    expect(failureOf(result), isA<LimitOrderInvalidAmountFailure>());
    verifyZeroInteractions(repository);
  });

  test(
    'allows an amount above the current balance (funded at execution)',
    () async {
      stubRate();
      when(() => repository.create(any()))
          .thenAnswer((_) async => Ok(limitOrder()));

      final result = await usecase.execute(
        limitPrice: 90000,
        fiatAmount: 1000000,
        currency: FiatCurrency.cad,
        address: 'bc1qexample',
      );

      expect(result, isA<Ok<LimitOrder, LimitOrdersFailure>>());
    },
  );

  test('rejects a target at or above the index price', () async {
    stubRate(indexPrice: 80000);

    final result = await usecase.execute(
      limitPrice: 90000,
      fiatAmount: 100,
      currency: FiatCurrency.cad,
      address: 'bc1qexample',
    );

    expect(failureOf(result), isA<LimitOrderInvalidTargetFailure>());
    verify(() => repository.getRate('CAD')).called(1);
    verifyNever(() => repository.create(any()));
  });

  test('creates the order with a trimmed address', () async {
    stubRate();
    when(() => repository.create(any()))
        .thenAnswer((_) async => Ok(limitOrder()));

    final result = await usecase.execute(
      limitPrice: 90000,
      fiatAmount: 100,
      currency: FiatCurrency.cad,
      address: '  bc1qexample  ',
    );

    expect(result, isA<Ok<LimitOrder, LimitOrdersFailure>>());
    final draft =
        verify(() => repository.create(captureAny())).captured.single
            as LimitOrderDraft;
    expect(draft.address, 'bc1qexample');
    expect(draft.currency, FiatCurrency.cad);
  });

  test('forwards a rate failure untouched', () async {
    when(() => repository.getRate(any())).thenAnswer(
      (_) async => const Err(
        ExchangeLimitOrderFailure(ExchangeLimitOrderProblem.load, 'rate'),
      ),
    );

    final result = await usecase.execute(
      limitPrice: 90000,
      fiatAmount: 100,
      currency: FiatCurrency.cad,
      address: 'bc1qexample',
    );

    expect(failureOf(result), isA<LimitOrdersLoadFailure>());
    verifyNever(() => repository.create(any()));
  });
}
