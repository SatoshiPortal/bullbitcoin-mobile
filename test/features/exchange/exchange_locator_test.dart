import 'package:bb_mobile/features/exchange/domain/repositories/exchange_access_repository.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/guard_exchange_trading_usecase.dart';
import 'package:bb_mobile/features/exchange/exchange_locator.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';

class _Preferences extends Mock implements Preferences {}

class _Access extends Mock implements ExchangeAccessRepository {}

void main() {
  late GetIt locator;
  late _Preferences preferences;

  Future<void> setUpPlatform(ExchangePlatform platform) async {
    locator = GetIt.asNewInstance();
    addTearDown(locator.reset);
    preferences = _Preferences();
    locator.registerSingleton<Preferences>(preferences);
    ExchangeLocator.setup(locator, platform: platform);
    await locator.unregister<ExchangeAccessRepository>();
    final access = _Access();
    when(
      () => access.current,
    ).thenReturn(const ExchangeAccessEnabled(ExchangeAccessSession.signedOut));
    locator.registerSingleton<ExchangeAccessRepository>(access);
  }

  test('unreadable iOS preferences hide trading without failing', () async {
    await setUpPlatform(ExchangePlatform.ios);
    when(preferences.fetch)
        .thenAnswer((_) async => const Err(PreferencesReadFailure()));

    final result = await locator<GuardExchangeTradingUsecase>().execute();

    expect(
      result,
      isA<Ok<ExchangeAvailability, ExchangeFailure>>().having(
        (ok) => ok.value,
        'availability',
        ExchangeAvailability.hidden,
      ),
    );
  });

  test('the non-iOS platform check does not read preferences', () async {
    await setUpPlatform(ExchangePlatform.other);

    final result = await locator<GuardExchangeTradingUsecase>().execute();

    expect(
      result,
      isA<Ok<ExchangeAvailability, ExchangeFailure>>().having(
        (ok) => ok.value,
        'availability',
        ExchangeAvailability.signInRequired,
      ),
    );
    verifyZeroInteractions(preferences);
  });

  test('the iOS superuser override still allows trading sign-in', () async {
    await setUpPlatform(ExchangePlatform.ios);
    when(preferences.fetch).thenAnswer(
      (_) async => const Ok(
        SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.btc,
          currencyCode: 'CAD',
          isSuperuser: true,
        ),
      ),
    );

    final result = await locator<GuardExchangeTradingUsecase>().execute();

    expect(
      result,
      isA<Ok<ExchangeAvailability, ExchangeFailure>>().having(
        (ok) => ok.value,
        'availability',
        ExchangeAvailability.signInRequired,
      ),
    );
  });
}
