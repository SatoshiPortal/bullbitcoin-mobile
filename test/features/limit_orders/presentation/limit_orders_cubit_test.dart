import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order.dart';
import 'package:bb_mobile/features/limit_orders/domain/limit_orders_failure.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/cancel_all_limit_orders_usecase.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/can_create_limit_order_usecase.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/list_active_limit_orders_usecase.dart';
import 'package:bb_mobile/features/limit_orders/presentation/limit_orders_cubit.dart';
import 'package:bb_mobile/features/limit_orders/presentation/limit_orders_state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../limit_order_fixtures.dart';

class MockListActiveLimitOrdersUsecase extends Mock
    implements ListActiveLimitOrdersUsecase {}

class MockCancelAllLimitOrdersUsecase extends Mock
    implements CancelAllLimitOrdersUsecase {}

void main() {
  late MockListActiveLimitOrdersUsecase listActive;
  late MockCancelAllLimitOrdersUsecase cancelAll;
  const canCreate = CanCreateLimitOrderUsecase();

  List<LimitOrder> orders(int count) =>
      List.generate(count, (i) => limitOrder(id: 'lo-$i'));

  setUp(() {
    listActive = MockListActiveLimitOrdersUsecase();
    cancelAll = MockCancelAllLimitOrdersUsecase();
  });

  blocTest<LimitOrdersCubit, LimitOrdersState>(
    'loads the active orders',
    setUp: () =>
        when(() => listActive.execute()).thenAnswer((_) async => Ok(orders(2))),
    build: () => LimitOrdersCubit(listActive, cancelAll, canCreate),
    act: (cubit) => cubit.load(),
    verify: (cubit) {
      expect(cubit.state.orders, hasLength(2));
      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.canCreate, isTrue);
    },
  );

  blocTest<LimitOrdersCubit, LimitOrdersState>(
    'refuses another order once the maximum is active',
    setUp: () => when(() => listActive.execute()).thenAnswer(
      (_) async => Ok(orders(CanCreateLimitOrderUsecase.maximumActiveOrders)),
    ),
    build: () => LimitOrdersCubit(listActive, cancelAll, canCreate),
    act: (cubit) => cubit.load(),
    verify: (cubit) => expect(cubit.state.canCreate, isFalse),
  );

  blocTest<LimitOrdersCubit, LimitOrdersState>(
    'stores a load failure without dropping the loading flag',
    setUp: () => when(
      () => listActive.execute(),
    ).thenAnswer((_) async => const Err(LimitOrdersLoadFailure('list'))),
    build: () => LimitOrdersCubit(listActive, cancelAll, canCreate),
    act: (cubit) => cubit.load(),
    verify: (cubit) {
      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.failure, isA<LimitOrdersLoadFailure>());
    },
  );

  blocTest<LimitOrdersCubit, LimitOrdersState>(
    'empties the list after cancelling every order',
    setUp: () {
      when(() => listActive.execute()).thenAnswer((_) async => Ok(orders(3)));
      when(() => cancelAll.execute()).thenAnswer((_) async => const Ok([]));
    },
    build: () => LimitOrdersCubit(listActive, cancelAll, canCreate),
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
      when(() => listActive.execute()).thenAnswer((_) async => Ok(orders(3)));
      when(() => cancelAll.execute()).thenAnswer(
        (_) async => const Err(LimitOrderCancellationFailure('cancel all')),
      );
    },
    build: () => LimitOrdersCubit(listActive, cancelAll, canCreate),
    act: (cubit) async {
      await cubit.load();
      await cubit.cancelAll();
    },
    verify: (cubit) {
      expect(cubit.state.orders, hasLength(3));
      expect(cubit.state.failure, isA<LimitOrderCancellationFailure>());
    },
  );
}
