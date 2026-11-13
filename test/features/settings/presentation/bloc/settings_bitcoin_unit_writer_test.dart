import 'dart:async';

import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_bitcoin_unit_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_currency_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/sync_exchange_currency_usecase.dart';
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
import 'package:bb_mobile/features/settings/domain/usecases/check_sp_wallet_setup_for_settings_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/revoke_sp_wallet_for_settings_usecase.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetSettingsUsecase extends Mock implements GetSettingsUsecase {}

class _MockSetEnvironmentUsecase extends Mock
    implements SetEnvironmentUsecase {}

class _MockSetBitcoinUnitUsecase extends Mock
    implements SetBitcoinUnitUsecase {}

class _MockSetLanguageUsecase extends Mock implements SetLanguageUsecase {}

class _MockSetCurrencyUsecase extends Mock implements SetCurrencyUsecase {}

class _MockSyncExchangeCurrencyUsecase extends Mock
    implements SyncExchangeCurrencyUsecase {}

class _MockSetHideAmountsUsecase extends Mock
    implements SetHideAmountsUsecase {}

class _MockSetIsSuperuserUsecase extends Mock
    implements SetIsSuperuserUsecase {}

class _MockSetIsDevModeUsecase extends Mock implements SetIsDevModeUsecase {}

class _MockSetThemeModeUsecase extends Mock implements SetThemeModeUsecase {}

class _MockRevokeSpWalletForSettingsUsecase extends Mock
    implements RevokeSpWalletForSettingsUsecase {}

class _MockCheckSpWalletSetupForSettingsUsecase extends Mock
    implements CheckSpWalletSetupForSettingsUsecase {}

class _MockSetErrorReportingUsecase extends Mock
    implements SetErrorReportingUsecase {}

class _MockSetScreenCaptureProtectionUsecase extends Mock
    implements SetScreenCaptureProtectionUsecase {}

class _MockSetExchangeTestnetBasicAuthUsecase extends Mock
    implements SetExchangeTestnetBasicAuthUsecase {}

class _MockSetPayjoinEnabledUsecase extends Mock
    implements SetPayjoinEnabledUsecase {}

class _MockSetPayjoinMinAmountUsecase extends Mock
    implements SetPayjoinMinAmountUsecase {}

class _MockSetPayjoinExpireAfterSecUsecase extends Mock
    implements SetPayjoinExpireAfterSecUsecase {}

class _MockWatchPayjoinPolicyUsecase extends Mock
    implements WatchPayjoinPolicyUsecase {}

class _TestSettingsCubit extends SettingsCubit {
  _TestSettingsCubit({
    required super.getSettingsUsecase,
    required super.setEnvironmentUsecase,
    required super.setBitcoinUnitUsecase,
    required super.setLanguageUsecase,
    required super.setCurrencyUsecase,
    required super.syncExchangeCurrencyUsecase,
    required super.setHideAmountsUsecase,
    required super.setIsSuperuserUsecase,
    required super.setIsDevModeUsecase,
    required super.setThemeModeUsecase,
    required super.revokeSpWalletUsecase,
    required super.checkSpWalletSetupUsecase,
    required super.setErrorReportingUsecase,
    required super.setScreenCaptureProtectionUsecase,
    required super.setExchangeTestnetBasicAuthUsecase,
    required super.setPayjoinEnabledUsecase,
    required super.watchPayjoinPolicyUsecase,
    required super.setPayjoinMinAmountUsecase,
    required super.setPayjoinExpireAfterSecUsecase,
  });

  void seed(SettingsEntity settings, PayjoinPolicy policy) {
    emit(SettingsState(storedSettings: settings, payjoinPolicy: policy));
  }
}

void main() {
  setUpAll(() => registerFallbackValue(BitcoinUnit.btc));

  late StreamController<PayjoinPolicy> changes;
  late _MockSetPayjoinEnabledUsecase setPayjoinEnabled;
  late _MockSetBitcoinUnitUsecase setBitcoinUnit;
  late _MockSetScreenCaptureProtectionUsecase setScreenCapture;
  late _TestSettingsCubit cubit;

  setUp(() {
    changes = StreamController<PayjoinPolicy>.broadcast();
    setPayjoinEnabled = _MockSetPayjoinEnabledUsecase();
    setBitcoinUnit = _MockSetBitcoinUnitUsecase();
    setScreenCapture = _MockSetScreenCaptureProtectionUsecase();
    final watchChanges = _MockWatchPayjoinPolicyUsecase();
    when(() => watchChanges.execute()).thenAnswer((_) => changes.stream);
    cubit = _TestSettingsCubit(
      getSettingsUsecase: _MockGetSettingsUsecase(),
      setEnvironmentUsecase: _MockSetEnvironmentUsecase(),
      setBitcoinUnitUsecase: setBitcoinUnit,
      setLanguageUsecase: _MockSetLanguageUsecase(),
      setCurrencyUsecase: _MockSetCurrencyUsecase(),
      syncExchangeCurrencyUsecase: _MockSyncExchangeCurrencyUsecase(),
      setHideAmountsUsecase: _MockSetHideAmountsUsecase(),
      setIsSuperuserUsecase: _MockSetIsSuperuserUsecase(),
      setIsDevModeUsecase: _MockSetIsDevModeUsecase(),
      setThemeModeUsecase: _MockSetThemeModeUsecase(),
      revokeSpWalletUsecase: _MockRevokeSpWalletForSettingsUsecase(),
      checkSpWalletSetupUsecase: _MockCheckSpWalletSetupForSettingsUsecase(),
      setErrorReportingUsecase: _MockSetErrorReportingUsecase(),
      setScreenCaptureProtectionUsecase: setScreenCapture,
      setExchangeTestnetBasicAuthUsecase:
          _MockSetExchangeTestnetBasicAuthUsecase(),
      setPayjoinEnabledUsecase: setPayjoinEnabled,
      watchPayjoinPolicyUsecase: watchChanges,
      setPayjoinMinAmountUsecase: _MockSetPayjoinMinAmountUsecase(),
      setPayjoinExpireAfterSecUsecase: _MockSetPayjoinExpireAfterSecUsecase(),
    );
    cubit.seed(
      const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
      ),
      PayjoinPolicy.defaults().copyWith(receiveEnabled: true),
    );
  });

  tearDown(() async {
    await cubit.close();
    await changes.close();
  });

  test('writer returns the original failure without emitting it', () async {
    const failure = SettingsStorageFailure();
    const result = Err<void, SettingsFailure>(failure);
    when(
      () => setBitcoinUnit.execute(BitcoinUnit.sats),
    ).thenAnswer((_) async => result);
    expect(await cubit.setBitcoinUnit(BitcoinUnit.sats), same(result));
    expect(cubit.state.failure, isNull);
    expect(cubit.state.bitcoinUnit, BitcoinUnit.sats);
    await cubit.toggleSatsUnit(true);
    expect(cubit.state.failure, same(failure));
  });

  test('writer preserves settings changed during persistence', () async {
    final pending = Completer<Result<void, SettingsFailure>>();
    when(
      () => setBitcoinUnit.execute(BitcoinUnit.btc),
    ).thenAnswer((_) => pending.future);
    final write = cubit.setBitcoinUnit(BitcoinUnit.btc);
    cubit.seed(
      const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      ),
      PayjoinPolicy.defaults(),
    );
    pending.complete(const Ok<void, SettingsFailure>(null));
    expect(await write, isA<Ok<void, SettingsFailure>>());
    expect(cubit.state.bitcoinUnit, BitcoinUnit.btc);
    expect(cubit.state.currencyCode, 'CAD');
  });
}
