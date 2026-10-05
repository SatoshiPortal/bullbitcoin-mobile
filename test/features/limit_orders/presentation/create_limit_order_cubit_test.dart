import 'dart:async';

import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order_amount_limits.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order_creation_context.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order_rate.dart';
import 'package:bb_mobile/features/limit_orders/domain/limit_orders_failure.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/create_limit_order_usecase.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/get_limit_order_rate_usecase.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/load_limit_order_creation_usecase.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/resolve_wallet_address_usecase.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/validate_lightning_address_usecase.dart';
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

class MockResolveWalletAddressUsecase extends Mock
    implements ResolveWalletAddressUsecase {}

class MockValidateLightningAddressUsecase extends Mock
    implements ValidateLightningAddressUsecase {}

class _MockWallet extends Mock implements Wallet {}

void main() {
  late MockLoadLimitOrderCreationUsecase loadCreation;
  late MockGetLimitOrderRateUsecase getRate;
  late MockCreateLimitOrderUsecase create;
  late MockResolveWalletAddressUsecase resolveAddress;
  late MockValidateLightningAddressUsecase validateLnAddress;

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
    resolveAddress = MockResolveWalletAddressUsecase();
    validateLnAddress = MockValidateLightningAddressUsecase();
  });

  CreateLimitOrderCubit buildCubit() => CreateLimitOrderCubit(
    loadCreation,
    getRate,
    create,
    resolveAddress,
    validateLnAddress,
  );

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
    'setting the limit price recomputes the discount',
    setUp: () => when(
      () => loadCreation.execute(),
    ).thenAnswer((_) async => Ok(creationContext)),
    build: buildCubit,
    act: (cubit) async {
      await cubit.load();
      cubit.setLimitPrice(90000);
    },
    verify: (cubit) {
      expect(cubit.state.limitPrice, closeTo(90000, 1e-6));
      expect(cubit.state.discount, closeTo(10, 1e-6));
    },
  );

  blocTest<CreateLimitOrderCubit, CreateLimitOrderState>(
    'setting the discount recomputes the limit price',
    setUp: () => when(
      () => loadCreation.execute(),
    ).thenAnswer((_) async => Ok(creationContext)),
    build: buildCubit,
    act: (cubit) async {
      await cubit.load();
      cubit.setDiscount(25);
    },
    verify: (cubit) {
      expect(cubit.state.discount, 25);
      expect(cubit.state.limitPrice, closeTo(75000, 1e-6));
    },
  );

  blocTest<CreateLimitOrderCubit, CreateLimitOrderState>(
    'flags an amount below the on-chain minimum for a bitcoin destination',
    setUp: () => when(
      () => loadCreation.execute(),
    ).thenAnswer((_) async => Ok(creationContext)),
    build: buildCubit,
    act: (cubit) async {
      await cubit.load();
      cubit.setAmount(1);
      cubit.selectWallet(bitcoinWallet);
    },
    verify: (cubit) {
      final violation = cubit.state.amountLimitViolation;
      expect(violation, isNotNull);
      expect(violation!.kind, LimitOrderAmountViolationKind.belowMinimum);
    },
  );

  blocTest<CreateLimitOrderCubit, CreateLimitOrderState>(
    'does not leave the wallet step while an amount violates a limit',
    setUp: () => when(
      () => loadCreation.execute(),
    ).thenAnswer((_) async => Ok(creationContext)),
    build: buildCubit,
    act: (cubit) async {
      await cubit.load();
      cubit.setAmount(1);
      cubit.selectWallet(bitcoinWallet);
      cubit.continueFromWallet();
    },
    verify: (cubit) {
      expect(cubit.state.step, isNot(CreateLimitOrderStep.confirmation));
      expect(cubit.state.amountLimitViolation, isNotNull);
    },
  );

  blocTest<CreateLimitOrderCubit, CreateLimitOrderState>(
    'clears the violation for an in-range amount',
    setUp: () => when(
      () => loadCreation.execute(),
    ).thenAnswer((_) async => Ok(creationContext)),
    build: buildCubit,
    act: (cubit) async {
      await cubit.load();
      cubit.setAmount(200);
      cubit.selectWallet(bitcoinWallet);
    },
    verify: (cubit) {
      expect(cubit.state.amountLimitViolation, isNull);
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

  Wallet appWallet(String id, Network network) {
    final wallet = _MockWallet();
    when(() => wallet.id).thenReturn(id);
    when(() => wallet.network).thenReturn(network);
    return wallet;
  }

  for (final fails in [false, true]) {
    test('keeps the confirmed default destination after a stale app-wallet '
        '${fails ? 'failure' : 'success'}', () async {
      final pending = Completer<Result<String, LimitOrdersFailure>>();
      when(
        () => loadCreation.execute(),
      ).thenAnswer((_) async => Ok(creationContext));
      when(
        () => resolveAddress.execute('w-btc'),
      ).thenAnswer((_) => pending.future);
      when(
        () => create.execute(
          limitPrice: 99000,
          fiatAmount: 100,
          currency: FiatCurrency.cad,
          address: bitcoinWallet.address,
        ),
      ).thenAnswer((_) async => Ok(limitOrder()));
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.load();
      cubit.setAmount(100);
      cubit.continueFromAmount();
      final resolving = cubit.selectAppWallet(
        appWallet('w-btc', Network.bitcoinMainnet),
      );
      cubit.selectWallet(bitcoinWallet);
      cubit.continueFromWallet();
      expect(cubit.state.step, CreateLimitOrderStep.confirmation);
      pending.complete(
        fails
            ? const Err(LimitOrdersUnexpectedFailure('stale failure'))
            : const Ok('bc1qstale'),
      );
      await resolving;
      expect(cubit.state.wallet, bitcoinWallet);
      expect(cubit.state.selectedAppWalletId, isNull);
      expect(cubit.state.isResolvingAddress, isFalse);
      expect(cubit.state.failure, isNull);
      await cubit.submit();
      verify(
        () => create.execute(
          limitPrice: 99000,
          fiatAmount: 100,
          currency: FiatCurrency.cad,
          address: bitcoinWallet.address,
        ),
      ).called(1);
    });
  }

  for (final staleAddress in ['old@example.com', null]) {
    test('keeps a default wallet after stale Lightning validation '
        'returns $staleAddress', () async {
      final pending = Completer<String?>();
      when(
        () => validateLnAddress.execute('old@example.com'),
      ).thenAnswer((_) => pending.future);
      final cubit = buildCubit();
      addTearDown(cubit.close);
      final validating = cubit.setLightningAddress('old@example.com');
      cubit.selectWallet(bitcoinWallet);
      pending.complete(staleAddress);
      await validating;
      expect(cubit.state.wallet, bitcoinWallet);
      expect(cubit.state.isResolvingAddress, isFalse);
      expect(cubit.state.lightningAddressInvalid, isFalse);
    });
  }

  test('a stale app-wallet result does not finish the latest Lightning '
      'validation', () async {
    final pendingWallet = Completer<Result<String, LimitOrdersFailure>>();
    final pendingLightning = Completer<String?>();
    when(
      () => resolveAddress.execute('w-btc'),
    ).thenAnswer((_) => pendingWallet.future);
    when(
      () => validateLnAddress.execute('new@example.com'),
    ).thenAnswer((_) => pendingLightning.future);
    final cubit = buildCubit();
    addTearDown(cubit.close);
    final resolving = cubit.selectAppWallet(
      appWallet('w-btc', Network.bitcoinMainnet),
    );
    final validating = cubit.setLightningAddress('new@example.com');
    pendingWallet.complete(const Ok('bc1qstale'));
    await resolving;
    expect(cubit.state.wallet, isNull);
    expect(cubit.state.isResolvingAddress, isTrue);
    pendingLightning.complete('new@example.com');
    await validating;
    expect(cubit.state.wallet?.address, 'new@example.com');
    expect(cubit.state.isResolvingAddress, isFalse);
  });

  test('keeps the latest Lightning address when validations finish '
      'out of order', () async {
    final pending = Completer<String?>();
    when(
      () => validateLnAddress.execute('old@example.com'),
    ).thenAnswer((_) => pending.future);
    when(
      () => validateLnAddress.execute('new@example.com'),
    ).thenAnswer((_) async => 'new@example.com');
    final cubit = buildCubit();
    addTearDown(cubit.close);
    final oldValidation = cubit.setLightningAddress('old@example.com');
    await cubit.setLightningAddress('new@example.com');
    pending.complete('old@example.com');
    await oldValidation;
    expect(cubit.state.wallet?.address, 'new@example.com');
    expect(cubit.state.lightningAddressInput, 'new@example.com');
    expect(cubit.state.isResolvingAddress, isFalse);
  });

  blocTest<CreateLimitOrderCubit, CreateLimitOrderState>(
    'selectAppWallet derives a receive address and sets the destination',
    setUp: () => when(
      () => resolveAddress.execute('w-btc'),
    ).thenAnswer((_) async => const Ok('bc1qderived')),
    build: buildCubit,
    act: (cubit) =>
        cubit.selectAppWallet(appWallet('w-btc', Network.bitcoinMainnet)),
    verify: (cubit) {
      expect(cubit.state.isResolvingAddress, isFalse);
      expect(cubit.state.selectedAppWalletId, 'w-btc');
      expect(cubit.state.wallet?.type, LimitOrderWalletType.bitcoin);
      expect(cubit.state.wallet?.address, 'bc1qderived');
    },
  );

  blocTest<CreateLimitOrderCubit, CreateLimitOrderState>(
    'selectAppWallet surfaces a derive failure and clears the selection',
    setUp: () => when(
      () => resolveAddress.execute('w-lbtc'),
    ).thenAnswer((_) async => const Err(LimitOrdersUnexpectedFailure('boom'))),
    build: buildCubit,
    act: (cubit) =>
        cubit.selectAppWallet(appWallet('w-lbtc', Network.liquidMainnet)),
    verify: (cubit) {
      expect(cubit.state.isResolvingAddress, isFalse);
      expect(cubit.state.wallet, isNull);
      expect(cubit.state.selectedAppWalletId, isNull);
      expect(cubit.state.failure, isA<LimitOrdersUnexpectedFailure>());
    },
  );

  blocTest<CreateLimitOrderCubit, CreateLimitOrderState>(
    'accepts a valid lightning address as the destination',
    setUp: () => when(
      () => validateLnAddress.execute('sats@bullbitcoin.com'),
    ).thenAnswer((_) async => 'sats@bullbitcoin.com'),
    build: buildCubit,
    act: (cubit) => cubit.setLightningAddress('sats@bullbitcoin.com'),
    verify: (cubit) {
      expect(cubit.state.lightningAddressInvalid, isFalse);
      expect(cubit.state.wallet?.type, LimitOrderWalletType.lightning);
      expect(cubit.state.wallet?.address, 'sats@bullbitcoin.com');
    },
  );

  blocTest<CreateLimitOrderCubit, CreateLimitOrderState>(
    'rejects an invoice or otherwise invalid lightning address',
    setUp: () => when(
      () => validateLnAddress.execute(any()),
    ).thenAnswer((_) async => null),
    build: buildCubit,
    act: (cubit) => cubit.setLightningAddress('lnbc1invoice'),
    verify: (cubit) {
      expect(cubit.state.lightningAddressInvalid, isTrue);
      expect(cubit.state.wallet, isNull);
    },
  );
}
