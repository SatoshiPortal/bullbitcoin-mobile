import 'package:bull_exchange/testing.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockExchangeOrders extends Mock implements ExchangeOrders {}

class MockSettingsRepository extends Mock implements Preferences {}

/// Stands in for whatever a foreign exception message may embed — a
/// credential, a response body. It must never reach a [DcaFailure].
const _sentinelSecret = 'super-secret';

void main() {
  setUpAll(() {
    registerFallbackValue(FiatCurrency.cad);
    registerFallbackValue(DcaBuyFrequency.daily);
    registerFallbackValue(BtcNetwork.bitcoin);
  });

  late MockExchangeOrders mainnetOrders;
  late MockExchangeOrders testnetOrders;
  late MockSettingsRepository settings;

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
    network: BtcNetwork.lightning,
    address: 'user@lightning.address',
    nextPurchaseDate: DateTime(2026),
  );

  setUp(() {
    mainnetOrders = MockExchangeOrders();
    testnetOrders = MockExchangeOrders();
    settings = MockSettingsRepository();

    usecase = SetDcaUsecase(
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
    test('regtest refuses before account access', () async {
      when(() => settings.fetch()).thenAnswer(
        (_) async =>
            Ok(mainnetSettings.copyWith(environment: Environment.regtest)),
      );
      final result = await usecase.execute(
        amount: 10,
        currency: FiatCurrency.cad,
        frequency: DcaBuyFrequency.daily,
        network: BtcNetwork.lightning,
        address: 'user@example.com',
      );
      expect(result, isA<Err<Dca, DcaFailure>>());
      verifyZeroInteractions(mainnetOrders);
      verifyZeroInteractions(testnetOrders);
    });

    test('maps a missing lightning address to LightningAddressRequired '
        'without calling the exchange', () async {
      final result = await usecase.execute(
        amount: 10,
        currency: FiatCurrency.cad,
        frequency: DcaBuyFrequency.daily,
        network: BtcNetwork.lightning,
        address: '',
      );

      final failure = failureOf(result);
      expect(failure, isA<DcaLightningAddressRequiredFailure>());
      expect(failure.logMessage, isNull);
      verifyZeroInteractions(mainnetOrders);
    });

    test('maps an empty Bitcoin address to DestinationAddressRequired '
        'without calling the exchange', () async {
      final result = await usecase.execute(
        amount: 10,
        currency: FiatCurrency.cad,
        frequency: DcaBuyFrequency.daily,
        network: BtcNetwork.bitcoin,
        address: '',
      );

      final failure = failureOf(result);
      expect(failure, isA<DcaDestinationAddressRequiredFailure>());
      verifyZeroInteractions(mainnetOrders);
    });

    for (final network in [BtcNetwork.bitcoin, BtcNetwork.liquid]) {
      test('sends the chosen ${network.name} address (exchange default wallet '
          'or typed) unchanged as the DCA destination', () async {
        const destination = 'default-wallet-address';
        when(
          () => mainnetOrders.createDca(
            amount: any(named: 'amount'),
            currency: any(named: 'currency'),
            frequency: any(named: 'frequency'),
            network: any(named: 'network'),
            address: any(named: 'address'),
          ),
        ).thenAnswer((_) async => WriteDone(dca));

        final result = await usecase.execute(
          amount: 10,
          currency: FiatCurrency.cad,
          frequency: DcaBuyFrequency.daily,
          network: network,
          address: destination,
        );

        expect(result, isA<Ok<Dca, DcaFailure>>());
        verify(
          () => mainnetOrders.createDca(
            amount: 10,
            currency: FiatCurrency.cad,
            frequency: DcaBuyFrequency.daily,
            network: network,
            address: destination,
          ),
        ).called(1);
      });
    }

    test('maps an exchange rejection to OrderCreationFailure without carrying '
        'the raw reason', () async {
      when(
        () => mainnetOrders.createDca(
          amount: any(named: 'amount'),
          currency: any(named: 'currency'),
          frequency: any(named: 'frequency'),
          network: any(named: 'network'),
          address: any(named: 'address'),
        ),
      ).thenAnswer(
        (_) async => const WriteRefused(ExchangeRefusal(httpStatus: 500)),
      );

      final result = await usecase.execute(
        amount: 10,
        currency: FiatCurrency.cad,
        frequency: DcaBuyFrequency.daily,
        network: BtcNetwork.lightning,
        address: 'user@lightning.address',
      );

      final failure = failureOf(result);
      expect(failure, isA<DcaOrderCreationFailure>());
      // A foreign diagnostic must not reach the DCA feature failure.
      expect(failure.logMessage, isNot(contains(_sentinelSecret)));
      expect(failure.logMessage, 'createDca rejected');
    });

    group('enabling the DCA preference after the creation', () {
      const session = ExchangeSession(
        environment: ExchangeEnvironment.mainnet,
        epoch: 1,
        sessionId: 'test',
      );
      const account = UserSummary(
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

      for (final (name, summary, saved, expected) in [
        (
          'goes through the one preference writer',
          const Ok<UserSummary, ExchangeFailure>(account),
          const Ok<void, ExchangeFailure>(null),
          [
            {
              'language': 'en',
              'currency': 'CAD',
              'dcaEnabled': true,
              'autoBuyEnabled': 'true',
              'emailNotificationsEnabled': true,
            },
          ],
        ),
        (
          'keeps the DCA when the preference write is refused',
          const Ok<UserSummary, ExchangeFailure>(account),
          const Err<void, ExchangeFailure>(ExchangePreferencesSaveFailure()),
          [
            {
              'language': 'en',
              'currency': 'CAD',
              'dcaEnabled': true,
              'autoBuyEnabled': 'true',
              'emailNotificationsEnabled': true,
            },
          ],
        ),
        (
          'keeps the DCA and writes nothing when the summary is unreadable',
          const Err<UserSummary, ExchangeFailure>(ExchangeNetworkFailure()),
          const Ok<void, ExchangeFailure>(null),
          <Map<String, Object?>>[],
        ),
      ]) {
        test(name, () async {
          final sent = <Map<String, Object?>>[];
          when(
            () => mainnetOrders.createDca(
              amount: any(named: 'amount'),
              currency: any(named: 'currency'),
              frequency: any(named: 'frequency'),
              network: any(named: 'network'),
              address: any(named: 'address'),
            ),
          ).thenAnswer((_) async => WriteDone(dca));
          final usecase = SetDcaUsecase(
            settingsRepository: settings,
            exchange: exchangeForTesting(
              access: fixedAccessForTesting(
                const ExchangeAccessSignedIn(session),
              ),
              orders: (_) => mainnetOrders,
              getUserSummary: (_) async => summary,
              saveUserPreference:
                  (
                    _, {
                    language,
                    currency,
                    dcaEnabled,
                    autoBuyEnabled,
                    emailNotificationsEnabled,
                  }) async {
                    sent.add({
                      'language': language,
                      'currency': currency,
                      'dcaEnabled': dcaEnabled,
                      'autoBuyEnabled': autoBuyEnabled,
                      'emailNotificationsEnabled': emailNotificationsEnabled,
                    });
                    return saved;
                  },
            ),
          );

          final result = await usecase.execute(
            amount: 10,
            currency: FiatCurrency.cad,
            frequency: DcaBuyFrequency.daily,
            network: BtcNetwork.lightning,
            address: 'user@lightning.address',
          );

          expect(result, isA<Ok<Dca, DcaFailure>>());
          expect(sent, expected);
        });
      }
    });

    test('an unknown create outcome is never reported as a failure to retry '
        '(DCA-2)', () async {
      when(
        () => mainnetOrders.createDca(
          amount: any(named: 'amount'),
          currency: any(named: 'currency'),
          frequency: any(named: 'frequency'),
          network: any(named: 'network'),
          address: any(named: 'address'),
        ),
      ).thenAnswer((_) async => const WriteOutcomeUnknown('receive timeout'));

      final result = await usecase.execute(
        amount: 10,
        currency: FiatCurrency.cad,
        frequency: DcaBuyFrequency.daily,
        network: BtcNetwork.lightning,
        address: 'user@lightning.address',
      );

      expect(failureOf(result), isA<DcaCreationOutcomeUnknownFailure>());
    });

    for (final (name, write) in <(String, ExchangeWrite<Dca>)>[
      ('signed out', const WriteNotSent(ExchangeNotSentReason.signedOut)),
      ('unreachable', const WriteNotSent(ExchangeNotSentReason.unreachable)),
      ('a rejected session', const WriteSessionRejected()),
    ]) {
      test('$name is an unavailable account', () async {
        when(
          () => mainnetOrders.createDca(
            amount: any(named: 'amount'),
            currency: any(named: 'currency'),
            frequency: any(named: 'frequency'),
            network: any(named: 'network'),
            address: any(named: 'address'),
          ),
        ).thenAnswer((_) async => write);

        final result = await usecase.execute(
          amount: 10,
          currency: FiatCurrency.cad,
          frequency: DcaBuyFrequency.daily,
          network: BtcNetwork.lightning,
          address: 'user@lightning.address',
        );

        expect(failureOf(result), isA<DcaAccountUnavailableFailure>());
      });
    }

    test('rethrows an Error instead of turning a bug into a failure', () async {
      when(() => settings.fetch()).thenThrow(StateError('bug'));

      expect(
        () => usecase.execute(
          amount: 10,
          currency: FiatCurrency.cad,
          frequency: DcaBuyFrequency.daily,
          network: BtcNetwork.lightning,
          address: 'user@lightning.address',
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
      ).thenAnswer((_) async => WriteDone(dca));
      final result = await usecase.execute(
        amount: 10,
        currency: FiatCurrency.cad,
        frequency: DcaBuyFrequency.daily,
        network: BtcNetwork.lightning,
        address: 'user@lightning.address',
      );

      expect(result, isA<Ok<Dca, DcaFailure>>());
      expect((result as Ok<Dca, DcaFailure>).value, same(dca));
    });
  });
}
