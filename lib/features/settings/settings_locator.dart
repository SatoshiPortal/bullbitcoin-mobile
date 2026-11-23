import 'package:bb_mobile/features/settings/domain/usecases/load_settings_usecase.dart';
import 'package:electrum/setup.dart';

import 'dart:io';

import 'package:bb_mobile/features/settings/domain/usecases/watch_quick_actions_visibility_usecase.dart';
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/settings/data/payjoin_disclaimer_repository_impl.dart';
import 'package:bb_mobile/features/settings/domain/repositories/payjoin_disclaimer_repository.dart';
import 'package:bb_mobile/features/settings/domain/usecases/get_payjoin_disclaimer_shown_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/mark_payjoin_disclaimer_shown_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/check_sp_wallet_setup_for_settings_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/revoke_sp_wallet_for_settings_usecase.dart';
import 'package:bb_mobile/features/sp/public/sp_facade.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_bitcoin_unit_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_error_reporting_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_currency_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_environment_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_hide_amounts_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_exchange_testnet_basic_auth_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_is_dev_mode_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_is_superuser_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_language_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_screen_capture_protection_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_payjoin_enabled_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_payjoin_expire_after_sec_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_payjoin_min_amount_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_theme_mode_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/sync_exchange_currency_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/watch_payjoin_policy_usecase.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/swap_restore_cubit.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:swaps/swaps.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:get_it/get_it.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_amount_input_mode_usecase.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:bb_mobile/features/settings/domain/usecases/discover_wallet_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/get_swap_rescue_wallets_usecase.dart';
import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';
import 'package:bb_mobile/features/settings/presentation/wallet_discovery_cubit.dart';

class SettingsLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<SwapRestoreCubit>(
      () =>
          SwapRestoreCubit(restoreSwapsUsecase: locator<RestoreSwapsUsecase>()),
    );
    locator.registerFactory<GetSwapRescueWalletsUsecase>(
      () => GetSwapRescueWalletsUsecase(
        walletRepository: locator<WalletRepository>(),
        settingsRepository: locator<Preferences>(),
      ),
    );
    locator.registerLazySingleton<QuickActionsCubit>(
      () => createQuickActionsCubit(
        warning: log.warning,
        defaults: Platform.isIOS
            ? QuickActionsLayout.iosDefaults
            : QuickActionsLayout.defaults,
        exchangeVisible: WatchQuickActionsVisibilityUsecase(
          exchange: locator<ExchangeFacade>(),
          settings: locator<Preferences>(),
          isIOS: Platform.isIOS,
          platformChanges: locator<SettingsCubit>().stream
              .where((state) => state.storedSettings != null)
              .map((state) => !Platform.isIOS || state.isSuperuser == true),
        ).execute(),
      ),
      dispose: (cubit) => cubit.close(),
    );
    locator.registerFactory<DiscoverWalletUsecase>(
      () => DiscoverWalletUsecase(locator<WalletFacade>()),
    );
    locator.registerFactory<WalletDiscoveryCubit>(
      () => WalletDiscoveryCubit(locator<DiscoverWalletUsecase>()),
    );
    // Usecases
    locator.registerFactory<SetEnvironmentUsecase>(
      () => SetEnvironmentUsecase(
        settingsRepository: locator<Preferences>(),
        electrumSettings: locator<ElectrumDefaultsProvisioner>(),
      ),
    );
    locator.registerFactory<SetAmountInputModeUsecase>(
      () => SetAmountInputModeUsecase(locator<AmountInputPreferences>()),
    );
    locator.registerFactory<SetBitcoinUnitUsecase>(
      () => SetBitcoinUnitUsecase(settingsRepository: locator<Preferences>()),
    );
    locator.registerFactory<SetLanguageUsecase>(
      () => SetLanguageUsecase(settingsRepository: locator<Preferences>()),
    );
    locator.registerFactory<SyncExchangeCurrencyUsecase>(
      () => SyncExchangeCurrencyUsecase(
        settingsRepository: locator<Preferences>(),
        exchange: locator<Exchange>(),
      ),
    );
    locator.registerFactory<SetCurrencyUsecase>(
      () => SetCurrencyUsecase(settingsRepository: locator<Preferences>()),
    );
    locator.registerFactory<SetHideAmountsUsecase>(
      () => SetHideAmountsUsecase(settingsRepository: locator<Preferences>()),
    );
    locator.registerFactory<SetIsSuperuserUsecase>(
      () => SetIsSuperuserUsecase(settingsRepository: locator<Preferences>()),
    );

    locator.registerFactory<SetIsDevModeUsecase>(
      () => SetIsDevModeUsecase(settingsRepository: locator<Preferences>()),
    );

    locator.registerFactory<SetThemeModeUsecase>(
      () => SetThemeModeUsecase(settingsRepository: locator<Preferences>()),
    );

    locator.registerFactory<SetErrorReportingUsecase>(
      () =>
          SetErrorReportingUsecase(settingsRepository: locator<Preferences>()),
    );

    locator.registerFactory<SetScreenCaptureProtectionUsecase>(
      () => SetScreenCaptureProtectionUsecase(
        settingsRepository: locator<Preferences>(),
      ),
    );

    locator.registerFactory<SetExchangeTestnetBasicAuthUsecase>(
      () => SetExchangeTestnetBasicAuthUsecase(
        preferences: locator<ExchangeTestnetBasicAuthPreferences>(),
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
        payjoinPolicy: locator<PayjoinPolicyAccess>(),
        getPayjoinDisclaimerShownUsecase:
            locator<GetPayjoinDisclaimerShownUsecase>(),
        markPayjoinDisclaimerShownUsecase:
            locator<MarkPayjoinDisclaimerShownUsecase>(),
      ),
    );
    locator.registerFactory<SetPayjoinMinAmountUsecase>(
      () => SetPayjoinMinAmountUsecase(
        payjoinPolicy: locator<PayjoinPolicyAccess>(),
      ),
    );
    locator.registerFactory<SetPayjoinExpireAfterSecUsecase>(
      () => SetPayjoinExpireAfterSecUsecase(
        payjoinPolicy: locator<PayjoinPolicyAccess>(),
      ),
    );
    locator.registerFactory<WatchPayjoinPolicyUsecase>(
      () => WatchPayjoinPolicyUsecase(locator<PayjoinPolicyAccess>()),
    );

    locator.registerLazySingleton<SettingsFacade>(
      () => SettingsFacade(
        setPayjoinEnabledUsecase: locator<SetPayjoinEnabledUsecase>(),
        watchPayjoinPolicyUsecase: locator<WatchPayjoinPolicyUsecase>(),
      ),
    );

    locator.registerFactory<RevokeSpWalletForSettingsUsecase>(
      () => RevokeSpWalletForSettingsUsecase(spFacade: locator<SpFacade>()),
    );

    locator.registerFactory<CheckSpWalletSetupForSettingsUsecase>(
      () => CheckSpWalletSetupForSettingsUsecase(spFacade: locator<SpFacade>()),
    );

    // Blocs
    locator.registerLazySingleton<SettingsCubit>(
      () => SettingsCubit(
        setEnvironmentUsecase: locator<SetEnvironmentUsecase>(),
        loadPreferencesUsecase: LoadSettingsUsecase(locator<Preferences>()),
        setBitcoinUnitUsecase: locator<SetBitcoinUnitUsecase>(),
        setAmountInputModeUsecase: locator<SetAmountInputModeUsecase>(),
        setLanguageUsecase: locator<SetLanguageUsecase>(),
        setCurrencyUsecase: locator<SetCurrencyUsecase>(),
        syncExchangeCurrencyUsecase: locator<SyncExchangeCurrencyUsecase>(),
        setHideAmountsUsecase: locator<SetHideAmountsUsecase>(),
        setIsSuperuserUsecase: locator<SetIsSuperuserUsecase>(),
        setIsDevModeUsecase: locator<SetIsDevModeUsecase>(),
        setThemeModeUsecase: locator<SetThemeModeUsecase>(),
        revokeSpWalletUsecase: locator<RevokeSpWalletForSettingsUsecase>(),
        checkSpWalletSetupUsecase:
            locator<CheckSpWalletSetupForSettingsUsecase>(),
        setErrorReportingUsecase: locator<SetErrorReportingUsecase>(),
        setScreenCaptureProtectionUsecase:
            locator<SetScreenCaptureProtectionUsecase>(),
        setExchangeTestnetBasicAuthUsecase:
            locator<SetExchangeTestnetBasicAuthUsecase>(),
        setPayjoinEnabledUsecase: locator<SetPayjoinEnabledUsecase>(),
        watchPayjoinPolicyUsecase: locator<WatchPayjoinPolicyUsecase>(),
        setPayjoinMinAmountUsecase: locator<SetPayjoinMinAmountUsecase>(),
        setPayjoinExpireAfterSecUsecase:
            locator<SetPayjoinExpireAfterSecUsecase>(),
      ),
    );
  }
}
