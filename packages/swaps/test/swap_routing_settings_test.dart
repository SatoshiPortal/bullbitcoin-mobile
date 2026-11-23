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

  setUp(() {
    routeSettings = _MockSwapRouteSettingRepository();
    settingsRepository = _MockSettingsRepository();
    settings = _MockSettingsEntity();
    when(() => routeSettings.isExchangeFallbackEnabled())
        .thenAnswer((_) async => const Ok(true));
    when(() => routeSettings.getRouteOverride())
        .thenAnswer((_) async => const Ok(SwapRouteOverride.boltzOnly));
    when(() => settingsRepository.fetch())
        .thenAnswer((_) async => Ok(settings));
    when(() => settings.isDevModeEnabled).thenReturn(true);
    routing = StoredSwapRouting(routeSettings, settingsRepository);
  });

  test('returns the stored choices and whether dev mode is on', () async {
    final result = await routing.readRouteSettings();

    expect(
      switch (result) {
        Ok(:final value) => value,
        Err() => null,
      },
      (
        exchangeFallbackEnabled: true,
        override: SwapRouteOverride.boltzOnly,
        devModeEnabled: true,
      ),
    );
  });

  test('an unreadable setting is a failure, not a default', () async {
    when(() => routeSettings.isExchangeFallbackEnabled())
        .thenAnswer((_) async => const Err(SwapsStorageFailure()));

    expect(
      await routing.readRouteSettings(),
      isA<Err<SwapRouteSettings, SwapsFailure>>(),
    );
  });

  test('unreadable app settings hide the developer section', () async {
    when(() => settingsRepository.fetch()).thenThrow(Exception('locked'));

    final result = await routing.readRouteSettings();

    expect(switch (result) {
      Ok(:final value) => value.devModeEnabled,
      Err() => null,
    }, isFalse);
  });
}
