import 'package:bb_mobile/features/exchange/domain/usecases/resolve_exchange_access_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/enable_exchange_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/sign_out_exchange_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/watch_exchange_access_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/guard_exchange_trading_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSaveExchangePreferencesUsecase extends Mock
    implements SaveExchangePreferencesUsecase {}

class _Resolve extends Mock implements ResolveExchangeAccessUsecase {}

class _Enable extends Mock implements EnableExchangeUsecase {}

class _SignOut extends Mock implements SignOutExchangeUsecase {}

class _Watch extends Mock implements WatchExchangeAccessUsecase {}

class _Guard extends Mock implements GuardExchangeTradingUsecase {}

class _MockWebSettings extends Mock implements GetExchangeWebSettingsUsecase {}

void main() {
  late _MockSaveExchangePreferencesUsecase savePreferences;
  late ExchangeFacade facade;
  late _MockWebSettings webSettings;

  setUp(() {
    savePreferences = _MockSaveExchangePreferencesUsecase();
    webSettings = _MockWebSettings();
    facade = ExchangeFacade(
      loadWebPreferences: webSettings.execute,
      saveAccountPreferences: savePreferences.execute,
      resolveAccess: _Resolve(),
      enable: _Enable(),
      signOut: _SignOut(),
      watchAccess: _Watch(),
      tradingGuard: _Guard(),
    );
  });

  test('only unsupported networks redirect exchange entry', () async {
    when(
      webSettings.execute,
    ).thenAnswer((_) async => const Err(ExchangeUnsupportedNetworkFailure()));
    expect(await facade.networkUnavailable(), isTrue);
    when(webSettings.execute)
        .thenAnswer((_) async => const Err(ExchangeUnexpectedFailure()));
    expect(await facade.networkUnavailable(), isFalse);
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
