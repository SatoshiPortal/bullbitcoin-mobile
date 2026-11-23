import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:rust_bindings/rust_bindings.dart' show BullSdk;
import 'package:sync/sync.dart';
import 'package:sync/write.dart' show WalletNativeLifecycle;
import 'package:bull_exchange/testing.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../exchange/data/bbx_api_test_http.dart';

class MockExchangeOrders extends Mock implements ExchangeOrders {}

class MockWalletRepository extends Mock implements WalletInventory {}

class MockSettingsRepository extends Mock implements Preferences {}

class MockWalletAddressRepository extends Mock
    implements WalletNativeLifecycle {}

/// Routed through the failing address-generation path so the test output can
/// be searched for it: it must never appear in a log line.
const _sentinelWalletId = 'wallet-id-must-not-be-logged';
WalletRegistration _defaultWallet() => walletRegistrationForTesting(
  id: _sentinelWalletId,
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
  late MockSettingsRepository settings;
  late MockWalletAddressRepository walletAddress;

  late SetDcaUsecase usecase;

  const mainnetSettings = SettingsEntity(
    environment: Environment.mainnet,
    bitcoinUnit: BitcoinUnit.sats,
    currencyCode: 'CAD',
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
    settings = MockSettingsRepository();
    walletAddress = MockWalletAddressRepository();

    usecase = SetDcaUsecase(
      payouts: ExchangePayoutWallets(wallet, walletAddress),
      settingsRepository: settings,
      exchange: exchangeForTesting(
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
        Future<Result<Dca, ExchangeFailure>> placeOrder() =>
            mainnetOrders.createDca(
              amount: 10,
              currency: FiatCurrency.cad,
              frequency: DcaBuyFrequency.daily,
              network: DcaNetwork.bitcoin,
              address: address,
              enablePreference: true,
            );
        when(placeOrder).thenAnswer((_) async => Ok(dca));

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
      final result = await usecase.execute(
        amount: 10,
        currency: FiatCurrency.cad,
        frequency: DcaBuyFrequency.daily,
        network: DcaNetwork.lightning,
        lightningAddress: 'user@example.com',
      );
      expect(result, isA<Err<Dca, DcaFailure>>());
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
      when(
        () => mainnetOrders.createDca(
          amount: any(named: 'amount'),
          currency: any(named: 'currency'),
          frequency: any(named: 'frequency'),
          network: any(named: 'network'),
          address: any(named: 'address'),
          enablePreference: true,
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

    for (final (name, scenario) in [
      (
        'enables the preference after a successful creation during a session storage failure',
        'completionRead',
      ),
      (
        'keeps the DCA when the exchange rejects the preference write',
        'refusedPreference',
      ),
      (
        'keeps the DCA when the session changes before the preference write',
        'changedSession',
      ),
      (
        'aborts before creating anything when the summary read fails',
        'refusedSummary',
      ),
    ]) {
      test(name, () async {
        var reads = 0;
        final http = FakeBbxHttp(
          respond: (request) {
            final method = (request.data as Map)['method'];
            if ((method == 'getUserSummary' && scenario == 'refusedSummary') ||
                (method == 'saveUserPreferences' &&
                    scenario == 'refusedPreference')) {
              return {
                'error': {'code': -32603},
              };
            }
            return {
              'result': switch (method) {
                'getUserSummary' => {
                  'userNumber': 1,
                  'groups': [],
                  'profile': {'firstName': 'First', 'lastName': 'Last'},
                  'email': 'user@example.com',
                  'balances': [],
                  'language': 'en',
                  'currency': 'CAD',
                  'dca': {'isActive': false},
                  'autoBuy': {'isActive': true, 'addresses': {}},
                },
                'createDCA' => {
                  'element': {
                    'userId': 'synthetic-user',
                    'userNbr': 1,
                    'amountStr': '10',
                    'currencyCode': 'CAD',
                    'recurringFrequency': 'DAILY',
                    'recipientType': 'OUT_LIGHTNING_ADDRESS',
                    'nextRunAt': '2026-11-24T00:00:00Z',
                    'createdAt': '2026-11-23T00:00:00Z',
                    'address': 'user@lightning.address',
                  },
                },
                'saveUserPreferences' => null,
                _ => fail('Unexpected exchange request'),
              },
            };
          },
        );
        final usecase = SetDcaUsecase(
          wallet: wallet,
          settingsRepository: settings,
          walletAddressRepository: walletAddress,
          exchange: testExchange(
            http,
            // The old runner reads credentials a fifth time, after the
            // successful creation and before the preference can be sent.
            readApiKey: () async {
              reads++;
              if (scenario == 'changedSession' && http.requests.length == 2) {
                return const Ok('changed-key');
              }
              return reads == 5 && scenario == 'completionRead'
                  ? const Err(ExchangeCredentialReadFailure())
                  : const Ok('synthetic-key');
            },
          ),
        );

        final result = await usecase.execute(
          amount: 10,
          currency: FiatCurrency.cad,
          frequency: DcaBuyFrequency.daily,
          network: DcaNetwork.lightning,
          lightningAddress: 'user@lightning.address',
        );

        if (scenario == 'refusedSummary') {
          expect(failureOf(result), isA<DcaAccountUnavailableFailure>());
        } else {
          expect(result, isA<Ok<Dca, DcaFailure>>());
        }
        expect(
          http.requests.map((request) => (request.data as Map)['method']),
          [
            'getUserSummary',
            if (scenario != 'refusedSummary') 'createDCA',
            if (scenario == 'completionRead' || scenario == 'refusedPreference')
              'saveUserPreferences',
          ],
        );
        if (scenario == 'completionRead' || scenario == 'refusedPreference') {
          expect((http.requests.last.data as Map)['params'], {
            'userPreferences': {
              'LANGUAGE': 'en',
              'DEFAULT_FIAT_CURRENCY_CODE': 'CAD',
              'DCA_ENABLED': 'true',
              'AUTO_BUY_ENABLED': 'true',
              'EMAIL_NOTIFICATIONS': 'true',
            },
          });
        }
      });
    }

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
          enablePreference: true,
        ),
      ).thenAnswer((_) async => Ok(dca));
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
  });
}
