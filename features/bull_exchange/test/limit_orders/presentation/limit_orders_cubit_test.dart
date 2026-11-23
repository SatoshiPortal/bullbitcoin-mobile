import 'dart:async';

import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';
import 'package:bull_exchange/src/limit_orders/domain/usecases/can_create_limit_order_usecase.dart';
import 'package:bull_exchange/src/limit_orders/presentation/limit_orders_cubit.dart';
import 'package:bull_exchange/src/limit_orders/presentation/limit_orders_state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../limit_order_fixtures.dart';

class _Orders extends Mock implements ExchangeLimitOrders {}

void main() {
  late _Orders exchangeOrders;
  late StreamController<Result<NotificationMessage, ExchangeFailure>>
  notificationStream;
  const canCreate = CanCreateLimitOrderUsecase();

  List<LimitOrder> orders(int count) =>
      List.generate(count, (i) => limitOrder(id: 'lo-$i'));

  setUp(() {
    exchangeOrders = _Orders();
    notificationStream =
        StreamController<
          Result<NotificationMessage, ExchangeFailure>
        >.broadcast();
  });

  tearDown(() => notificationStream.close());

  LimitOrdersCubit buildCubit() =>
      LimitOrdersCubit(exchangeOrders, canCreate, notificationStream.stream);

  blocTest<LimitOrdersCubit, LimitOrdersState>(
    'loads the active orders',
    setUp: () =>
        when(() => exchangeOrders.listActive())
            .thenAnswer((_) async => Ok(orders(2))),
    build: buildCubit,
    act: (cubit) => cubit.load(),
    verify: (cubit) {
      expect(cubit.state.orders, hasLength(2));
      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.canCreate, isTrue);
    },
  );

  blocTest<LimitOrdersCubit, LimitOrdersState>(
    'refuses another order once the maximum is active',
    setUp: () => when(() => exchangeOrders.listActive()).thenAnswer(
      (_) async => Ok(orders(CanCreateLimitOrderUsecase.maximumActiveOrders)),
    ),
    build: buildCubit,
    act: (cubit) => cubit.load(),
    verify: (cubit) => expect(cubit.state.canCreate, isFalse),
  );

  blocTest<LimitOrdersCubit, LimitOrdersState>(
    'stores a load failure without dropping the loading flag',
    setUp: () => when(() => exchangeOrders.listActive()).thenAnswer(
      (_) async =>
          const Err(ExchangeLimitOrderFailure(ExchangeLimitOrderProblem.load)),
    ),
    build: buildCubit,
    act: (cubit) => cubit.load(),
    verify: (cubit) {
      expect(cubit.state.isLoading, isFalse);
      expect(
        cubit.state.failure,
        isA<ExchangeLimitOrderFailure>().having(
          (value) => value.problem,
          'problem',
          ExchangeLimitOrderProblem.load,
        ),
      );
    },
  );

  blocTest<LimitOrdersCubit, LimitOrdersState>(
    'empties the list after cancelling every order',
    setUp: () {
      when(() => exchangeOrders.listActive())
          .thenAnswer((_) async => Ok(orders(3)));
      when(() => exchangeOrders.cancelAll())
          .thenAnswer((_) async => const Ok([]));
    },
    build: buildCubit,
    act: (cubit) async {
      await cubit.load();
      await cubit.cancelAll();
    },
    verify: (cubit) {
      expect(cubit.state.orders, isEmpty);
      expect(cubit.state.canCreate, isTrue);
      expect(cubit.state.isCancellingAll, isFalse);
    },
  );

  blocTest<LimitOrdersCubit, LimitOrdersState>(
    'keeps the orders when cancelling them all fails',
    setUp: () {
      when(() => exchangeOrders.listActive())
          .thenAnswer((_) async => Ok(orders(3)));
      when(() => exchangeOrders.cancelAll()).thenAnswer(
        (_) async => const Err(
          ExchangeLimitOrderFailure(ExchangeLimitOrderProblem.cancel),
        ),
      );
    },
    build: buildCubit,
    act: (cubit) async {
      await cubit.load();
      await cubit.cancelAll();
    },
    verify: (cubit) {
      expect(cubit.state.orders, hasLength(3));
      expect(
        cubit.state.failure,
        isA<ExchangeLimitOrderFailure>().having(
          (value) => value.problem,
          'problem',
          ExchangeLimitOrderProblem.cancel,
        ),
      );
    },
  );

  blocTest<LimitOrdersCubit, LimitOrdersState>(
    'reloads when a limit-order notification arrives',
    setUp: () =>
        when(() => exchangeOrders.listActive())
            .thenAnswer((_) async => Ok(orders(1))),
    build: buildCubit,
    act: (cubit) async {
      notificationStream.add(
        const Ok(NotificationMessage(kind: NotificationMessageKind.limitOrder)),
      );
      await Future<void>.delayed(Duration.zero);
    },
    verify: (cubit) {
      verify(() => exchangeOrders.listActive()).called(1);
      expect(cubit.state.orders, hasLength(1));
    },
  );

  blocTest<LimitOrdersCubit, LimitOrdersState>(
    'ignores notifications that are not limit-order events',
    build: buildCubit,
    act: (cubit) async {
      notificationStream.add(
        const Ok(NotificationMessage(kind: NotificationMessageKind.balance)),
      );
      await Future<void>.delayed(Duration.zero);
    },
    verify: (_) => verifyNever(() => exchangeOrders.listActive()),
  );

  final refreshRequests = StreamController<void>.broadcast();
  tearDownAll(refreshRequests.close);

  blocTest<LimitOrdersCubit, LimitOrdersState>(
    'reloads when the host screen requests a refresh',
    setUp: () =>
        when(() => exchangeOrders.listActive())
            .thenAnswer((_) async => Ok(orders(1))),
    build: () => LimitOrdersCubit(
      exchangeOrders,
      canCreate,
      notificationStream.stream,
      refreshRequests: refreshRequests.stream,
    ),
    act: (cubit) async {
      refreshRequests.add(null);
      await Future<void>.delayed(Duration.zero);
    },
    verify: (cubit) {
      verify(() => exchangeOrders.listActive()).called(1);
      expect(cubit.state.orders, hasLength(1));
    },
  );
}
