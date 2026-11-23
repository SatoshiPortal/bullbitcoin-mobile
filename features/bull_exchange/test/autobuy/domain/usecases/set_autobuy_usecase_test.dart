import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:bull_exchange/src/autobuy/domain/autobuy_failure.dart';
import 'package:bull_exchange/src/autobuy/domain/usecases/set_autobuy_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetExchangeUserSummaryUsecase extends Mock
    implements _SummaryReader {}

abstract interface class _SummaryReader {
  Future<Result<UserSummary, ExchangeFailure>> execute();
}

abstract interface class _PreferenceWriter {
  Future<Result<void, ExchangeFailure>> saveUserPreference({
    String? language,
    String? currency,
    bool? dcaEnabled,
    String? autoBuyEnabled,
    bool? emailNotificationsEnabled,
  });
}

abstract interface class _DefaultWalletReader {
  Future<Result<DefaultWallets, ExchangeFailure>> execute();
}

class MockGetDefaultWalletsUsecase extends Mock
    implements _DefaultWalletReader {}

class MockExchangeUserRepository extends Mock implements _PreferenceWriter {}

class MockSettingsRepository extends Mock implements Preferences {}

UserSummary _summaryWithGroups(List<String> groups) => UserSummary(
  userNumber: 1,
  groups: groups,
  profile: const UserProfile(firstName: 'Satoshi', lastName: 'Nakamoto'),
  email: 'satoshi@example.com',
  balances: const [],
  language: 'FR',
  currency: 'CAD',
  dca: const UserDca(isActive: true),
  autoBuy: const UserAutoBuy(
    isActive: false,
    addresses: UserAutoBuyAddresses(),
  ),
  emailNotificationsEnabled: false,
);

final _summary = _summaryWithGroups(['KYC_IDENTITY_VERIFIED']);
final _restrictedSummary = _summaryWithGroups([
  'KYC_IDENTITY_VERIFIED',
  'RESTRICTED_FULL',
]);

const _wallets = DefaultWallets(
  bitcoin: DefaultWallet(
    recipientId: 'r1',
    walletType: WalletAddressType.bitcoin,
    address: 'bc1qexample',
    isDefault: true,
  ),
);

const _noWallets = DefaultWallets();

