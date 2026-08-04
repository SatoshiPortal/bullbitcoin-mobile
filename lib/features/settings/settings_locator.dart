import 'package:bb_mobile/core/ark/usecases/revoke_ark_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart'
    as domain;
import 'package:bb_mobile/features/settings/data/payjoin_disclaimer_repository_impl.dart';
import 'package:bb_mobile/features/settings/domain/repositories/payjoin_disclaimer_repository.dart';
import 'package:bb_mobile/features/settings/domain/usecases/get_payjoin_disclaimer_shown_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/mark_payjoin_disclaimer_shown_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_bitcoin_unit_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_error_reporting_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_currency_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_environment_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_hide_amounts_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_exchange_testnet_basic_auth_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_is_dev_mode_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_is_superuser_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_language_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_payjoin_enabled_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_payjoin_expire_after_sec_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_payjoin_min_amount_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_theme_mode_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/watch_payjoin_min_amount_changes_usecase.dart';
import 'package:bb_mobile/core/settings/domain/watch_payjoin_enabled_changes_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/disable_payjoin_receivers_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/restore_swaps_usecase.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/swap_restore_cubit.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:get_it/get_it.dart';

class SettingsLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<SwapRestoreCubit>(
      () =>
          SwapRestoreCubit(restoreSwapsUsecase: locator<RestoreSwapsUsecase>()),
    );
    // Usecases
    locator.registerFactory<SetEnvironmentUsecase>(
      () => SetEnvironmentUsecase(
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerFactory<SetBitcoinUnitUsecase>(
      () => SetBitcoinUnitUsecase(
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerFactory<SetLanguageUsecase>(
      () =>
          SetLanguageUsecase(settingsRepository: locator<SettingsRepository>()),
    );
    locator.registerFactory<SetCurrencyUsecase>(
      () =>
          SetCurrencyUsecase(settingsRepository: locator<SettingsRepository>()),
    );
    locator.registerFactory<SetHideAmountsUsecase>(
      () => SetHideAmountsUsecase(
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerFactory<SetIsSuperuserUsecase>(
      () => SetIsSuperuserUsecase(
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerFactory<SetIsDevModeUsecase>(
      () => SetIsDevModeUsecase(
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerFactory<SetThemeModeUsecase>(
      () => SetThemeModeUsecase(
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerFactory<SetErrorReportingUsecase>(
      () => SetErrorReportingUsecase(
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerFactory<SetExchangeTestnetBasicAuthUsecase>(
      () => SetExchangeTestnetBasicAuthUsecase(
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerLazySingleton<PayjoinDisclaimerRepository>(
      PayjoinDisclaimerRepositoryImpl.new,
    );
    locator.registerFactory<GetPayjoinDisclaimerShownUsecase>(
      () => GetPayjoinDisclaimerShownUsecase(
        payjoinDisclaimerRepository: locator<PayjoinDisclaimerRepository>(),
      ),
    );
    locator.registerFactory<MarkPayjoinDisclaimerShownUsecase>(
      () => MarkPayjoinDisclaimerShownUsecase(
        payjoinDisclaimerRepository: locator<PayjoinDisclaimerRepository>(),
      ),
    );
    locator.registerFactory<SetPayjoinEnabledUsecase>(
      () => SetPayjoinEnabledUsecase(
        settingsRepository: locator<domain.SettingsRepository>(),
        getPayjoinDisclaimerShownUsecase:
            locator<GetPayjoinDisclaimerShownUsecase>(),
        markPayjoinDisclaimerShownUsecase:
            locator<MarkPayjoinDisclaimerShownUsecase>(),
        disablePayjoinReceiversUsecase:
            locator<DisablePayjoinReceiversUsecase>(),
      ),
    );
    locator.registerFactory<SetPayjoinMinAmountUsecase>(
      () => SetPayjoinMinAmountUsecase(
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerFactory<SetPayjoinExpireAfterSecUsecase>(
      () => SetPayjoinExpireAfterSecUsecase(
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerFactory<WatchPayjoinMinAmountChangesUsecase>(
      () => WatchPayjoinMinAmountChangesUsecase(
        settingsRepository: locator<domain.SettingsRepository>(),
      ),
    );

    locator.registerLazySingleton<SettingsFacade>(
      () => SettingsFacade(
        setPayjoinEnabledUsecase: locator<SetPayjoinEnabledUsecase>(),
        watchPayjoinMinAmountChangesUsecase:
            locator<WatchPayjoinMinAmountChangesUsecase>(),
      ),
    );

    // Blocs
    locator.registerLazySingleton<SettingsCubit>(
      () => SettingsCubit(
        setEnvironmentUsecase: locator<SetEnvironmentUsecase>(),
        getSettingsUsecase: locator<GetSettingsUsecase>(),
        setBitcoinUnitUsecase: locator<SetBitcoinUnitUsecase>(),
        setLanguageUsecase: locator<SetLanguageUsecase>(),
        setCurrencyUsecase: locator<SetCurrencyUsecase>(),
        setHideAmountsUsecase: locator<SetHideAmountsUsecase>(),
        setIsSuperuserUsecase: locator<SetIsSuperuserUsecase>(),
        setIsDevModeUsecase: locator<SetIsDevModeUsecase>(),
        setThemeModeUsecase: locator<SetThemeModeUsecase>(),
        revokeArkUsecase: locator<RevokeArkUsecase>(),
        setErrorReportingUsecase: locator<SetErrorReportingUsecase>(),
        setExchangeTestnetBasicAuthUsecase:
            locator<SetExchangeTestnetBasicAuthUsecase>(),
        setPayjoinEnabledUsecase: locator<SetPayjoinEnabledUsecase>(),
        watchPayjoinEnabledChangesUsecase:
            locator<WatchPayjoinEnabledChangesUsecase>(),
        setPayjoinMinAmountUsecase: locator<SetPayjoinMinAmountUsecase>(),
        setPayjoinExpireAfterSecUsecase:
            locator<SetPayjoinExpireAfterSecUsecase>(),
      ),
    );
  }
}
