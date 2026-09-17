import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/settings/domain/settings_store_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_bitcoin_unit_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_currency_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_environment_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_error_reporting_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_exchange_testnet_basic_auth_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_hide_amounts_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_is_dev_mode_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_is_superuser_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_language_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_screen_capture_protection_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_theme_mode_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// What the repository boundary already sanitized it to. If a use-case ever
/// widened this — or let the core family through — the assertions below fail.
const _sanitized = SettingsStoreWriteFailure('setCurrency failed: _Exception');

class _MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(BitcoinUnit.btc);
    registerFallbackValue(Language.unitedStatesEnglish);
    registerFallbackValue(Environment.mainnet);
    registerFallbackValue(AppThemeMode.system);
  });

  late _MockSettingsRepository repository;

  setUp(() => repository = _MockSettingsRepository());

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
      final failure = (result as Err).failure as SettingsFailure;

      expect(failure, isA<SettingsStorageFailure>(), reason: name);
      expect(
        failure,
        isNot(isA<SettingsStoreFailure>()),
        reason: 'the core family must not escape into the cubit',
      );
      expect(failure.logMessage, _sanitized.logMessage);
    });
  }

  expectsLift(
    'setBitcoinUnit',
    () => when(
      () => repository.setBitcoinUnit(any()),
    ).thenAnswer((_) async => const Err(_sanitized)),
    () => SetBitcoinUnitUsecase(
      settingsRepository: repository,
    ).execute(BitcoinUnit.sats),
  );

  expectsLift(
    'setLanguage',
    () => when(
      () => repository.setLanguage(any()),
    ).thenAnswer((_) async => const Err(_sanitized)),
    () => SetLanguageUsecase(
      settingsRepository: repository,
    ).execute(Language.unitedStatesEnglish),
  );

  expectsLift(
    'setCurrency',
    () => when(
      () => repository.setCurrency(any()),
    ).thenAnswer((_) async => const Err(_sanitized)),
    () => SetCurrencyUsecase(settingsRepository: repository).execute('CAD'),
  );

  expectsLift(
    'setEnvironment',
    () => when(
      () => repository.setEnvironment(any()),
    ).thenAnswer((_) async => const Err(_sanitized)),
    () => SetEnvironmentUsecase(
      settingsRepository: repository,
    ).execute(Environment.testnet),
  );

  expectsLift(
    'setThemeMode',
    () => when(
      () => repository.setThemeMode(any()),
    ).thenAnswer((_) async => const Err(_sanitized)),
    () => SetThemeModeUsecase(
      settingsRepository: repository,
    ).execute(AppThemeMode.dark),
  );

  expectsLift(
    'setHideAmounts',
    () => when(
      () => repository.setHideAmounts(any()),
    ).thenAnswer((_) async => const Err(_sanitized)),
    () => SetHideAmountsUsecase(settingsRepository: repository).execute(true),
  );

  expectsLift(
    'setIsSuperuser',
    () => when(
      () => repository.setIsSuperuser(any()),
    ).thenAnswer((_) async => const Err(_sanitized)),
    () => SetIsSuperuserUsecase(settingsRepository: repository).execute(true),
  );

  expectsLift(
    'setIsDevMode',
    () => when(
      () => repository.setIsDevMode(any()),
    ).thenAnswer((_) async => const Err(_sanitized)),
    () => SetIsDevModeUsecase(settingsRepository: repository).execute(true),
  );

  expectsLift(
    'setErrorReportingEnabled',
    () => when(
      () => repository.setErrorReportingEnabled(any()),
    ).thenAnswer((_) async => const Err(_sanitized)),
    () =>
        SetErrorReportingUsecase(settingsRepository: repository).execute(true),
  );

  expectsLift(
    'setScreenCaptureProtectionEnabled',
    () => when(
      () => repository.setScreenCaptureProtectionEnabled(any()),
    ).thenAnswer((_) async => const Err(_sanitized)),
    () => SetScreenCaptureProtectionUsecase(
      settingsRepository: repository,
    ).execute(false),
  );

  expectsLift(
    'setExchangeTestnetBasicAuth',
    () => when(
      () => repository.setExchangeTestnetBasicAuth(
        username: any(named: 'username'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => const Err(_sanitized)),
    () => SetExchangeTestnetBasicAuthUsecase(
      settingsRepository: repository,
    ).execute(username: 'u', password: 'p'),
  );

  test('a successful write is forwarded as Ok', () async {
    when(
      () => repository.setCurrency(any()),
    ).thenAnswer((_) async => const Ok(null));

    expect(
      await SetCurrencyUsecase(settingsRepository: repository).execute('EUR'),
      isA<Ok<void, SettingsFailure>>(),
    );
  });
}
