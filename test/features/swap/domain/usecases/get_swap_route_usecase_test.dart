import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/swap/domain/entities/swap_route.dart';
import 'package:bb_mobile/features/swap/domain/repositories/swap_route_setting_repository.dart';
import 'package:bb_mobile/features/swap/domain/swap_failure.dart';
import 'package:bb_mobile/features/swap/domain/usecases/get_swap_route_usecase.dart';
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
  late GetSwapRouteUsecase usecase;

  void stubRoute({
    required Result<bool, SwapFailure> fallback,
    required Result<SwapRouteOverride, SwapFailure> override,
  }) {
    when(
      () => routeSettings.isExchangeFallbackEnabled(),
    ).thenAnswer((_) async => fallback);
    when(
      () => routeSettings.getRouteOverride(),
    ).thenAnswer((_) async => override);
  }

  setUp(() {
    routeSettings = _MockSwapRouteSettingRepository();
    settingsRepository = _MockSettingsRepository();
    settings = _MockSettingsEntity();
    when(() => settingsRepository.fetch()).thenAnswer((_) async => settings);
    when(() => settings.isDevModeEnabled).thenReturn(false);
    usecase = GetSwapRouteUsecase(
      swapRouteSettingRepository: routeSettings,
      settingsRepository: settingsRepository,
    );
  });

  test('routes to Boltz with the fallback the user turned on', () async {
    stubRoute(
      fallback: const Ok(true),
      override: const Ok(SwapRouteOverride.auto),
    );

    expect(await usecase.execute(), SwapRoute.boltzWithExchangeFallback);
  });

  test('applies the dev override only in dev mode', () async {
    stubRoute(
      fallback: const Ok(false),
      override: const Ok(SwapRouteOverride.exchangeOnly),
    );

    expect(await usecase.execute(), SwapRoute.boltz);

    when(() => settings.isDevModeEnabled).thenReturn(true);
    expect(await usecase.execute(), SwapRoute.exchange);
  });

  test('unreadable settings keep swaps on Boltz without fallback', () async {
    stubRoute(
      fallback: const Err(SwapStorageFailure()),
      override: const Err(SwapStorageFailure()),
    );
    when(() => settingsRepository.fetch()).thenThrow(Exception('locked'));

    expect(await usecase.execute(), SwapRoute.boltz);
  });
}
