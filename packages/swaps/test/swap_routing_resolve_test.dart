import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:swaps/swaps.dart';
import 'package:swaps/src/domain/repositories/swap_route_setting_repository.dart';
import 'package:swaps/src/domain/swap_routing.dart';
import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSwapRouteSettingRepository extends Mock
    implements SwapRouteSettingRepository {}

class _MockSettingsRepository extends Mock implements Preferences {}

class _MockSettingsEntity extends Mock implements SettingsEntity {}

void main() {
  late _MockSwapRouteSettingRepository routeSettings;
  late _MockSettingsRepository settingsRepository;
  late _MockSettingsEntity settings;
  late SwapRouting routing;

  void stubRoute({
    required Result<bool, SwapsFailure> fallback,
    required Result<SwapRouteOverride, SwapsFailure> override,
  }) {
    when(() => routeSettings.isExchangeFallbackEnabled())
        .thenAnswer((_) async => fallback);
    when(() => routeSettings.getRouteOverride())
        .thenAnswer((_) async => override);
  }

  setUp(() {
    routeSettings = _MockSwapRouteSettingRepository();
    settingsRepository = _MockSettingsRepository();
    settings = _MockSettingsEntity();
    when(() => settingsRepository.fetch())
        .thenAnswer((_) async => Ok(settings));
    when(() => settings.isDevModeEnabled).thenReturn(false);
    routing = StoredSwapRouting(routeSettings, settingsRepository);
  });

  test('routes to Boltz with the fallback the user turned on', () async {
    stubRoute(
      fallback: const Ok(true),
      override: const Ok(SwapRouteOverride.auto),
    );

    expect(await routing.resolveRoute(), SwapRoute.boltzWithExchangeFallback);
  });

  test('applies the dev override only in dev mode', () async {
    stubRoute(
      fallback: const Ok(false),
      override: const Ok(SwapRouteOverride.exchangeOnly),
    );

    expect(await routing.resolveRoute(), SwapRoute.boltz);

    when(() => settings.isDevModeEnabled).thenReturn(true);
    expect(await routing.resolveRoute(), SwapRoute.exchange);
  });

  test('unreadable settings keep swaps on Boltz without fallback', () async {
    stubRoute(
      fallback: const Err(SwapsStorageFailure()),
      override: const Err(SwapsStorageFailure()),
    );
    when(() => settingsRepository.fetch()).thenThrow(Exception('locked'));

    expect(await routing.resolveRoute(), SwapRoute.boltz);
  });
}
