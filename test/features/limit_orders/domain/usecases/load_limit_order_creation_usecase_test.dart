import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/default_wallets/public/default_wallets_facade.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order_creation_context.dart';
import 'package:bb_mobile/features/limit_orders/domain/limit_orders_failure.dart';
import 'package:bb_mobile/features/limit_orders/domain/repositories/limit_order_repository.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/load_limit_order_creation_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../limit_order_fixtures.dart';

class MockLimitOrderRepository extends Mock implements LimitOrderRepository {}

class MockGetExchangeUserSummaryUsecase extends Mock
    implements GetExchangeUserSummaryUsecase {}

class MockDefaultWalletsFacade extends Mock implements DefaultWalletsFacade {}

class MockGetWalletsUsecase extends Mock implements GetWalletsUsecase {}

class _MockWallet extends Mock implements Wallet {}

Wallet _wallet(String id, Network network) {
  final wallet = _MockWallet();
  when(() => wallet.id).thenReturn(id);
  when(() => wallet.network).thenReturn(network);
  return wallet;
}

const _wallets = DefaultWallets(
  bitcoin: DefaultWallet(
    recipientId: 'r1',
    walletType: WalletAddressType.bitcoin,
    address: 'bc1qexample',
    isDefault: true,
  ),
  liquid: DefaultWallet(
    recipientId: 'r2',
    walletType: WalletAddressType.liquid,
    address: 'lq1qexample',
    isDefault: true,
  ),
);

void main() {
  late MockLimitOrderRepository repository;
  late MockGetExchangeUserSummaryUsecase getUserSummary;
  late MockDefaultWalletsFacade defaultWallets;
  late MockGetWalletsUsecase getWallets;
  late LoadLimitOrderCreationUsecase usecase;

  LimitOrdersFailure failureOf(
    Result<LimitOrderCreationContext, LimitOrdersFailure> r,
  ) => (r as Err<LimitOrderCreationContext, LimitOrdersFailure>).failure;

  LimitOrderCreationContext valueOf(
    Result<LimitOrderCreationContext, LimitOrdersFailure> r,
  ) => (r as Ok<LimitOrderCreationContext, LimitOrdersFailure>).value;

  setUp(() {
    repository = MockLimitOrderRepository();
    getUserSummary = MockGetExchangeUserSummaryUsecase();
    defaultWallets = MockDefaultWalletsFacade();
    getWallets = MockGetWalletsUsecase();
    usecase = LoadLimitOrderCreationUsecase(
      getUserSummary,
      defaultWallets,
      getWallets,
      repository,
    );
    when(
      () => repository.getRate(any()),
    ).thenAnswer((_) async => Ok(limitOrderRate()));
    when(
      () => defaultWallets.getDefaultWallets(),
    ).thenAnswer((_) async => _wallets);
    when(() => getWallets.execute()).thenAnswer((_) async => Ok([]));
  });

  test(
    'includes the in-app bitcoin and liquid wallets in the context',
    () async {
      when(
        () => getUserSummary.execute(),
      ).thenAnswer((_) async => userSummary());
      when(() => getWallets.execute()).thenAnswer(
        (_) async => Ok([
          _wallet('w-btc', Network.bitcoinMainnet),
          _wallet('w-lbtc', Network.liquidMainnet),
        ]),
      );

      final result = await usecase.execute();

      final ids = valueOf(result).appWallets.map((w) => w.id).toList();
      expect(ids, ['w-btc', 'w-lbtc']);
    },
  );

  test('degrades to no in-app wallets when listing them fails', () async {
    when(() => getUserSummary.execute()).thenAnswer((_) async => userSummary());
    when(() => getWallets.execute()).thenThrow(Exception('no wallets'));

    final result = await usecase.execute();

    expect(valueOf(result).appWallets, isEmpty);
  });

  test('drops zero balances and refuses an unfunded account', () async {
    when(() => getUserSummary.execute()).thenAnswer(
      (_) async => userSummary(
        balances: const [UserBalance(amount: 0, currencyCode: 'CAD')],
      ),
    );

    final result = await usecase.execute();

    expect(failureOf(result), isA<LimitOrdersAccountUnavailableFailure>());
    verifyZeroInteractions(repository);
  });

  test('prefers the account currency when it holds a balance', () async {
    when(() => getUserSummary.execute()).thenAnswer(
      (_) async => userSummary(
        balances: const [
          UserBalance(amount: 10, currencyCode: 'USD'),
          UserBalance(amount: 20, currencyCode: 'CAD'),
        ],
        currency: 'CAD',
      ),
    );

    final context = valueOf(await usecase.execute());

    expect(context.selectedCurrency, FiatCurrency.cad);
    verify(() => repository.getRate('CAD')).called(1);
  });

  test('falls back to the first funded balance', () async {
    when(() => getUserSummary.execute()).thenAnswer(
      (_) async => userSummary(
        balances: const [UserBalance(amount: 10, currencyCode: 'USD')],
        currency: 'CAD',
      ),
    );

    final context = valueOf(await usecase.execute());

    expect(context.selectedCurrency, FiatCurrency.usd);
  });

  test('maps only the configured default wallets', () async {
    when(() => getUserSummary.execute()).thenAnswer((_) async => userSummary());

    final context = valueOf(await usecase.execute());

    expect(context.wallets.map((wallet) => wallet.type), [
      LimitOrderWalletType.bitcoin,
      LimitOrderWalletType.liquid,
    ]);
  });

  test('forwards a rate failure untouched', () async {
    when(() => getUserSummary.execute()).thenAnswer((_) async => userSummary());
    when(
      () => repository.getRate(any()),
    ).thenAnswer((_) async => const Err(LimitOrdersLoadFailure('rate')));

    expect(failureOf(await usecase.execute()), isA<LimitOrdersLoadFailure>());
  });

  test('maps an unavailable account to a typed failure', () async {
    when(
      () => getUserSummary.execute(),
    ).thenThrow(GetExchangeUserSummaryException('account request failed'));

    expect(
      failureOf(await usecase.execute()),
      isA<LimitOrdersAccountUnavailableFailure>(),
    );
  });

  test('maps an unreadable default wallet list to the catch-all', () async {
    when(() => getUserSummary.execute()).thenAnswer((_) async => userSummary());
    when(
      () => defaultWallets.getDefaultWallets(),
    ).thenThrow(Exception('recipient request failed'));

    expect(
      failureOf(await usecase.execute()),
      isA<LimitOrdersUnexpectedFailure>(),
    );
  });

  test('does not convert programmer errors into recoverable failures', () {
    when(() => getUserSummary.execute()).thenThrow(StateError('bug'));

    expect(() => usecase.execute(), throwsStateError);
  });
}
