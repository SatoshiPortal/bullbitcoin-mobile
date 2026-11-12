import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap_server.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/swap_server_setting_repository.dart';
import 'package:bb_mobile/core/swaps/swap_engine_switcher.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/swap/domain/swap_failure.dart';
import 'package:bb_mobile/features/swap/domain/usecases/set_swap_server_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSwapServerSettingRepository extends Mock
    implements SwapServerSettingRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockSwapEngineSwitcher extends Mock implements SwapEngineSwitcher {}

void main() {
  late _MockSwapServerSettingRepository serverSettings;
  late _MockSettingsRepository settingsRepository;
  late _MockSwapEngineSwitcher switcher;
  late SetSwapServerUsecase usecase;

  setUpAll(() => registerFallbackValue(SwapServer.mainnetDefault));

  void stubEnvironment(Environment environment) =>
      when(() => settingsRepository.fetch()).thenAnswer(
        (_) async => SettingsEntity(
          environment: environment,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
        ),
      );

  setUp(() {
    serverSettings = _MockSwapServerSettingRepository();
    settingsRepository = _MockSettingsRepository();
    switcher = _MockSwapEngineSwitcher();
    when(
      () => serverSettings.save(any(), isTestnet: any(named: 'isTestnet')),
    ).thenAnswer((_) async {});
    when(
      () => switcher.rebuild(isTestnet: any(named: 'isTestnet')),
    ).thenAnswer((_) async {});
    stubEnvironment(Environment.mainnet);
    usecase = SetSwapServerUsecase(
      swapServerSettingRepository: serverSettings,
      settingsRepository: settingsRepository,
      swapEngineSwitcher: switcher,
    );
  });

  SwapFailure? failureOf(Result<SwapServer, SwapFailure> result) =>
      switch (result) {
        Ok() => null,
        Err(:final failure) => failure,
      };

  test('stores a valid server and moves the engine onto it', () async {
    final result = await usecase.execute('https://boltz.example.com/v2');

    expect(failureOf(result), isNull);
    final saved = verify(
      () => serverSettings.save(captureAny(), isTestnet: false),
    ).captured.single;
    expect((saved as SwapServer).host, 'boltz.example.com/v2');
    verify(() => switcher.rebuild(isTestnet: false)).called(1);
  });

  test('stores a testnet server under testnet', () async {
    stubEnvironment(Environment.testnet);

    final result = await usecase.execute('boltz.example.com/v2');

    expect(failureOf(result), isNull);
    verify(() => serverSettings.save(any(), isTestnet: true)).called(1);
    verify(() => switcher.rebuild(isTestnet: true)).called(1);
  });

  test('refuses an address it cannot parse', () async {
    final result = await usecase.execute('not a host');

    expect(failureOf(result), isA<SwapValidationFailure>());
    verifyNever(
      () => serverSettings.save(any(), isTestnet: any(named: 'isTestnet')),
    );
    verifyNever(() => switcher.rebuild(isTestnet: any(named: 'isTestnet')));
  });

  test('refuses a plaintext server on mainnet', () async {
    final result = await usecase.execute('http://10.0.2.2:9001/v2');

    expect(failureOf(result), isA<SwapValidationFailure>());
    verifyNever(
      () => serverSettings.save(any(), isTestnet: any(named: 'isTestnet')),
    );
  });

  test('allows a plaintext server on testnet', () async {
    stubEnvironment(Environment.testnet);

    final result = await usecase.execute('http://10.0.2.2:9001/v2');

    expect(failureOf(result), isNull);
  });

  test('a failed write is a storage failure and leaves the engine', () async {
    when(
      () => serverSettings.save(any(), isTestnet: any(named: 'isTestnet')),
    ).thenThrow(const SwapServerSettingException());

    final result = await usecase.execute('boltz.example.com/v2');

    expect(failureOf(result), isA<SwapStorageFailure>());
    verifyNever(() => switcher.rebuild(isTestnet: any(named: 'isTestnet')));
  });
}
