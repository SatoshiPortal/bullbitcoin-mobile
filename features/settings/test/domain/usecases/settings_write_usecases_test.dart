import 'package:electrum/setup.dart';

import 'dart:io';

import 'package:bull_logger/bull_logger.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:settings/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// What the repository boundary already sanitized it to. If a use-case ever
/// widened this — or let the core family through — the assertions below fail.
const _sanitized = PreferencesWriteFailure('setCurrency failed: _Exception');

/// The failure an [Err] carries, typed by the [Result]; an [Ok] fails the test.
F _failureOf<T, F extends Failure>(Result<T, F> result) => switch (result) {
  Ok() => fail('expected an Err, got Ok'),
  Err(:final failure) => failure,
};

class _MockSettingsRepository extends Mock implements Preferences {}

class _Electrum extends Mock implements ElectrumDefaultsProvisioner {}

void main() {
  setUpAll(() {
    registerFallbackValue(BitcoinUnit.btc);
    registerFallbackValue(Language.unitedStatesEnglish);
    registerFallbackValue(Environment.mainnet);
    registerFallbackValue(AppThemeMode.system);
  });

  late _MockSettingsRepository repository;

  setUp(() {
    repository = _MockSettingsRepository();
    when(() => repository.fetch()).thenAnswer(
      (_) async => Ok(
        const SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
          isSuperuser: true,
          isDevModeEnabled: true,
        ),
      ),
    );
  });

  test('developer mode persists only a successful settings outcome', () async {
    final directory = await Directory.systemTemp.createTemp('dev-mode-log-');
    log = Logger.replace(directory: directory);
    addTearDown(() async {
      await log.flush();
      await directory.delete(recursive: true);
    });
    when(() => repository.setIsDevMode(any()))
        .thenAnswer((_) async => const Ok(null));
    final usecase = SetIsDevModeUsecase(settingsRepository: repository);
    expect(await usecase.execute(true), isA<Ok>());
    expect(await usecase.execute(false), isA<Ok>());
    when(() => repository.setIsDevMode(any()))
        .thenAnswer((_) async => const Err(_sanitized));
    expect(await usecase.execute(true), isA<Err>());
    expect((await log.readLogs()).map((row) => row.split('\t')[2]), [
      'Developer mode saved enabled=true',
      'Developer mode saved enabled=false network=mainnet',
    ]);
  });

  /// Every write use-case is the same thin lift, so they are proven the same
  /// way: a repository failure must come back as the feature's own family,
  /// carrying the already-sanitized reason and nothing more.
  void expectsLift(
    String name,
    void Function() stubFailure,
    Future<Result<void, SettingsFailure>> Function() run,
  ) {
    test('$name lifts a repository failure into the feature family', () async {
      stubFailure();

      final result = await run();
      final failure = _failureOf(result);

      expect(failure, isA<SettingsStorageFailure>(), reason: name);
      expect(
        failure,
        isNot(isA<PreferencesFailure>()),
        reason: 'the core family must not escape into the cubit',
      );
      expect(
        failure.logMessage,
        name == 'setEnvironment' ? null : _sanitized.logMessage,
      );
    });
  }

  expectsLift(
    'setBitcoinUnit',
    () =>
        when(() => repository.setBitcoinUnit(any()))
            .thenAnswer((_) async => const Err(_sanitized)),
    () =>
        SetBitcoinUnitUsecase(settingsRepository: repository)
            .execute(BitcoinUnit.sats),
  );

  expectsLift(
    'setLanguage',
    () =>
        when(() => repository.setLanguage(any()))
            .thenAnswer((_) async => const Err(_sanitized)),
    () =>
        SetLanguageUsecase(settingsRepository: repository)
            .execute(Language.unitedStatesEnglish),
  );

  expectsLift(
    'setCurrency',
    () =>
        when(() => repository.setCurrency(any()))
            .thenAnswer((_) async => const Err(_sanitized)),
    () => SetCurrencyUsecase(settingsRepository: repository).execute('CAD'),
  );

  expectsLift(
    'setEnvironment',
    () =>
        when(() => repository.setEnvironment(any()))
            .thenAnswer((_) async => const Err(_sanitized)),
    () => SetEnvironmentUsecase(
      settingsRepository: repository,
      electrumSettings: _Electrum(),
    ).execute(Environment.testnet),
  );

  expectsLift(
    'setThemeMode',
    () =>
        when(() => repository.setThemeMode(any()))
            .thenAnswer((_) async => const Err(_sanitized)),
    () =>
        SetThemeModeUsecase(settingsRepository: repository)
            .execute(AppThemeMode.dark),
  );

  expectsLift(
    'setHideAmounts',
    () =>
        when(() => repository.setHideAmounts(any()))
            .thenAnswer((_) async => const Err(_sanitized)),
    () => SetHideAmountsUsecase(settingsRepository: repository).execute(true),
  );

  expectsLift(
    'setIsSuperuser',
    () =>
        when(() => repository.setIsSuperuser(any()))
            .thenAnswer((_) async => const Err(_sanitized)),
    () => SetIsSuperuserUsecase(settingsRepository: repository).execute(true),
  );

  expectsLift(
    'setIsDevMode',
    () =>
        when(() => repository.setIsDevMode(any()))
            .thenAnswer((_) async => const Err(_sanitized)),
    () => SetIsDevModeUsecase(settingsRepository: repository).execute(true),
  );

  expectsLift(
    'setErrorReportingEnabled',
    () =>
        when(() => repository.setErrorReportingEnabled(any()))
            .thenAnswer((_) async => const Err(_sanitized)),
    () =>
        SetErrorReportingUsecase(settingsRepository: repository).execute(true),
  );

  expectsLift(
    'setScreenCaptureProtectionEnabled',
    () =>
        when(() => repository.setScreenCaptureProtectionEnabled(any()))
            .thenAnswer((_) async => const Err(_sanitized)),
    () =>
        SetScreenCaptureProtectionUsecase(settingsRepository: repository)
            .execute(false),
  );

  expectsLift(
    'setShowPaymentAnimations',
    () =>
        when(() => repository.setShowPaymentAnimations(any()))
            .thenAnswer((_) async => const Err(_sanitized)),
    () =>
        SetShowPaymentAnimationsUsecase(settingsRepository: repository)
            .execute(false),
  );

  test('a successful write is forwarded as Ok', () async {
    when(() => repository.setCurrency(any()))
        .thenAnswer((_) async => const Ok(null));

    expect(
      await SetCurrencyUsecase(settingsRepository: repository).execute('EUR'),
      isA<Ok<void, SettingsFailure>>(),
    );
  });
}
