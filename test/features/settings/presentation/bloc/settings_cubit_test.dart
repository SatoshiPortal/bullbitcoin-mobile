import 'dart:async';

import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/settings/domain/watch_payjoin_enabled_changes_usecase.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/get_old_seeds_usecase.dart';
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
import 'package:bb_mobile/features/settings/domain/usecases/set_payjoin_enabled_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_payjoin_expire_after_sec_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_payjoin_min_amount_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_theme_mode_usecase.dart';
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

class _MockGetOldSeedsUsecase extends Mock implements GetOldSeedsUsecase {}

class _MockSetErrorReportingUsecase extends Mock
    implements SetErrorReportingUsecase {}

class _MockSetExchangeTestnetBasicAuthUsecase extends Mock
    implements SetExchangeTestnetBasicAuthUsecase {}

class _MockSetPayjoinEnabledUsecase extends Mock
    implements SetPayjoinEnabledUsecase {}

class _MockSetPayjoinMinAmountUsecase extends Mock
    implements SetPayjoinMinAmountUsecase {}

class _MockSetPayjoinExpireAfterSecUsecase extends Mock
    implements SetPayjoinExpireAfterSecUsecase {}

class _MockWatchPayjoinEnabledChangesUsecase extends Mock
    implements WatchPayjoinEnabledChangesUsecase {}

class _TestSettingsCubit extends SettingsCubit {
  _TestSettingsCubit({
    required super.getSettingsUsecase,
    required super.setEnvironmentUsecase,
    required super.setBitcoinUnitUsecase,
    required super.setLanguageUsecase,
    required super.setCurrencyUsecase,
    required super.setHideAmountsUsecase,
    required super.setIsSuperuserUsecase,
    required super.setIsDevModeUsecase,
    required super.setThemeModeUsecase,
    required super.getOldSeedsUsecase,
    required super.setErrorReportingUsecase,
    required super.setExchangeTestnetBasicAuthUsecase,
    required super.setPayjoinEnabledUsecase,
    required super.watchPayjoinEnabledChangesUsecase,
    required super.setPayjoinMinAmountUsecase,
    required super.setPayjoinExpireAfterSecUsecase,
  });

  void seed(SettingsEntity settings) {
    emit(SettingsState(storedSettings: settings));
  }
}

void main() {
  late StreamController<bool> changes;
  late _MockSetPayjoinEnabledUsecase setPayjoinEnabled;
  late _TestSettingsCubit cubit;

  setUp(() {
    changes = StreamController<bool>.broadcast();
    setPayjoinEnabled = _MockSetPayjoinEnabledUsecase();
    final watchChanges = _MockWatchPayjoinEnabledChangesUsecase();
    when(() => watchChanges.execute()).thenAnswer((_) => changes.stream);
    cubit = _TestSettingsCubit(
      getSettingsUsecase: _MockGetSettingsUsecase(),
      setEnvironmentUsecase: _MockSetEnvironmentUsecase(),
      setBitcoinUnitUsecase: _MockSetBitcoinUnitUsecase(),
      setLanguageUsecase: _MockSetLanguageUsecase(),
      setCurrencyUsecase: _MockSetCurrencyUsecase(),
      setHideAmountsUsecase: _MockSetHideAmountsUsecase(),
      setIsSuperuserUsecase: _MockSetIsSuperuserUsecase(),
      setIsDevModeUsecase: _MockSetIsDevModeUsecase(),
      setThemeModeUsecase: _MockSetThemeModeUsecase(),
      getOldSeedsUsecase: _MockGetOldSeedsUsecase(),
      setErrorReportingUsecase: _MockSetErrorReportingUsecase(),
      setExchangeTestnetBasicAuthUsecase:
          _MockSetExchangeTestnetBasicAuthUsecase(),
      setPayjoinEnabledUsecase: setPayjoinEnabled,
      watchPayjoinEnabledChangesUsecase: watchChanges,
      setPayjoinMinAmountUsecase: _MockSetPayjoinMinAmountUsecase(),
      setPayjoinExpireAfterSecUsecase: _MockSetPayjoinExpireAfterSecUsecase(),
    );
    cubit.seed(
      const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
        isPayjoinEnabled: true,
      ),
    );
  });

  tearDown(() async {
    await cubit.close();
    await changes.close();
  });

  test('a successful disable updates the cubit state to false', () async {
    when(
      () => setPayjoinEnabled.execute(
        false,
        requestConsent: any(named: 'requestConsent'),
      ),
    ).thenAnswer((_) async => const Ok<bool, SettingsFailure>(false));

    await cubit.togglePayjoinEnabled(false, requestConsent: () async => true);

    expect(cubit.state.isPayjoinEnabled, isFalse);
  });

  test('external persisted changes keep the cubit in sync', () async {
    changes.add(false);
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.isPayjoinEnabled, isFalse);
  });
}
