import 'package:bb_mobile/core/swaps/domain/entity/swap_server.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/swap/domain/entities/swap_route.dart';
import 'package:bb_mobile/features/swap/domain/swap_failure.dart';
import 'package:bb_mobile/features/swap/domain/usecases/get_swap_route_settings_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/get_swap_server_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/set_swap_exchange_fallback_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/set_swap_route_override_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/set_swap_server_usecase.dart';
import 'package:bb_mobile/features/swap/presentation/swap_settings_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetSwapRouteSettingsUsecase extends Mock
    implements GetSwapRouteSettingsUsecase {}

class _MockSetSwapExchangeFallbackUsecase extends Mock
    implements SetSwapExchangeFallbackUsecase {}

class _MockSetSwapRouteOverrideUsecase extends Mock
    implements SetSwapRouteOverrideUsecase {}

class _MockGetSwapServerUsecase extends Mock implements GetSwapServerUsecase {}

class _MockSetSwapServerUsecase extends Mock implements SetSwapServerUsecase {}

void main() {
  late _MockGetSwapRouteSettingsUsecase getSettings;
  late _MockSetSwapExchangeFallbackUsecase setFallback;
  late _MockSetSwapRouteOverrideUsecase setOverride;
  late _MockGetSwapServerUsecase getServer;
  late _MockSetSwapServerUsecase setServer;

  setUpAll(() => registerFallbackValue(SwapRouteOverride.auto));

  setUp(() {
    getSettings = _MockGetSwapRouteSettingsUsecase();
    setFallback = _MockSetSwapExchangeFallbackUsecase();
    setOverride = _MockSetSwapRouteOverrideUsecase();
    getServer = _MockGetSwapServerUsecase();
    setServer = _MockSetSwapServerUsecase();
    when(() => getServer.execute()).thenAnswer(
      (_) async => (server: SwapServer.mainnetDefault, isTestnet: false),
    );
    when(() => getSettings.execute()).thenAnswer(
      (_) async => const Ok((
        exchangeFallbackEnabled: false,
        override: SwapRouteOverride.auto,
        devModeEnabled: true,
      )),
    );
    when(
      () => setFallback.execute(any()),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => setOverride.execute(any()),
    ).thenAnswer((_) async => const Ok(null));
  });

  SwapSettingsCubit build() => SwapSettingsCubit(
    getSwapRouteSettingsUsecase: getSettings,
    setSwapExchangeFallbackUsecase: setFallback,
    setSwapRouteOverrideUsecase: setOverride,
    getSwapServerUsecase: getServer,
    setSwapServerUsecase: setServer,
  );

  test('loads the stored choices', () async {
    final cubit = build();
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.loaded, isTrue);
    expect(cubit.state.exchangeFallbackEnabled, isFalse);
    expect(cubit.state.routeOverride, SwapRouteOverride.auto);
    expect(cubit.state.devModeEnabled, isTrue);
  });

  test('nothing is written before the stored choices are known', () async {
    when(
      () => getSettings.execute(),
    ).thenAnswer((_) async => const Err(SwapStorageFailure()));
    final cubit = build();
    addTearDown(cubit.close);

    await cubit.load();
    await cubit.setExchangeFallbackEnabled(true);

    expect(cubit.state.loaded, isFalse);
    expect(cubit.state.failure, isA<SwapStorageFailure>());
    verifyNever(() => setFallback.execute(any()));
  });

  test('turning the fallback on persists it', () async {
    final cubit = build();
    addTearDown(cubit.close);
    await cubit.load();

    await cubit.setExchangeFallbackEnabled(true);

    verify(() => setFallback.execute(true)).called(1);
    expect(cubit.state.exchangeFallbackEnabled, isTrue);
    expect(cubit.state.saving, isFalse);
  });

  test('a failed write keeps the previous value and reports it', () async {
    when(
      () => setFallback.execute(any()),
    ).thenAnswer((_) async => const Err(SwapStorageFailure()));
    final cubit = build();
    addTearDown(cubit.close);
    await cubit.load();

    await cubit.setExchangeFallbackEnabled(true);

    expect(cubit.state.exchangeFallbackEnabled, isFalse);
    expect(cubit.state.failure, isA<SwapStorageFailure>());
  });

  test('pins the swap provider', () async {
    final cubit = build();
    addTearDown(cubit.close);
    await cubit.load();

    await cubit.setRouteOverride(SwapRouteOverride.exchangeOnly);

    verify(() => setOverride.execute(SwapRouteOverride.exchangeOnly)).called(1);
    expect(cubit.state.routeOverride, SwapRouteOverride.exchangeOnly);
  });

  test('loads and stores the swap server', () async {
    final custom = SwapServer.parse('boltz.example.com/v2', isTestnet: false);
    when(
      () => setServer.execute(any()),
    ).thenAnswer((_) async => Ok(custom ?? SwapServer.mainnetDefault));
    final cubit = build();
    addTearDown(cubit.close);
    await cubit.load();
    expect(cubit.state.swapServer, SwapServer.mainnetDefault);

    expect(await cubit.setSwapServer('boltz.example.com/v2'), isNull);

    expect(cubit.state.swapServer, custom);
    expect(cubit.state.isDefaultSwapServer, isFalse);
  });

  test('marks the testnet default as the default on testnet', () async {
    when(() => getServer.execute()).thenAnswer(
      (_) async => (server: SwapServer.testnetDefault, isTestnet: true),
    );
    final cubit = build();
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.isDefaultSwapServer, isTrue);
  });

  test('an invalid server is returned to the editor, not reported', () async {
    when(() => setServer.execute(any())).thenAnswer(
      (_) async => const Err(SwapValidationFailure(field: 'server')),
    );
    final cubit = build();
    addTearDown(cubit.close);
    await cubit.load();

    final invalid = await cubit.setSwapServer('not a host');

    expect(invalid, isA<SwapValidationFailure>());
    expect(cubit.state.failure, isNull);
    expect(cubit.state.swapServer, SwapServer.mainnetDefault);
  });
}
