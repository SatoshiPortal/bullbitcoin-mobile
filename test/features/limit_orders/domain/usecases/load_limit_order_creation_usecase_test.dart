import 'dart:async';

import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:primitives/primitives.dart'
    show Network, BitcoinNetwork, LiquidNetwork, Err, Ok, Result;
import 'package:preferences/preferences.dart'
    show ActiveEnvironmentReader, Environment;
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order_creation_context.dart';
import 'package:bb_mobile/features/limit_orders/domain/limit_orders_failure.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/load_limit_order_creation_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../limit_order_fixtures.dart';

class MockLimitOrderRepository extends Mock implements ExchangeLimitOrders {}

class MockGetExchangeUserSummaryUsecase extends Mock
    implements GetExchangeUserSummaryUsecase {}

abstract interface class _DefaultWalletReader {
  Future<Result<DefaultWallets, ExchangeFailure>> getDefaultWallets();
}

class MockDefaultWalletReader extends Mock implements _DefaultWalletReader {}

class _Inventory extends Mock implements WalletInventory {}

class _Environment extends Mock implements ActiveEnvironmentReader {}

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
  late MockDefaultWalletReader defaultWallets;
  late _Inventory inventory;
  late _Environment environment;
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
    defaultWallets = MockDefaultWalletReader();
    inventory = _Inventory();
    environment = _Environment();
    usecase = LoadLimitOrderCreationUsecase(
      getUserSummary,
      exchangeForTesting(getDefaultWallets: defaultWallets.getDefaultWallets),
      inventory,
      environment,
      repository,
    );
    when(() => repository.getRate(any()))
        .thenAnswer((_) async => Ok(limitOrderRate()));
    when(() => defaultWallets.getDefaultWallets())
        .thenAnswer((_) async => const Ok(_wallets));
    when(environment.readActiveEnvironment)
        .thenAnswer((_) async => const Ok(Environment.mainnet));
    for (final network in <Network>[
      BitcoinNetwork.mainnet,
      LiquidNetwork.mainnet,
    ]) {
      when(() => inventory.walletsForNetwork(network))
          .thenAnswer((_) async => Ok(walletSelectionForTesting([])));
    }
  });

  test(
    'includes the in-app bitcoin and liquid wallets in the context',
    () async {
      when(() => getUserSummary.execute())
          .thenAnswer((_) async => userSummary());
      when(() => inventory.walletsForNetwork(BitcoinNetwork.mainnet))
          .thenAnswer(
            (_) async => Ok(
              walletSelectionForTesting([
                walletRegistrationForTesting(
                  id: 'w-btc',
                  network: BitcoinNetwork.mainnet,
                ),
              ]),
            ),
          );
      when(() => inventory.walletsForNetwork(LiquidNetwork.mainnet)).thenAnswer(
        (_) async => Ok(
          walletSelectionForTesting([
            walletRegistrationForTesting(
              id: 'w-lbtc',
              network: LiquidNetwork.mainnet,
            ),
          ]),
        ),
      );

      final result = await usecase.execute();

      final ids = valueOf(result).appWallets.map((w) => w.id).toList();
      expect(ids, ['w-btc', 'w-lbtc']);
    },
  );

  test('degrades to no in-app wallets when listing them fails', () async {
    when(() => getUserSummary.execute()).thenAnswer((_) async => userSummary());
    when(() => inventory.walletsForNetwork(BitcoinNetwork.mainnet))
        .thenAnswer((_) async => const Err(FetchSecretFailure()));

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

    expect(failureOf(result), isA<LimitOrdersNoFundedBalanceFailure>());
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
    when(() => repository.getRate(any())).thenAnswer(
      (_) async => const Err(
        ExchangeLimitOrderFailure(ExchangeLimitOrderProblem.load, 'rate'),
      ),
    );

    expect(failureOf(await usecase.execute()), isA<LimitOrdersLoadFailure>());
  });

  test('maps an unavailable account to a typed failure', () async {
    when(() => getUserSummary.execute())
        .thenThrow(GetExchangeUserSummaryException('account request failed'));

    expect(
      failureOf(await usecase.execute()),
      isA<LimitOrdersAccountUnavailableFailure>(),
    );
  });

  test('maps an unreadable default wallet list to the catch-all', () async {
    when(() => getUserSummary.execute()).thenAnswer((_) async => userSummary());
    when(() => defaultWallets.getDefaultWallets())
        .thenAnswer((_) async => const Err(ExchangeNetworkFailure()));

    expect(
      failureOf(await usecase.execute()),
      isA<LimitOrdersUnexpectedFailure>(),
    );
  });

  test('fetches default and app wallets concurrently with the user summary, and the rate after it', () async {
    final summary = Completer<UserSummary>();
    when(() => getUserSummary.execute()).thenAnswer((_) => summary.future);

    final result = usecase.execute();
    await Future<void>.delayed(Duration.zero);

    verify(() => defaultWallets.getDefaultWallets()).called(1);
    verify(() => inventory.walletsForNetwork(BitcoinNetwork.mainnet)).called(1);
    verifyNever(() => repository.getRate(any()));

    summary.complete(userSummary());
    expect(
      await result,
      isA<Ok<LimitOrderCreationContext, LimitOrdersFailure>>(),
    );
  });

  test('does not convert programmer errors into recoverable failures', () {
    when(() => getUserSummary.execute()).thenThrow(StateError('bug'));

    expect(() => usecase.execute(), throwsStateError);
  });
}
