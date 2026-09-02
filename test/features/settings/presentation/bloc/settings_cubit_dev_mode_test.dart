import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/settings/domain/usecases/check_sp_wallet_setup_for_settings_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/revoke_sp_wallet_for_settings_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_bitcoin_unit_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_currency_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_environment_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_error_reporting_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_exchange_testnet_basic_auth_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_hide_amounts_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_is_dev_mode_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_is_superuser_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_language_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_payjoin_enabled_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_payjoin_expire_after_sec_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_payjoin_min_amount_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_screen_capture_protection_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_theme_mode_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/watch_payjoin_policy_usecase.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetSettingsUsecase extends Mock implements GetSettingsUsecase {}

class _MockSetEnvironmentUsecase extends Mock
    implements SetEnvironmentUsecase {}

class _MockSetBitcoinUnitUsecase extends Mock
    implements SetBitcoinUnitUsecase {}

class _MockSetLanguageUsecase extends Mock implements SetLanguageUsecase {}

class _MockSetCurrencyUsecase extends Mock implements SetCurrencyUsecase {}

class _MockSetHideAmountsUsecase extends Mock
    implements SetHideAmountsUsecase {}

class _MockSetIsSuperuserUsecase extends Mock
    implements SetIsSuperuserUsecase {}

class _MockSetIsDevModeUsecase extends Mock implements SetIsDevModeUsecase {}

class _MockSetThemeModeUsecase extends Mock implements SetThemeModeUsecase {}

class _MockSetScreenCaptureProtectionUsecase extends Mock
    implements SetScreenCaptureProtectionUsecase {}

class _MockSetPayjoinEnabledUsecase extends Mock
    implements SetPayjoinEnabledUsecase {}

class _MockWatchPayjoinPolicyUsecase extends Mock
    implements WatchPayjoinPolicyUsecase {}

class _MockSetPayjoinMinAmountUsecase extends Mock
    implements SetPayjoinMinAmountUsecase {}

class _MockSetPayjoinExpireAfterSecUsecase extends Mock
    implements SetPayjoinExpireAfterSecUsecase {}

class _MockRevokeSpWalletUsecase extends Mock
    implements RevokeSpWalletForSettingsUsecase {}

class _MockCheckSpWalletSetupUsecase extends Mock
    implements CheckSpWalletSetupForSettingsUsecase {}

class _MockSetErrorReportingUsecase extends Mock
    implements SetErrorReportingUsecase {}

class _MockSetExchangeTestnetBasicAuthUsecase extends Mock
    implements SetExchangeTestnetBasicAuthUsecase {}

SettingsEntity _settings({bool isDevModeEnabled = true}) => SettingsEntity(
  environment: Environment.mainnet,
  bitcoinUnit: BitcoinUnit.sats,
  currencyCode: 'USD',
  isSuperuser: true,
  isDevModeEnabled: isDevModeEnabled,
);

