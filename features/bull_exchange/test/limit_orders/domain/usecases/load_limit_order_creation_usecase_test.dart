import 'dart:async';

import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:primitives/primitives.dart'
    show BitcoinNetwork, LiquidNetwork, Network, Err, Ok, Result;
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:sync/write.dart';
import 'package:preferences/preferences.dart';
import 'package:bull_exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../limit_order_fixtures.dart';

class MockLimitOrderRepository extends Mock implements ExchangeLimitOrders {}

abstract interface class _ExchangeReads {
  Future<Result<DefaultWallets, ExchangeFailure>> getDefaultWallets();
  Future<Result<UserSummary, ExchangeFailure>> getUserSummary(
    ExchangeEnvironment? environment,
  );
}

class _MockExchangeReads extends Mock implements _ExchangeReads {}

class _MockInventory extends Mock implements WalletInventory {}

class _MockNative extends Mock implements WalletNativeLifecycle {}

class _MockPreferences extends Mock implements Preferences {}

class _MockSettings extends Mock implements SettingsEntity {}

WalletRegistration _wallet(String id, Network network) =>
    walletRegistrationForTesting(id: id, network: network);

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
  late _MockExchangeReads exchangeReads;
  late _MockInventory inventory;
  late _MockSettings settings;
  late LoadLimitOrderCreationUsecase usecase;

  LimitOrdersFailure failureOf(
    Result<LimitOrderCreationContext, LimitOrdersFailure> r,
  ) => (r as Err<LimitOrderCreationContext, LimitOrdersFailure>).failure;

  LimitOrderCreationContext valueOf(
    Result<LimitOrderCreationContext, LimitOrdersFailure> r,
  ) => (r as Ok<LimitOrderCreationContext, LimitOrdersFailure>).value;

  setUp(() {
    repository = MockLimitOrderRepository();
    exchangeReads = _MockExchangeReads();
    inventory = _MockInventory();
    final preferences = _MockPreferences();
    settings = _MockSettings();
    when(() => settings.environment).thenReturn(Environment.mainnet);
    when(() => preferences.fetch()).thenAnswer((_) async => Ok(settings));
    usecase = LoadLimitOrderCreationUsecase(
      exchangeForTesting(
        getDefaultWallets: exchangeReads.getDefaultWallets,
        getUserSummary: exchangeReads.getUserSummary,
      ),
      preferences,
      ExchangePayoutWallets(inventory, _MockNative()),
      repository,
    );
    when(() => repository.getRate(any()))
        .thenAnswer((_) async => Ok(limitOrderRate()));
    when(() => exchangeReads.getDefaultWallets())
        .thenAnswer((_) async => const Ok(_wallets));
    for (final network in [BitcoinNetwork.mainnet, LiquidNetwork.mainnet]) {
      when(() => inventory.walletsForNetwork(network))
          .thenAnswer((_) async => Ok(walletSelectionForTesting([])));
    }
  });

  test(
    'includes the in-app bitcoin and liquid wallets in the context',
    () async {
      when(() => exchangeReads.getUserSummary(ExchangeEnvironment.mainnet))
          .thenAnswer((_) async => Ok(userSummary()));
      when(
        () => inventory.walletsForNetwork(BitcoinNetwork.mainnet),
      ).thenAnswer(
        (_) async => Ok(
          walletSelectionForTesting([_wallet('w-btc', BitcoinNetwork.mainnet)]),
        ),
      );
      when(() => inventory.walletsForNetwork(LiquidNetwork.mainnet)).thenAnswer(
        (_) async => Ok(
          walletSelectionForTesting([_wallet('w-lbtc', LiquidNetwork.mainnet)]),
        ),
      );

      final result = await usecase.execute();

      final ids = valueOf(result).appWallets.map((w) => w.id).toList();
      expect(ids, ['w-btc', 'w-lbtc']);
    },
  );

  test('degrades to no in-app wallets when listing them fails', () async {
    when(() => exchangeReads.getUserSummary(ExchangeEnvironment.mainnet))
        .thenAnswer((_) async => Ok(userSummary()));
    when(
      () => inventory.walletsForNetwork(BitcoinNetwork.mainnet),
    ).thenAnswer((_) async => const Err(WalletRegistrationNotFoundFailure()));
    when(
      () => inventory.walletsForNetwork(LiquidNetwork.mainnet),
    ).thenAnswer((_) async => const Err(WalletRegistrationNotFoundFailure()));

    final result = await usecase.execute();

    expect(valueOf(result).appWallets, isEmpty);
    expect(valueOf(result).wallets, hasLength(2));
  });

  test('drops zero balances and refuses an unfunded account', () async {
    when(() => exchangeReads.getUserSummary(ExchangeEnvironment.mainnet))
        .thenAnswer(
          (_) async => Ok(
            userSummary(
              balances: const [UserBalance(amount: 0, currencyCode: 'CAD')],
            ),
          ),
        );

    final result = await usecase.execute();

    expect(failureOf(result), isA<LimitOrdersNoFundedBalanceFailure>());
    verifyZeroInteractions(repository);
  });

  test('does not read payouts or rates on regtest', () async {
    when(() => settings.environment).thenReturn(Environment.regtest);

    expect(
      failureOf(await usecase.execute()),
      isA<LimitOrdersUnsupportedNetworkFailure>(),
    );
    verifyZeroInteractions(exchangeReads);
    verifyZeroInteractions(inventory);
    verifyZeroInteractions(repository);
  });

  test('prefers the account currency when it holds a balance', () async {
    when(() => exchangeReads.getUserSummary(ExchangeEnvironment.mainnet))
        .thenAnswer(
          (_) async => Ok(
            userSummary(
              balances: const [
                UserBalance(amount: 10, currencyCode: 'USD'),
                UserBalance(amount: 20, currencyCode: 'CAD'),
              ],
              currency: 'CAD',
            ),
          ),
        );

    final context = valueOf(await usecase.execute());

    expect(context.selectedCurrency, FiatCurrency.cad);
    verify(() => repository.getRate('CAD')).called(1);
  });

  test('falls back to the first funded balance', () async {
    when(() => exchangeReads.getUserSummary(ExchangeEnvironment.mainnet))
        .thenAnswer(
          (_) async => Ok(
            userSummary(
              balances: const [UserBalance(amount: 10, currencyCode: 'USD')],
              currency: 'CAD',
            ),
          ),
        );

    final context = valueOf(await usecase.execute());

    expect(context.selectedCurrency, FiatCurrency.usd);
  });

  test('maps only the configured default wallets', () async {
    when(() => exchangeReads.getUserSummary(ExchangeEnvironment.mainnet))
        .thenAnswer((_) async => Ok(userSummary()));

    final context = valueOf(await usecase.execute());

    expect(context.wallets.map((wallet) => wallet.type), [
      LimitOrderWalletType.bitcoin,
      LimitOrderWalletType.liquid,
    ]);
  });

  test('forwards a rate failure untouched', () async {
    when(() => exchangeReads.getUserSummary(ExchangeEnvironment.mainnet))
        .thenAnswer((_) async => Ok(userSummary()));
    when(() => repository.getRate(any())).thenAnswer(
      (_) async => const Err(
        ExchangeLimitOrderFailure(ExchangeLimitOrderProblem.load, 'rate'),
      ),
    );

    expect(failureOf(await usecase.execute()), isA<LimitOrdersLoadFailure>());
  });

  test('maps an unavailable account to a typed failure', () async {
    when(() => exchangeReads.getUserSummary(ExchangeEnvironment.mainnet))
        .thenAnswer((_) async => const Err(ExchangeNetworkFailure()));

    expect(
      failureOf(await usecase.execute()),
      isA<LimitOrdersAccountUnavailableFailure>(),
    );
  });

  test('maps an unreadable default wallet list to the catch-all', () async {
    when(() => exchangeReads.getUserSummary(ExchangeEnvironment.mainnet))
        .thenAnswer((_) async => Ok(userSummary()));
    when(() => exchangeReads.getDefaultWallets())
        .thenAnswer((_) async => const Err(ExchangeNetworkFailure()));

    expect(
      failureOf(await usecase.execute()),
      isA<LimitOrdersUnexpectedFailure>(),
    );
  });

  test('fetches default and app wallets concurrently with the user summary, and the rate after it', () async {
    final summary = Completer<Result<UserSummary, ExchangeFailure>>();
    when(() => exchangeReads.getUserSummary(ExchangeEnvironment.mainnet))
        .thenAnswer((_) => summary.future);

    final result = usecase.execute();
    await Future<void>.delayed(Duration.zero);

    verify(() => exchangeReads.getDefaultWallets()).called(1);
    verify(() => inventory.walletsForNetwork(BitcoinNetwork.mainnet)).called(1);
    verify(() => inventory.walletsForNetwork(LiquidNetwork.mainnet)).called(1);
    verifyNever(() => repository.getRate(any()));

    summary.complete(Ok(userSummary()));
    expect(
      await result,
      isA<Ok<LimitOrderCreationContext, LimitOrdersFailure>>(),
    );
  });

  test('does not convert programmer errors into recoverable failures', () {
    when(() => exchangeReads.getUserSummary(ExchangeEnvironment.mainnet))
        .thenThrow(StateError('bug'));

    expect(() => usecase.execute(), throwsStateError);
  });
}
