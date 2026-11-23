import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:rust_bindings/rust_bindings.dart' show BullSdk;
import 'package:sync/sync.dart';
import 'package:sync/write.dart' show WalletNativeLifecycle;
import 'package:bull_exchange/testing.dart';
import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../core/exchange/fake_exchange_users.dart';

class MockExchangeOrders extends Mock implements ExchangeOrders {}

class MockWalletRepository extends Mock implements WalletInventory {}

class MockSettingsRepository extends Mock implements Preferences {}

class MockWalletAddressRepository extends Mock
    implements WalletNativeLifecycle {}

class MockExchangeUserRepository extends Mock
    implements ExchangeUserOperations {}

// The preference write now goes straight to the repository, which is the
// sanitizing boundary.

WalletRegistration _defaultWallet() => walletRegistrationForTesting(
  id: 'default-wallet',
  network: BitcoinNetwork.mainnet,
  isDefault: true,
);

/// Stands in for whatever a foreign exception message may embed — a
/// credential, a response body. It must never reach a [DcaFailure].
const _sentinelSecret = 'super-secret';

void main() {
  setUpAll(BullSdk.init);
  tearDownAll(BullSdk.dispose);
  setUpAll(() {
    registerFallbackValue(FiatCurrency.cad);
    registerFallbackValue(DcaBuyFrequency.daily);
    registerFallbackValue(DcaNetwork.bitcoin);
  });

  late MockExchangeOrders mainnetOrders;
  late MockExchangeOrders testnetOrders;
  late MockWalletRepository wallet;
  late MockExchangeUserRepository mainnetUsers;
  late MockExchangeUserRepository testnetUsers;
  late MockSettingsRepository settings;
  late MockWalletAddressRepository walletAddress;

  late SetDcaUsecase usecase;

  const mainnetSettings = SettingsEntity(
    environment: Environment.mainnet,
    bitcoinUnit: BitcoinUnit.sats,
    currencyCode: 'CAD',
  );

  // An account with AutoBuy already on: enabling the recurring buy must not
  // flip it off, since saveUserPreferences replaces the whole preference set.
  const userSummary = UserSummary(
    userNumber: 1,
    groups: [],
    profile: UserProfile(firstName: 'First', lastName: 'Last'),
    email: 'user@example.com',
    balances: [],
    language: 'en',
    currency: 'CAD',
    dca: UserDca(isActive: false),
    autoBuy: UserAutoBuy(isActive: true, addresses: UserAutoBuyAddresses()),
  );

  final dca = Dca(
    amount: 10,
    currency: FiatCurrency.cad,
    frequency: DcaBuyFrequency.daily,
    network: DcaNetwork.lightning,
    address: 'user@lightning.address',
    nextPurchaseDate: DateTime(2026),
  );

  setUp(() {
    mainnetOrders = MockExchangeOrders();
    testnetOrders = MockExchangeOrders();
    wallet = MockWalletRepository();
    mainnetUsers = MockExchangeUserRepository();
    testnetUsers = MockExchangeUserRepository();
    settings = MockSettingsRepository();
    walletAddress = MockWalletAddressRepository();

    usecase = SetDcaUsecase(
      payouts: ExchangePayoutWallets(wallet, walletAddress),
      settingsRepository: settings,
      exchange: fakeExchangeUsers(
        mainnetUsers,
        testnetUsers,
        orders: (environment) => environment == ExchangeEnvironment.testnet
            ? testnetOrders
            : mainnetOrders,
      ),
    );
    when(() => settings.fetch()).thenAnswer((_) async => Ok(mainnetSettings));
  });

  DcaFailure failureOf(Result<Dca, DcaFailure> result) {
    expect(result, isA<Err<Dca, DcaFailure>>());
    return (result as Err<Dca, DcaFailure>).failure;
  }

  group('SetDcaUsecase', () {
    test(
      'creates Bitcoin DCA with the native address of the unique default',
      () async {
        final registration = _defaultWallet();
        final key = WalletKey(
          id: registration.id,
          network: registration.network,
        );
        const address = '1BoatSLRHtKNngkdXEeobR76b53LETtpyT';
        when(() => wallet.walletsForNetwork(BitcoinNetwork.mainnet)).thenAnswer(
          (_) async => Ok(walletSelectionForTesting([registration])),
        );
        when(() => wallet.readWallet(registration.id))
            .thenAnswer((_) async => Ok(registration));
        when(() => walletAddress.receive(key, advance: true))
            .thenAnswer((_) async => const Ok((address: address, index: 3)));
        when(mainnetUsers.getUserSummary)
            .thenAnswer((_) async => const Ok(userSummary));
        Future<Result<Dca, ExchangeFailure>> placeOrder() =>
            mainnetOrders.createDca(
              amount: 10,
              currency: FiatCurrency.cad,
              frequency: DcaBuyFrequency.daily,
              network: DcaNetwork.bitcoin,
              address: address,
            );
        when(placeOrder).thenAnswer((_) async => Ok(dca));
        when(
          () => mainnetUsers.saveUserPreference(
            language: 'en',
            currency: 'CAD',
            dcaEnabled: true,
            autoBuyEnabled: 'true',
            emailNotificationsEnabled: true,
          ),
        ).thenAnswer((_) async => const Ok(null));

        final result = await usecase.execute(
          amount: 10,
          currency: FiatCurrency.cad,
          frequency: DcaBuyFrequency.daily,
          network: DcaNetwork.bitcoin,
        );

        expect(result, isA<Ok<Dca, DcaFailure>>());
        verifyInOrder([
          () => walletAddress.receive(key, advance: true),
          placeOrder,
        ]);
        verifyZeroInteractions(testnetOrders);
      },
    );

    test('refuses conflicting defaults before issuing or writing', () async {
      when(() => wallet.walletsForNetwork(BitcoinNetwork.mainnet)).thenAnswer(
        (_) async => Ok(
          walletSelectionForTesting([
            _defaultWallet(),
            walletRegistrationForTesting(
              id: 'other-default',
              network: BitcoinNetwork.mainnet,
              isDefault: true,
            ),
          ]),
        ),
      );
      final result = await usecase.execute(
        amount: 10,
        currency: FiatCurrency.cad,
        frequency: DcaBuyFrequency.daily,
        network: DcaNetwork.bitcoin,
      );
      expect(failureOf(result), isA<DcaReceiveAddressFailure>());
      verifyZeroInteractions(walletAddress);
      verifyZeroInteractions(mainnetOrders);
    });

    test('derives on the selected network and does not write if reauthorization fails', () async {
      final registration = _defaultWallet();
      final key = WalletKey(
        id: registration.id,
        network: BitcoinNetwork.mainnet,
      );
      when(
        () => wallet.walletsForNetwork(BitcoinNetwork.mainnet),
      ).thenAnswer((_) async => Ok(walletSelectionForTesting([registration])));
      when(() => wallet.readWallet(registration.id))
          .thenAnswer((_) async => const Err(KeystoreLockedFailure()));
      final result = await usecase.execute(
        amount: 10,
        currency: FiatCurrency.cad,
        frequency: DcaBuyFrequency.daily,
        network: DcaNetwork.bitcoin,
      );
      expect(failureOf(result), isA<DcaReceiveAddressFailure>());
      verifyNever(() => walletAddress.receive(key, advance: true));
      verifyZeroInteractions(mainnetOrders);
    });

    test('regtest refuses before wallet or account access', () async {
      when(() => settings.fetch()).thenAnswer(
        (_) async =>
            Ok(mainnetSettings.copyWith(environment: Environment.regtest)),
      );
      when(() => mainnetUsers.getUserSummary())
          .thenAnswer((_) async => const Err(ExchangeUnexpectedFailure()));
      final result = await usecase.execute(
        amount: 10,
        currency: FiatCurrency.cad,
        frequency: DcaBuyFrequency.daily,
        network: DcaNetwork.lightning,
        lightningAddress: 'user@example.com',
      );
      expect(result, isA<Err<Dca, DcaFailure>>());
      verifyZeroInteractions(mainnetUsers);
      verifyZeroInteractions(testnetUsers);
      verifyZeroInteractions(mainnetOrders);
      verifyZeroInteractions(testnetOrders);
      verifyZeroInteractions(wallet);
      verifyZeroInteractions(walletAddress);
    });

    test('maps a missing lightning address to LightningAddressRequired '
        'without calling the exchange', () async {
      final result = await usecase.execute(
        amount: 10,
        currency: FiatCurrency.cad,
        frequency: DcaBuyFrequency.daily,
        network: DcaNetwork.lightning,
        lightningAddress: null,
      );

      final failure = failureOf(result);
      expect(failure, isA<DcaLightningAddressRequiredFailure>());
      expect(failure.logMessage, isNull);
      verifyZeroInteractions(mainnetOrders);
    });

    test(
      'maps an empty default-wallet list to ReceiveAddressFailure',
      () async {
        when(() => wallet.walletsForNetwork(BitcoinNetwork.mainnet))
            .thenAnswer((_) async => Ok(walletSelectionForTesting([])));

        final result = await usecase.execute(
          amount: 10,
          currency: FiatCurrency.cad,
          frequency: DcaBuyFrequency.daily,
          network: DcaNetwork.bitcoin,
        );

        final failure = failureOf(result);
        expect(failure, isA<DcaReceiveAddressFailure>());
        expect(failure.logMessage, isNull);
        verifyZeroInteractions(mainnetOrders);
      },
    );

    test(
      'a failed wallet read is NOT reported as a missing receive address',
      () async {
        // An onboarded install always has both default wallets, so an empty
        // list means "not set up" while a failure means "could not read".
        // Reporting the same thing for both would misdiagnose the common case.
        when(() => wallet.walletsForNetwork(BitcoinNetwork.mainnet))
            .thenAnswer((_) async => const Err(KeystoreLockedFailure()));

        final result = await usecase.execute(
          amount: 10,
          currency: FiatCurrency.cad,
          frequency: DcaBuyFrequency.daily,
          network: DcaNetwork.bitcoin,
        );

        final failure = failureOf(result);
        expect(failure, isA<DcaUnexpectedFailure>());
        expect(failure, isNot(isA<DcaReceiveAddressFailure>()));
        // The wallet layer's reason stays in the log.
        expect(failure.logMessage, isNot(contains('disk image is malformed')));
        verifyZeroInteractions(mainnetOrders);
      },
    );

    test('maps a failing address generation to ReceiveAddressFailure without '
        'logging the wallet identifier', () async {
      when(() => wallet.walletsForNetwork(BitcoinNetwork.mainnet)).thenAnswer(
        (_) async => Ok(walletSelectionForTesting([_defaultWallet()])),
      );
      final registration = _defaultWallet();
      when(() => wallet.readWallet(registration.id))
          .thenAnswer((_) async => Ok(registration));
      final key = WalletKey(
        id: registration.id,
        network: BitcoinNetwork.mainnet,
      );
      when(() => walletAddress.receive(key, advance: true))
          .thenAnswer((_) async => const Err(SyncStorageFailure()));

      final result = await usecase.execute(
        amount: 10,
        currency: FiatCurrency.cad,
        frequency: DcaBuyFrequency.daily,
        network: DcaNetwork.bitcoin,
      );

      final failure = failureOf(result);
      expect(failure, isA<DcaReceiveAddressFailure>());
      expect(failure.logMessage, isNull);
      verify(() => walletAddress.receive(key, advance: true)).called(1);
      verifyZeroInteractions(mainnetOrders);
    });

    test('maps an exchange rejection to OrderCreationFailure without carrying '
        'the raw reason', () async {
      when(() => mainnetUsers.getUserSummary())
          .thenAnswer((_) async => const Ok(userSummary));
      when(
        () => mainnetOrders.createDca(
          amount: any(named: 'amount'),
          currency: any(named: 'currency'),
          frequency: any(named: 'frequency'),
          network: any(named: 'network'),
          address: any(named: 'address'),
        ),
      ).thenAnswer(
        (_) async => const Err(
          ExchangeNetworkFailure(
            'Failed to create DCA: HTTP 500 apiKey=$_sentinelSecret',
          ),
        ),
      );

      final result = await usecase.execute(
        amount: 10,
        currency: FiatCurrency.cad,
        frequency: DcaBuyFrequency.daily,
        network: DcaNetwork.lightning,
        lightningAddress: 'user@lightning.address',
      );

      final failure = failureOf(result);
      expect(failure, isA<DcaOrderCreationFailure>());
      // A foreign diagnostic must not reach the DCA feature failure.
      expect(failure.logMessage, isNot(contains(_sentinelSecret)));
      expect(failure.logMessage, 'createDca rejected');
    });

    test('keeps the flow successful when the order was created but enabling '
        'the preference failed', () async {
      when(
        () => mainnetOrders.createDca(
          amount: any(named: 'amount'),
          currency: any(named: 'currency'),
          frequency: any(named: 'frequency'),
          network: any(named: 'network'),
          address: any(named: 'address'),
        ),
      ).thenAnswer((_) async => Ok(dca));
      when(() => mainnetUsers.getUserSummary())
          .thenAnswer((_) async => const Ok(userSummary));
      when(
        () => mainnetUsers.saveUserPreference(
          language: any(named: 'language'),
          currency: any(named: 'currency'),
          dcaEnabled: any(named: 'dcaEnabled'),
          autoBuyEnabled: any(named: 'autoBuyEnabled'),
          emailNotificationsEnabled: any(named: 'emailNotificationsEnabled'),
        ),
      ).thenAnswer(
        (_) async =>
            const Err(ExchangePreferencesSaveFailure('prefs write failed')),
      );

      final result = await usecase.execute(
        amount: 10,
        currency: FiatCurrency.cad,
        frequency: DcaBuyFrequency.daily,
        network: DcaNetwork.lightning,
        lightningAddress: 'user@lightning.address',
      );

      // The recurring buy exists on the exchange: reporting a failure here
      // would tell the user nothing happened and invite a duplicate order.
      expect(result, isA<Ok<Dca, DcaFailure>>());
      expect((result as Ok<Dca, DcaFailure>).value, same(dca));
    });

    test('rethrows an Error instead of turning a bug into a failure', () async {
      when(() => settings.fetch()).thenThrow(StateError('bug'));

      expect(
        () => usecase.execute(
          amount: 10,
          currency: FiatCurrency.cad,
          frequency: DcaBuyFrequency.daily,
          network: DcaNetwork.lightning,
          lightningAddress: 'user@lightning.address',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('returns Ok with the created dca on success', () async {
      when(
        () => mainnetOrders.createDca(
          amount: any(named: 'amount'),
          currency: any(named: 'currency'),
          frequency: any(named: 'frequency'),
          network: any(named: 'network'),
          address: any(named: 'address'),
        ),
      ).thenAnswer((_) async => Ok(dca));
      when(() => mainnetUsers.getUserSummary())
          .thenAnswer((_) async => const Ok(userSummary));
      when(
        () => mainnetUsers.saveUserPreference(
          language: any(named: 'language'),
          currency: any(named: 'currency'),
          dcaEnabled: any(named: 'dcaEnabled'),
          autoBuyEnabled: any(named: 'autoBuyEnabled'),
          emailNotificationsEnabled: any(named: 'emailNotificationsEnabled'),
        ),
      ).thenAnswer((_) async => const Ok(null));

      final result = await usecase.execute(
        amount: 10,
        currency: FiatCurrency.cad,
        frequency: DcaBuyFrequency.daily,
        network: DcaNetwork.lightning,
        lightningAddress: 'user@lightning.address',
      );

      expect(result, isA<Ok<Dca, DcaFailure>>());
      expect((result as Ok<Dca, DcaFailure>).value, same(dca));
    });

    test('sends the full preference set so an active AutoBuy survives '
        'enabling the recurring buy', () async {
      when(
        () => mainnetOrders.createDca(
          amount: any(named: 'amount'),
          currency: any(named: 'currency'),
          frequency: any(named: 'frequency'),
          network: any(named: 'network'),
          address: any(named: 'address'),
        ),
      ).thenAnswer((_) async => Ok(dca));
      when(() => mainnetUsers.getUserSummary())
          .thenAnswer((_) async => const Ok(userSummary));
      when(
        () => mainnetUsers.saveUserPreference(
          language: any(named: 'language'),
          currency: any(named: 'currency'),
          dcaEnabled: any(named: 'dcaEnabled'),
          autoBuyEnabled: any(named: 'autoBuyEnabled'),
          emailNotificationsEnabled: any(named: 'emailNotificationsEnabled'),
        ),
      ).thenAnswer((_) async => const Ok(null));

      final result = await usecase.execute(
        amount: 10,
        currency: FiatCurrency.cad,
        frequency: DcaBuyFrequency.daily,
        network: DcaNetwork.lightning,
        lightningAddress: 'user@lightning.address',
      );

      expect(result, isA<Ok<Dca, DcaFailure>>());
      verify(
        () => mainnetUsers.saveUserPreference(
          language: 'en',
          currency: 'CAD',
          dcaEnabled: true,
          autoBuyEnabled: 'true',
          emailNotificationsEnabled: true,
        ),
      ).called(1);
    });

    test(
      'aborts before creating anything when the summary read fails',
      () async {
        // The DCA flag is operative on the exchange (stopping a recurring buy
        // writes it), and the enabling write must carry the full current set.
        // A failed summary read therefore aborts the flow while nothing exists
        // on the exchange yet, instead of creating a DCA it cannot enable.
        when(
          () => mainnetUsers.getUserSummary(),
        ).thenAnswer((_) async => const Err(ExchangeNetworkFailure('timeout')));

        final result = await usecase.execute(
          amount: 10,
          currency: FiatCurrency.cad,
          frequency: DcaBuyFrequency.daily,
          network: DcaNetwork.lightning,
          lightningAddress: 'user@lightning.address',
        );

        final failure = failureOf(result);
        expect(failure, isA<DcaAccountUnavailableFailure>());
        verifyZeroInteractions(mainnetOrders);
        verifyNever(
          () => mainnetUsers.saveUserPreference(
            language: any(named: 'language'),
            currency: any(named: 'currency'),
            dcaEnabled: any(named: 'dcaEnabled'),
            autoBuyEnabled: any(named: 'autoBuyEnabled'),
            emailNotificationsEnabled: any(named: 'emailNotificationsEnabled'),
          ),
        );
      },
    );
  });
}
