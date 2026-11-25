import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:settings/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSettingsRepository extends Mock implements Preferences {}

class MockExchangeUserRepository extends Mock
    implements ExchangeUserOperations {}

void main() {
  late MockSettingsRepository settings;
  late MockExchangeUserRepository mainnetUsers;
  late MockExchangeUserRepository testnetUsers;
  late SyncExchangeCurrencyUsecase usecase;

  const mainnetSettings = SettingsEntity(
    environment: Environment.mainnet,
    bitcoinUnit: BitcoinUnit.sats,
    currencyCode: 'CAD',
  );

  const userSummary = UserSummary(
    userNumber: 1,
    groups: [],
    profile: UserProfile(firstName: 'First', lastName: 'Last'),
    email: 'user@example.com',
    balances: [],
    language: 'en',
    currency: 'CAD',
    dca: UserDca(isActive: true),
    autoBuy: UserAutoBuy(isActive: true, addresses: UserAutoBuyAddresses()),
  );

  setUp(() {
    settings = MockSettingsRepository();
    mainnetUsers = MockExchangeUserRepository();
    testnetUsers = MockExchangeUserRepository();
    usecase = SyncExchangeCurrencyUsecase(
      settingsRepository: settings,
      exchange: fakeExchangeUsers(
        mainnetUsers,
        testnetUsers,
        access: fixedAccessForTesting(
          const ExchangeAccessSignedIn(
            ExchangeSession(
              environment: ExchangeEnvironment.mainnet,
              epoch: 1,
              sessionId: 'test',
            ),
          ),
        ),
      ),
    );
    when(() => settings.fetch()).thenAnswer((_) async => Ok(mainnetSettings));
  });

  group('SyncExchangeCurrencyUsecase', () {
    test('regtest skips optional exchange currency sync', () async {
      when(settings.fetch).thenAnswer(
        (_) async =>
            Ok(mainnetSettings.copyWith(environment: Environment.regtest)),
      );
      for (final currency in ['CAD', 'USD']) {
        final result = await usecase.execute(currency);
        expect(result, isA<Ok<void, SettingsFailure>>());
      }
      verifyZeroInteractions(mainnetUsers);
      verifyZeroInteractions(testnetUsers);
    });

    test('a currency the exchange does not offer is not synced', () async {
      final result = await usecase.execute('JPY');

      expect(result, isA<Ok<void, SettingsFailure>>());
      verifyZeroInteractions(mainnetUsers);
      verifyZeroInteractions(testnetUsers);
    });

    test('a signed-out user is not an error and nothing is written', () async {
      when(
        () => mainnetUsers.getUserSummary(),
      ).thenAnswer((_) async => const Err(ExchangeNotAuthenticatedFailure()));

      final result = await usecase.execute('EUR');

      expect(result, isA<Ok<void, SettingsFailure>>());
      verifyNever(
        () => mainnetUsers.saveUserPreference(
          language: any(named: 'language'),
          currency: any(named: 'currency'),
          dcaEnabled: any(named: 'dcaEnabled'),
          autoBuyEnabled: any(named: 'autoBuyEnabled'),
          emailNotificationsEnabled: any(named: 'emailNotificationsEnabled'),
        ),
      );
    });

    test(
      'changes the currency and sends the other preferences as read',
      () async {
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

        final result = await usecase.execute('EUR');

        expect(result, isA<Ok<void, SettingsFailure>>());
        verify(
          () => mainnetUsers.saveUserPreference(
            language: 'en',
            currency: 'EUR',
            dcaEnabled: true,
            autoBuyEnabled: 'true',
            emailNotificationsEnabled: true,
          ),
        ).called(1);
      },
    );

    test('an exchange already on the chosen currency is left alone', () async {
      when(() => mainnetUsers.getUserSummary())
          .thenAnswer((_) async => const Ok(userSummary));

      final result = await usecase.execute('CAD');

      expect(result, isA<Ok<void, SettingsFailure>>());
      verifyNever(
        () => mainnetUsers.saveUserPreference(
          language: any(named: 'language'),
          currency: any(named: 'currency'),
          dcaEnabled: any(named: 'dcaEnabled'),
          autoBuyEnabled: any(named: 'autoBuyEnabled'),
          emailNotificationsEnabled: any(named: 'emailNotificationsEnabled'),
        ),
      );
    });

    test('a summary read failure blocks the write and is reported', () async {
      // Writing without the summary would reset the other preferences, since
      // the exchange replaces the whole set.
      when(
        () => mainnetUsers.getUserSummary(),
      ).thenAnswer((_) async => const Err(ExchangeNetworkFailure('timeout')));

      final result = await usecase.execute('EUR');

      expect(result, isA<Err<void, SettingsFailure>>());
      expect(
        (result as Err<void, SettingsFailure>).failure,
        isA<SettingsExchangeSyncFailure>(),
      );
      verifyNever(
        () => mainnetUsers.saveUserPreference(
          language: any(named: 'language'),
          currency: any(named: 'currency'),
          dcaEnabled: any(named: 'dcaEnabled'),
          autoBuyEnabled: any(named: 'autoBuyEnabled'),
          emailNotificationsEnabled: any(named: 'emailNotificationsEnabled'),
        ),
      );
    });

    test('a failed preference write is reported', () async {
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
        (_) async => const Err(ExchangePreferencesSaveFailure('write failed')),
      );

      final result = await usecase.execute('EUR');

      expect(result, isA<Err<void, SettingsFailure>>());
      expect(
        (result as Err<void, SettingsFailure>).failure,
        isA<SettingsExchangeSyncFailure>(),
      );
    });
  });
}