void main() {
  late _MockSetIsDevModeUsecase setIsDevModeUsecase;
  late _MockRevokeSpWalletUsecase revokeSpWalletUsecase;
  late _MockCheckSpWalletSetupUsecase checkSpWalletSetupUsecase;
  late SettingsCubit cubit;

  setUp(() {
    setIsDevModeUsecase = _MockSetIsDevModeUsecase();
    revokeSpWalletUsecase = _MockRevokeSpWalletUsecase();
    checkSpWalletSetupUsecase = _MockCheckSpWalletSetupUsecase();

    when(() => setIsDevModeUsecase.execute(any())).thenAnswer((_) async {});
    when(
      () => revokeSpWalletUsecase.execute(),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => checkSpWalletSetupUsecase.execute(),
    ).thenAnswer((_) async => Ok(false));

    final watchPayjoinPolicyUsecase = _MockWatchPayjoinPolicyUsecase();
    when(
      () => watchPayjoinPolicyUsecase.execute(),
    ).thenAnswer((_) => const Stream<PayjoinPolicy>.empty());

    cubit = SettingsCubit(
      getSettingsUsecase: _MockGetSettingsUsecase(),
      setEnvironmentUsecase: _MockSetEnvironmentUsecase(),
      setBitcoinUnitUsecase: _MockSetBitcoinUnitUsecase(),
      setLanguageUsecase: _MockSetLanguageUsecase(),
      setCurrencyUsecase: _MockSetCurrencyUsecase(),
      setHideAmountsUsecase: _MockSetHideAmountsUsecase(),
      setIsSuperuserUsecase: _MockSetIsSuperuserUsecase(),
      setIsDevModeUsecase: setIsDevModeUsecase,
      setThemeModeUsecase: _MockSetThemeModeUsecase(),
      revokeSpWalletUsecase: revokeSpWalletUsecase,
      checkSpWalletSetupUsecase: checkSpWalletSetupUsecase,
      setErrorReportingUsecase: _MockSetErrorReportingUsecase(),
      setScreenCaptureProtectionUsecase:
          _MockSetScreenCaptureProtectionUsecase(),
      setExchangeTestnetBasicAuthUsecase:
          _MockSetExchangeTestnetBasicAuthUsecase(),
      setPayjoinEnabledUsecase: _MockSetPayjoinEnabledUsecase(),
      watchPayjoinPolicyUsecase: watchPayjoinPolicyUsecase,
      setPayjoinMinAmountUsecase: _MockSetPayjoinMinAmountUsecase(),
      setPayjoinExpireAfterSecUsecase: _MockSetPayjoinExpireAfterSecUsecase(),
    );
  });

  tearDown(() => cubit.close());

  group('toggleDevMode', () {
    test(
      'dev-mode true -> false revokes the SP wallet; the wallet feature picks '
      'the change up from SpSetupChanged, settings never drives it',
      () async {
        // Seed cubit state with dev mode currently enabled.
        cubit.emit(
          cubit.state.copyWith(
            storedSettings: _settings(isDevModeEnabled: true),
          ),
        );

        await cubit.toggleDevMode(false);

        verify(() => revokeSpWalletUsecase.execute()).called(1);
        verify(() => setIsDevModeUsecase.execute(false)).called(1);
        expect(cubit.state.storedSettings?.isDevModeEnabled, false);
      },
    );

    test(
      'dev-mode false -> true does NOT call RevokeSpWalletUsecase',
      () async {
        cubit.emit(
          cubit.state.copyWith(
            storedSettings: _settings(isDevModeEnabled: false),
          ),
        );

        await cubit.toggleDevMode(true);

        verifyNever(() => revokeSpWalletUsecase.execute());
        verify(() => setIsDevModeUsecase.execute(true)).called(1);
        expect(cubit.state.storedSettings?.isDevModeEnabled, true);
      },
    );

    test(
      'dev-mode toggle-off keeps dev mode enabled when revoke fails',
      () async {
        when(
          () => revokeSpWalletUsecase.execute(),
        ).thenAnswer((_) async => const Err(SpUnexpected('file locked')));
        cubit.emit(
          cubit.state.copyWith(
            storedSettings: _settings(isDevModeEnabled: true),
          ),
        );

        await cubit.toggleDevMode(false);

        verify(() => revokeSpWalletUsecase.execute()).called(1);
        verifyNever(() => setIsDevModeUsecase.execute(false));
        expect(cubit.state.storedSettings?.isDevModeEnabled, true);
        expect(cubit.state.revokeSpFailed, isTrue);
      },
    );

    test(
      'successful toggle-off clears any previously-set revokeSpFailed',
      () async {
        // Seed state with a stale failure flag from a previous attempt.
        cubit.emit(
          cubit.state.copyWith(
            storedSettings: _settings(isDevModeEnabled: true),
            revokeSpFailed: true,
          ),
        );

        await cubit.toggleDevMode(false);

        verify(() => revokeSpWalletUsecase.execute()).called(1);
        expect(cubit.state.storedSettings?.isDevModeEnabled, false);
        expect(cubit.state.revokeSpFailed, isFalse);
      },
    );
  });
}
