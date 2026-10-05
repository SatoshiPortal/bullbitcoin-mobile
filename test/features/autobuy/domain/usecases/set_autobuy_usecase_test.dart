import 'package:bb_mobile/core/exchange/domain/entity/default_wallet.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_default_wallets_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_user_failure.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_user_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/autobuy/domain/autobuy_failure.dart';
import 'package:bb_mobile/features/autobuy/domain/usecases/set_autobuy_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetExchangeUserSummaryUsecase extends Mock
    implements GetExchangeUserSummaryUsecase {}

class MockGetDefaultWalletsUsecase extends Mock
    implements GetDefaultWalletsUsecase {}

class MockExchangeUserRepository extends Mock
    implements ExchangeUserRepository {}

class MockSettingsRepository extends Mock implements SettingsRepository {}

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
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      ),
    );
    usecase = SetAutoBuyUsecase(
      getUserSummary,
      getDefaultWallets,
      settings,
      savePreferences,
      testnetUsers,
    );
  });

  test('requires a default wallet before enabling AutoBuy', () async {
    when(() => getDefaultWallets.execute()).thenAnswer((_) async => _noWallets);

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
      when(() => getDefaultWallets.execute()).thenAnswer((_) async => _wallets);
      when(() => getUserSummary.execute()).thenAnswer((_) async => _summary);
      stubSaveSucceeds();

      final result = await usecase.execute(enabled: true);

      expect(result, isA<Ok<void, AutoBuyFailure>>());
      verify(() => getDefaultWallets.execute()).called(1);
    },
  );

  test('does not read the default wallets when disabling AutoBuy', () async {
    when(() => getUserSummary.execute()).thenAnswer((_) async => _summary);
    stubSaveSucceeds();

    final result = await usecase.execute(enabled: false);

    expect(result, isA<Ok<void, AutoBuyFailure>>());
    verifyZeroInteractions(getDefaultWallets);
  });

  test('refuses to enable AutoBuy on a funding-restricted account', () async {
    when(() => getDefaultWallets.execute()).thenAnswer((_) async => _wallets);
    when(
      () => getUserSummary.execute(),
    ).thenAnswer((_) async => _restrictedSummary);

    final result = await usecase.execute(enabled: true);

    expect(
      (result as Err<void, AutoBuyFailure>).failure,
      isA<AutoBuyFundingRestrictedFailure>(),
    );
    verifyZeroInteractions(savePreferences);
  });

  test('still allows disabling AutoBuy on a restricted account', () async {
    when(
      () => getUserSummary.execute(),
    ).thenAnswer((_) async => _restrictedSummary);
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
    when(() => getDefaultWallets.execute()).thenAnswer((_) async => _wallets);
    when(() => getUserSummary.execute()).thenAnswer((_) async => _summary);
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
    when(
      () => getDefaultWallets.execute(),
    ).thenThrow(Exception('recipient request failed'));

    final result = await usecase.execute(enabled: true);

    expect(
      (result as Err<void, AutoBuyFailure>).failure,
      isA<AutoBuyUnexpectedFailure>(),
    );
    verifyZeroInteractions(savePreferences);
  });

  test('maps an unavailable account to a typed failure', () async {
    when(() => getDefaultWallets.execute()).thenAnswer((_) async => _wallets);
    when(
      () => getUserSummary.execute(),
    ).thenThrow(GetExchangeUserSummaryException('account request failed'));

    final result = await usecase.execute(enabled: true);

    expect(
      (result as Err<void, AutoBuyFailure>).failure,
      isA<AutoBuyAccountUnavailableFailure>(),
    );
    verifyZeroInteractions(savePreferences);
  });

  test('maps an unclassified account error to the catch-all', () async {
    when(() => getDefaultWallets.execute()).thenAnswer((_) async => _wallets);
    when(
      () => getUserSummary.execute(),
    ).thenThrow(Exception('something nobody classified'));

    final result = await usecase.execute(enabled: true);

    expect(
      (result as Err<void, AutoBuyFailure>).failure,
      isA<AutoBuyUnexpectedFailure>(),
    );
    verifyZeroInteractions(savePreferences);
  });

  test('maps a rejected preference update to a typed failure', () async {
    when(() => getUserSummary.execute()).thenAnswer((_) async => _summary);
    when(
      () => savePreferences.saveUserPreference(
        language: any(named: 'language'),
        currency: any(named: 'currency'),
        dcaEnabled: any(named: 'dcaEnabled'),
        autoBuyEnabled: any(named: 'autoBuyEnabled'),
        emailNotificationsEnabled: any(named: 'emailNotificationsEnabled'),
      ),
    ).thenAnswer((_) async => const Err(ExchangeUserPreferencesSaveFailure()));

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
