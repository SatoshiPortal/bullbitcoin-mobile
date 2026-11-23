import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/address_view/domain/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_error.dart';
import 'package:bb_mobile/features/dca/domain/dca_failure.dart';
import 'package:bb_mobile/features/dca/domain/usecases/set_dca_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../exchange/data/bbx_api_test_http.dart';

class MockExchangeOrders extends Mock implements ExchangeOrders {}

class MockWalletRepository extends Mock implements WalletRepository {}

class MockSettingsRepository extends Mock implements Preferences {}

class MockWalletAddressRepository extends Mock
    implements WalletAddressRepository {}

class FakeWallet extends Fake implements Wallet {
  @override
  String get id => 'default-wallet';
}

/// Routed through the failing address-generation path so the test output can
/// be searched for it: it must never appear in a log line.
const _sentinelWalletId = 'wallet-id-must-not-be-logged';

/// Stands in for whatever a foreign exception message may embed — a
/// credential, a response body. It must never reach a [DcaFailure].
const _sentinelSecret = 'super-secret';

void main() {
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
      wallet: wallet,
      settingsRepository: settings,
      walletAddressRepository: walletAddress,
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
        when(
          () => wallet.getWallets(
            environment: Environment.mainnet,
            onlyDefaults: true,
            onlyBitcoin: true,
            onlyLiquid: false,
          ),
        ).thenAnswer((_) async => Ok([]));

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
        when(
          () => wallet.getWallets(
            environment: Environment.mainnet,
            onlyDefaults: true,
            onlyBitcoin: true,
            onlyLiquid: false,
          ),
        ).thenAnswer(
          (_) async => const Err<List<Wallet>, WalletFailure>(
            WalletStorageFailure(
              'SqliteException(11): disk image is malformed',
            ),
          ),
        );

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
      when(
        () => wallet.getWallets(
          environment: Environment.mainnet,
          onlyDefaults: true,
          onlyBitcoin: true,
          onlyLiquid: false,
        ),
      ).thenAnswer((_) async => Ok([FakeWallet()]));
      when(
        () => walletAddress.generateNewReceiveAddress(
          walletId: any(named: 'walletId'),
        ),
      ).thenThrow(const WalletNotFoundException(_sentinelWalletId));

      final result = await usecase.execute(
        amount: 10,
        currency: FiatCurrency.cad,
        frequency: DcaBuyFrequency.daily,
        network: DcaNetwork.bitcoin,
      );

      final failure = failureOf(result);
      expect(failure, isA<DcaReceiveAddressFailure>());
      // The failure travels into bloc state, so its logMessage is a fixed
      // breadcrumb: the identifier must not survive into it. The raw error
      // still reaches `log.severe`, which is the only sink allowed to see it.
      expect(failure.logMessage, isNot(contains(_sentinelWalletId)));
      expect(failure.logMessage, 'receive address generation failed');
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
