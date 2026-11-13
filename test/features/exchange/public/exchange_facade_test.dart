import 'package:bb_mobile/features/exchange/domain/usecases/resolve_exchange_access_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/enable_exchange_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/sign_out_exchange_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/watch_exchange_access_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/guard_exchange_trading_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_exchange_account_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/save_exchange_preferences_usecase.dart';
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetExchangeAccountUsecase extends Mock
    implements GetExchangeAccountUsecase {}

class _MockSaveExchangePreferencesUsecase extends Mock
    implements SaveExchangePreferencesUsecase {}

class _Resolve extends Mock implements ResolveExchangeAccessUsecase {}

class _Enable extends Mock implements EnableExchangeUsecase {}

class _SignOut extends Mock implements SignOutExchangeUsecase {}

class _Watch extends Mock implements WatchExchangeAccessUsecase {}

class _Guard extends Mock implements GuardExchangeTradingUsecase {}

void main() {
  late _MockGetExchangeAccountUsecase getAccount;
  late _MockSaveExchangePreferencesUsecase savePreferences;
  late ExchangeFacade facade;

  setUp(() {
    getAccount = _MockGetExchangeAccountUsecase();
    savePreferences = _MockSaveExchangePreferencesUsecase();
    facade = ExchangeFacade(
      getExchangeAccountUsecase: getAccount,
      saveExchangePreferencesUsecase: savePreferences,
      resolveAccess: _Resolve(),
      enable: _Enable(),
      signOut: _SignOut(),
      watchAccess: _Watch(),
      tradingGuard: _Guard(),
    );
  });

  test('publishes account details without returning the core entity', () async {
    const summary = UserSummary(
      userNumber: 42,
      userId: 'internal-id',
      groups: [
        'KYC_LIGHT_VERIFICATION',
        'RESTRICTED_FULL',
        'CONSENT_SCAM_WARNING',
        'internal-group',
      ],
      profile: UserProfile(firstName: 'Alice', lastName: 'Smith'),
      email: 'alice@example.com',
      balances: [],
      language: 'EN',
      currency: 'CAD',
      dca: UserDca(isActive: false),
      autoBuy: UserAutoBuy(isActive: false, addresses: UserAutoBuyAddresses()),
      emailNotificationsEnabled: false,
      payjoinReceiveEnabled: true,
    );
    when(getAccount.execute).thenAnswer((_) async => const Ok(summary));

    final result = await facade.getAccount();

    switch (result) {
      case Ok(:final value):
        expect(value, isA<ExchangeAccount>());
        expect(value, isNot(isA<UserSummary>()));
        expect(value.userNumber, 42);
        expect(value.firstName, 'Alice');
        expect(value.lastName, 'Smith');
        expect(value.email, 'alice@example.com');
        expect(value.language, 'EN');
        expect(value.currency, 'CAD');
        expect(value.emailNotificationsEnabled, isFalse);
        expect(value.isFullyVerifiedKycLevel, isFalse);
        expect(value.isLightKycLevel, isTrue);
        expect(value.isLimitedKycLevel, isFalse);
        expect(value.isFundingRestricted, isTrue);
        expect(value.hasConsentedScamWarning, isTrue);
        expect(value.payjoinReceiveEnabled, isTrue);
      case Err(:final failure):
        fail('Expected an account, got $failure');
    }
  });

  test('keeps signed-out distinct from an unavailable account', () async {
    for (final failure in const <ExchangeFailure>[
      ExchangeNotAuthenticatedFailure(),
      ExchangeNetworkFailure(),
      ExchangeAccountUnavailableFailure(),
    ]) {
      when(getAccount.execute).thenAnswer((_) async => Err(failure));

      final result = await facade.getAccount();

      switch (result) {
        case Err(failure: final actual):
          expect(actual, same(failure));
        case Ok():
          fail('Expected the account failure to be preserved');
      }
    }
  });

  test('saves only the preferences the caller passes', () async {
    when(
      () => savePreferences.execute(
        language: 'FR',
        currency: 'EUR',
        emailNotificationsEnabled: true,
      ),
    ).thenAnswer((_) async => const Ok(null));

    final result = await facade.savePreferences(
      language: 'FR',
      currency: 'EUR',
      emailNotificationsEnabled: true,
    );

    expect(result, isA<Ok<void, ExchangeFailure>>());
    verify(
      () => savePreferences.execute(
        language: 'FR',
        currency: 'EUR',
        emailNotificationsEnabled: true,
      ),
    ).called(1);
  });
}
