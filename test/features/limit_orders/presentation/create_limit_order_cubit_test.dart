import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order_creation_context.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order_rate.dart';
import 'package:bb_mobile/features/limit_orders/domain/limit_orders_failure.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/create_limit_order_usecase.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/get_limit_order_rate_usecase.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/load_limit_order_creation_usecase.dart';
import 'package:bb_mobile/features/limit_orders/presentation/create_limit_order_cubit.dart';
import 'package:bb_mobile/features/limit_orders/presentation/create_limit_order_state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../limit_order_fixtures.dart';

class MockLoadLimitOrderCreationUsecase extends Mock
    implements LoadLimitOrderCreationUsecase {}

class MockGetLimitOrderRateUsecase extends Mock
    implements GetLimitOrderRateUsecase {}

class MockCreateLimitOrderUsecase extends Mock
    implements CreateLimitOrderUsecase {}

void main() {
  late MockLoadLimitOrderCreationUsecase loadCreation;
  late MockGetLimitOrderRateUsecase getRate;
  late MockCreateLimitOrderUsecase create;

  final bitcoinWallet = LimitOrderWallet(
    type: LimitOrderWalletType.bitcoin,
    address: 'bc1qexample',
  );
  final creationContext = LimitOrderCreationContext(
    balances: [
      LimitOrderBalance(currency: FiatCurrency.cad, amount: 500),
      LimitOrderBalance(currency: FiatCurrency.usd, amount: 250),
    ],
    selectedCurrency: FiatCurrency.cad,
    rate: limitOrderRate(),
    wallets: [bitcoinWallet],
  );

  setUp(() {
    loadCreation = MockLoadLimitOrderCreationUsecase();
    getRate = MockGetLimitOrderRateUsecase();
    create = MockCreateLimitOrderUsecase();
  });

  CreateLimitOrderCubit buildCubit() =>
      CreateLimitOrderCubit(loadCreation, getRate, create);

  blocTest<CreateLimitOrderCubit, CreateLimitOrderState>(
    'loads the creation context and initializes the target',
    setUp: () => when(
      () => loadCreation.execute(),
    ).thenAnswer((_) async => Ok(creationContext)),
    build: buildCubit,
    act: (cubit) => cubit.load(),
    verify: (cubit) {
      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.currency, FiatCurrency.cad);
      expect(cubit.state.wallets, [bitcoinWallet]);
      expect(cubit.state.discount, 1);
      expect(cubit.state.limitPrice, 99000);
      expect(cubit.state.failure, isNull);
    },
  );

  blocTest<CreateLimitOrderCubit, CreateLimitOrderState>(
    'stores a typed failure when loading fails',
    setUp: () => when(
      () => loadCreation.execute(),
    ).thenAnswer((_) async => const Err(LimitOrdersLoadFailure('load failed'))),
    build: buildCubit,
    act: (cubit) => cubit.load(),
    verify: (cubit) {
      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.failure, isA<LimitOrdersLoadFailure>());
    },
  );

  blocTest<CreateLimitOrderCubit, CreateLimitOrderState>(
    'refreshes the rate after changing currency',
    setUp: () {
      when(
        () => loadCreation.execute(),
      ).thenAnswer((_) async => Ok(creationContext));
      when(() => getRate.execute('USD')).thenAnswer(
        (_) async => Ok(
          LimitOrderRate(
            currencyCode: 'USD',
            indexPrice: 80000,
            userPrice: 81000,
          ),
        ),
      );
    },
    build: buildCubit,
    act: (cubit) async {
      await cubit.load();
      await cubit.selectCurrency(FiatCurrency.usd);
    },
    verify: (cubit) {
      expect(cubit.state.currency, FiatCurrency.usd);
      expect(cubit.state.rate?.currencyCode, 'USD');
      expect(cubit.state.limitPrice, 79200);
      expect(cubit.state.discount, 1);
    },
  );

  blocTest<CreateLimitOrderCubit, CreateLimitOrderState>(
    'progresses through the form and creates an order',
    setUp: () {
      when(
        () => loadCreation.execute(),
      ).thenAnswer((_) async => Ok(creationContext));
      when(
        () => create.execute(
          limitPrice: 99000,
          fiatAmount: 100,
          currency: FiatCurrency.cad,
          address: bitcoinWallet.address,
        ),
      ).thenAnswer((_) async => Ok(limitOrder()));
    },
    build: buildCubit,
    act: (cubit) async {
      await cubit.load();
      cubit.continueFromIntro();
      cubit.continueFromTarget();
      cubit.setAmount(100);
      cubit.continueFromAmount();
      cubit.selectWallet(bitcoinWallet);
      cubit.continueFromWallet();
      await cubit.submit();
    },
    verify: (cubit) {
      expect(cubit.state.step, CreateLimitOrderStep.done);
      expect(cubit.state.createdOrder?.id, 'lo-1');
      expect(cubit.state.isSubmitting, isFalse);
      verify(
        () => create.execute(
          limitPrice: 99000,
          fiatAmount: 100,
          currency: FiatCurrency.cad,
          address: bitcoinWallet.address,
        ),
      ).called(1);
    },
  );

  blocTest<CreateLimitOrderCubit, CreateLimitOrderState>(
    'keeps the confirmation step when creation fails',
    setUp: () {
      when(
        () => loadCreation.execute(),
      ).thenAnswer((_) async => Ok(creationContext));
      when(
        () => create.execute(
          limitPrice: 99000,
          fiatAmount: 100,
          currency: FiatCurrency.cad,
          address: bitcoinWallet.address,
        ),
      ).thenAnswer(
        (_) async => const Err(LimitOrderCreationFailure('create failed')),
      );
    },
    build: buildCubit,
    act: (cubit) async {
      await cubit.load();
      cubit.continueFromIntro();
      cubit.continueFromTarget();
      cubit.setAmount(100);
      cubit.continueFromAmount();
      cubit.selectWallet(bitcoinWallet);
      cubit.continueFromWallet();
      await cubit.submit();
    },
    verify: (cubit) {
      expect(cubit.state.step, CreateLimitOrderStep.confirmation);
      expect(cubit.state.failure, isA<LimitOrderCreationFailure>());
      expect(cubit.state.isSubmitting, isFalse);
    },
  );
}
