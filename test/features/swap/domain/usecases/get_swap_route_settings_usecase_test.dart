import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/swap/domain/entities/swap_route.dart';
import 'package:bb_mobile/features/swap/domain/repositories/swap_route_setting_repository.dart';
import 'package:bb_mobile/features/swap/domain/swap_failure.dart';
import 'package:bb_mobile/features/swap/domain/usecases/get_swap_route_settings_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSwapRouteSettingRepository extends Mock
    implements SwapRouteSettingRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockSettingsEntity extends Mock implements SettingsEntity {}

void main() {
  late _MockSwapRouteSettingRepository routeSettings;
  late _MockSettingsRepository settingsRepository;
  late _MockSettingsEntity settings;
  late GetSwapRouteSettingsUsecase usecase;

  setUp(() {
    routeSettings = _MockSwapRouteSettingRepository();
    settingsRepository = _MockSettingsRepository();
    settings = _MockSettingsEntity();
    when(
      () => routeSettings.isExchangeFallbackEnabled(),
    ).thenAnswer((_) async => const Ok(true));
    when(
      () => routeSettings.getRouteOverride(),
    ).thenAnswer((_) async => const Ok(SwapRouteOverride.boltzOnly));
    when(() => settingsRepository.fetch()).thenAnswer((_) async => settings);
    when(() => settings.isDevModeEnabled).thenReturn(true);
    usecase = GetSwapRouteSettingsUsecase(
      swapRouteSettingRepository: routeSettings,
      settingsRepository: settingsRepository,
    );
  });

  test('returns the stored choices and whether dev mode is on', () async {
    final result = await usecase.execute();

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
    when(
      () => routeSettings.isExchangeFallbackEnabled(),
    ).thenAnswer((_) async => const Err(SwapStorageFailure()));

    expect(await usecase.execute(), isA<Err<SwapRouteSettings, SwapFailure>>());
  });

  test('unreadable app settings hide the developer section', () async {
    when(() => settingsRepository.fetch()).thenThrow(Exception('locked'));

    final result = await usecase.execute();

    expect(switch (result) {
      Ok(:final value) => value.devModeEnabled,
      Err() => null,
    }, isFalse);
  });
}
