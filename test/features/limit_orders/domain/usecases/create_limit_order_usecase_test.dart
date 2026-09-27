import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order_draft.dart';
import 'package:bb_mobile/features/limit_orders/domain/limit_orders_failure.dart';
import 'package:bb_mobile/features/limit_orders/domain/repositories/limit_order_repository.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/create_limit_order_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../limit_order_fixtures.dart';

class MockLimitOrderRepository extends Mock implements LimitOrderRepository {}

class MockGetExchangeUserSummaryUsecase extends Mock
    implements GetExchangeUserSummaryUsecase {}

void main() {
  late MockLimitOrderRepository repository;
  late MockGetExchangeUserSummaryUsecase getUserSummary;
  late CreateLimitOrderUsecase usecase;

  setUpAll(
    () => registerFallbackValue(
      LimitOrderDraft(
        limitPrice: 1,
        fiatAmount: 1,
        currencyCode: 'CAD',
        address: 'bc1qfallback',
      ),
    ),
  );

  LimitOrdersFailure failureOf(Result<LimitOrder, LimitOrdersFailure> r) =>
      (r as Err<LimitOrder, LimitOrdersFailure>).failure;

  void stubRate({double indexPrice = 100000}) {
    when(
      () => repository.getRate(any()),
    ).thenAnswer((_) async => Ok(limitOrderRate(indexPrice: indexPrice)));
  }

  setUp(() {
    repository = MockLimitOrderRepository();
    getUserSummary = MockGetExchangeUserSummaryUsecase();
    usecase = CreateLimitOrderUsecase(repository, getUserSummary);
  });

  test('rejects a blank address without calling the account', () async {
    final result = await usecase.execute(
      limitPrice: 90000,
      fiatAmount: 100,
      currency: FiatCurrency.cad,
      address: '   ',
    );

    expect(failureOf(result), isA<LimitOrderInvalidAddressFailure>());
    verifyZeroInteractions(getUserSummary);
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
    verifyZeroInteractions(getUserSummary);
  });

  test('reads the current balance rather than trusting the caller', () async {
    when(() => getUserSummary.execute()).thenAnswer(
      (_) async => userSummary(
        balances: const [UserBalance(amount: 50, currencyCode: 'CAD')],
      ),
    );

    final result = await usecase.execute(
      limitPrice: 90000,
      fiatAmount: 100,
      currency: FiatCurrency.cad,
      address: 'bc1qexample',
    );

    expect(failureOf(result), isA<LimitOrderInvalidAmountFailure>());
    verify(() => getUserSummary.execute()).called(1);
    verifyNever(() => repository.create(any()));
  });

  test('sums every balance held in the selected currency', () async {
    when(() => getUserSummary.execute()).thenAnswer(
      (_) async => userSummary(
        balances: const [
          UserBalance(amount: 60, currencyCode: 'CAD'),
          UserBalance(amount: 60, currencyCode: 'CAD'),
          UserBalance(amount: 900, currencyCode: 'USD'),
        ],
      ),
    );
    stubRate();
    when(
      () => repository.create(any()),
    ).thenAnswer((_) async => Ok(limitOrder()));

    final result = await usecase.execute(
      limitPrice: 90000,
      fiatAmount: 100,
      currency: FiatCurrency.cad,
      address: 'bc1qexample',
    );

    expect(result, isA<Ok<LimitOrder, LimitOrdersFailure>>());
  });

  test('reads the live rate rather than trusting the caller', () async {
    when(() => getUserSummary.execute()).thenAnswer((_) async => userSummary());
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

  test('rejects a target at the index price', () async {
    when(() => getUserSummary.execute()).thenAnswer((_) async => userSummary());
    stubRate();

    final result = await usecase.execute(
      limitPrice: 100000,
      fiatAmount: 100,
      currency: FiatCurrency.cad,
      address: 'bc1qexample',
    );

    expect(failureOf(result), isA<LimitOrderInvalidTargetFailure>());
  });

  test('creates the order with a trimmed address', () async {
    when(() => getUserSummary.execute()).thenAnswer((_) async => userSummary());
    stubRate();
    when(
      () => repository.create(any()),
    ).thenAnswer((_) async => Ok(limitOrder()));

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
    expect(draft.currencyCode, 'CAD');
  });

  test('forwards a rate failure untouched', () async {
    when(() => getUserSummary.execute()).thenAnswer((_) async => userSummary());
    when(
      () => repository.getRate(any()),
    ).thenAnswer((_) async => const Err(LimitOrdersLoadFailure('rate')));

    final result = await usecase.execute(
      limitPrice: 90000,
      fiatAmount: 100,
      currency: FiatCurrency.cad,
      address: 'bc1qexample',
    );

    expect(failureOf(result), isA<LimitOrdersLoadFailure>());
    verifyNever(() => repository.create(any()));
  });

  test('maps an unavailable account to a typed failure', () async {
    when(
      () => getUserSummary.execute(),
    ).thenThrow(GetExchangeUserSummaryException('account request failed'));

    final result = await usecase.execute(
      limitPrice: 90000,
      fiatAmount: 100,
      currency: FiatCurrency.cad,
      address: 'bc1qexample',
    );

    expect(failureOf(result), isA<LimitOrdersAccountUnavailableFailure>());
  });

  test('maps an unclassified account error to the catch-all', () async {
    when(
      () => getUserSummary.execute(),
    ).thenThrow(Exception('something nobody classified'));

    final result = await usecase.execute(
      limitPrice: 90000,
      fiatAmount: 100,
      currency: FiatCurrency.cad,
      address: 'bc1qexample',
    );

    expect(failureOf(result), isA<LimitOrdersUnexpectedFailure>());
  });

  test('does not convert programmer errors into recoverable failures', () {
    when(() => getUserSummary.execute()).thenThrow(StateError('bug'));

    expect(
      () => usecase.execute(
        limitPrice: 90000,
        fiatAmount: 100,
        currency: FiatCurrency.cad,
        address: 'bc1qexample',
      ),
      throwsStateError,
    );
  });
}