void main() {
  late MockGetExchangeUserSummaryUsecase getUserSummary;
  late MockGetDefaultWalletsUsecase getDefaultWallets;
  // The mainnet repository, which the settings below select.
  late MockExchangeUserRepository savePreferences;
  late MockExchangeUserRepository testnetUsers;
  late MockSettingsRepository settings;
  late SetAutoBuyUsecase usecase;

  void stubSaveSucceeds() {
    when(
      () => savePreferences.saveUserPreference(
        language: any(named: 'language'),
        currency: any(named: 'currency'),
        dcaEnabled: any(named: 'dcaEnabled'),
        autoBuyEnabled: any(named: 'autoBuyEnabled'),
        emailNotificationsEnabled: any(named: 'emailNotificationsEnabled'),
      ),
    ).thenAnswer((_) async => const Ok(null));
  }

  setUp(() {
    getUserSummary = MockGetExchangeUserSummaryUsecase();
    getDefaultWallets = MockGetDefaultWalletsUsecase();
    savePreferences = MockExchangeUserRepository();
    testnetUsers = MockExchangeUserRepository();
    settings = MockSettingsRepository();
    when(() => settings.fetch()).thenAnswer(
      (_) async => Ok(
        const SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
        ),
      ),
    );
    usecase = SetAutoBuyUsecase(
      settings,
      exchangeForTesting(
        getUserSummary: (_) => getUserSummary.execute(),
        getDefaultWallets: getDefaultWallets.execute,
        saveUserPreference:
            (
              environment, {
              language,
              currency,
              dcaEnabled,
              autoBuyEnabled,
              emailNotificationsEnabled,
            }) =>
                (environment == ExchangeEnvironment.mainnet
                        ? savePreferences
                        : testnetUsers)
                    .saveUserPreference(
                      language: language,
                      currency: currency,
                      dcaEnabled: dcaEnabled,
                      autoBuyEnabled: autoBuyEnabled,
                      emailNotificationsEnabled: emailNotificationsEnabled,
                    ),
      ),
    );
  });

  test('regtest refuses AutoBuy before account or wallet access', () async {
    when(() => settings.fetch()).thenAnswer(
      (_) async => Ok(
        const SettingsEntity(
          environment: Environment.regtest,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
        ),
      ),
    );
    when(() => getDefaultWallets.execute())
        .thenAnswer((_) async => const Ok(_wallets));
    when(() => getUserSummary.execute()).thenAnswer((_) async => Ok(_summary));
    stubSaveSucceeds();

    for (final enabled in [true, false]) {
      expect(
        await usecase.execute(enabled: enabled),
        isA<Err<void, AutoBuyFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<AutoBuyUnsupportedNetworkFailure>(),
        ),
      );
    }
    verifyZeroInteractions(getDefaultWallets);
    verifyZeroInteractions(getUserSummary);
    verifyZeroInteractions(savePreferences);
    verifyZeroInteractions(testnetUsers);
  });

  test('requires a default wallet before enabling AutoBuy', () async {
    when(() => getDefaultWallets.execute())
        .thenAnswer((_) async => const Ok(_noWallets));

    final result = await usecase.execute(enabled: true);

    expect(
      (result as Err<void, AutoBuyFailure>).failure,
      isA<AutoBuyWalletRequiredFailure>(),
    );
    verifyZeroInteractions(getUserSummary);
    verifyZeroInteractions(savePreferences);
  });

  test(
    'reads the current default wallets instead of trusting the caller',
    () async {
      when(() => getDefaultWallets.execute())
          .thenAnswer((_) async => const Ok(_wallets));
      when(() => getUserSummary.execute())
          .thenAnswer((_) async => Ok(_summary));
      stubSaveSucceeds();

      final result = await usecase.execute(enabled: true);

      expect(result, isA<Ok<void, AutoBuyFailure>>());
      verify(() => getDefaultWallets.execute()).called(1);
    },
  );

  test('does not read the default wallets when disabling AutoBuy', () async {
    when(() => getUserSummary.execute()).thenAnswer((_) async => Ok(_summary));
    stubSaveSucceeds();

    final result = await usecase.execute(enabled: false);

    expect(result, isA<Ok<void, AutoBuyFailure>>());
    verifyZeroInteractions(getDefaultWallets);
  });

  test('refuses to enable AutoBuy on a funding-restricted account', () async {
    when(() => getDefaultWallets.execute())
        .thenAnswer((_) async => const Ok(_wallets));
    when(() => getUserSummary.execute())
        .thenAnswer((_) async => Ok(_restrictedSummary));

    final result = await usecase.execute(enabled: true);

    expect(
      (result as Err<void, AutoBuyFailure>).failure,
      isA<AutoBuyFundingRestrictedFailure>(),
    );
    verifyZeroInteractions(savePreferences);
  });

  test('still allows disabling AutoBuy on a restricted account', () async {
    when(() => getUserSummary.execute())
        .thenAnswer((_) async => Ok(_restrictedSummary));
    stubSaveSucceeds();

    final result = await usecase.execute(enabled: false);

    expect(result, isA<Ok<void, AutoBuyFailure>>());
    verify(
      () => savePreferences.saveUserPreference(
        language: 'FR',
        currency: 'CAD',
        dcaEnabled: true,
        autoBuyEnabled: 'false',
        emailNotificationsEnabled: false,
      ),
    ).called(1);
  });

  test('preserves the existing preferences when enabling AutoBuy', () async {
    when(() => getDefaultWallets.execute())
        .thenAnswer((_) async => const Ok(_wallets));
    when(() => getUserSummary.execute()).thenAnswer((_) async => Ok(_summary));
    stubSaveSucceeds();

    final result = await usecase.execute(enabled: true);

    expect(result, isA<Ok<void, AutoBuyFailure>>());
    verify(
      () => savePreferences.saveUserPreference(
        language: 'FR',
        currency: 'CAD',
        dcaEnabled: true,
        autoBuyEnabled: 'true',
        emailNotificationsEnabled: false,
      ),
    ).called(1);
  });

  test('maps an unreadable default wallet list to the catch-all', () async {
    when(() => getDefaultWallets.execute())
        .thenAnswer((_) async => const Err(ExchangeNetworkFailure()));

    final result = await usecase.execute(enabled: true);

    expect(
      (result as Err<void, AutoBuyFailure>).failure,
      isA<AutoBuyUnexpectedFailure>(),
    );
    verifyZeroInteractions(savePreferences);
  });

  test('maps an unavailable account to a typed failure', () async {
    when(() => getDefaultWallets.execute())
        .thenAnswer((_) async => const Ok(_wallets));
    when(() => getUserSummary.execute())
        .thenAnswer((_) async => const Err(ExchangeNotAuthenticatedFailure()));

    final result = await usecase.execute(enabled: true);

    expect(
      (result as Err<void, AutoBuyFailure>).failure,
      isA<AutoBuyAccountUnavailableFailure>(),
    );
    verifyZeroInteractions(savePreferences);
  });

  test('maps a failed account query to an unavailable account', () async {
    when(() => getDefaultWallets.execute())
        .thenAnswer((_) async => const Ok(_wallets));
    when(() => getUserSummary.execute())
        .thenAnswer((_) async => const Err(ExchangeNetworkFailure()));

    final result = await usecase.execute(enabled: true);

    expect(
      (result as Err<void, AutoBuyFailure>).failure,
      isA<AutoBuyAccountUnavailableFailure>(),
    );
    verifyZeroInteractions(savePreferences);
  });

  test('maps a rejected preference update to a typed failure', () async {
    when(() => getUserSummary.execute()).thenAnswer((_) async => Ok(_summary));
    when(
      () => savePreferences.saveUserPreference(
        language: any(named: 'language'),
        currency: any(named: 'currency'),
        dcaEnabled: any(named: 'dcaEnabled'),
        autoBuyEnabled: any(named: 'autoBuyEnabled'),
        emailNotificationsEnabled: any(named: 'emailNotificationsEnabled'),
      ),
    ).thenAnswer((_) async => const Err(ExchangePreferencesSaveFailure()));

    final result = await usecase.execute(enabled: false);

    expect(
      (result as Err<void, AutoBuyFailure>).failure,
      isA<AutoBuyPreferenceUpdateFailure>(),
    );
  });

  test('does not convert programmer errors into recoverable failures', () {
    when(() => getDefaultWallets.execute()).thenThrow(StateError('bug'));

    expect(() => usecase.execute(enabled: true), throwsStateError);
  });
}
