import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_user_failure.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_user_repository.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/usecases/sync_exchange_currency_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockExchangeUserRepository extends Mock
    implements ExchangeUserRepository {}

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
      mainnetExchangeUserRepository: mainnetUsers,
      testnetExchangeUserRepository: testnetUsers,
    );
    when(() => settings.fetch()).thenAnswer((_) async => mainnetSettings);
  });

  group('SyncExchangeCurrencyUsecase', () {
    test('a currency the exchange does not offer is not synced', () async {
      final result = await usecase.execute('JPY');

      expect(result, isA<Ok<void, SettingsFailure>>());
      verifyZeroInteractions(mainnetUsers);
      verifyZeroInteractions(testnetUsers);
    });

    test('a signed-out user is not an error and nothing is written', () async {
      when(() => mainnetUsers.getUserSummary()).thenAnswer(
        (_) async => const Err(ExchangeUserNotAuthenticatedFailure()),
      );

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

    test('writes the full preference set with the new currency', () async {
      when(
        () => mainnetUsers.getUserSummary(),
      ).thenAnswer((_) async => const Ok(userSummary));
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
    });

    test('an exchange already on the chosen currency is left alone', () async {
      when(
        () => mainnetUsers.getUserSummary(),
      ).thenAnswer((_) async => const Ok(userSummary));

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
      when(() => mainnetUsers.getUserSummary()).thenAnswer(
        (_) async => const Err(ExchangeUserNetworkFailure('timeout')),
      );

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
      when(
        () => mainnetUsers.getUserSummary(),
      ).thenAnswer((_) async => const Ok(userSummary));
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
            const Err(ExchangeUserPreferencesSaveFailure('write failed')),
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
