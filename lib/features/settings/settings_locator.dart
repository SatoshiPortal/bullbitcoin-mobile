import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/features/settings/data/payjoin_disclaimer_repository_impl.dart';
import 'package:bb_mobile/features/settings/domain/repositories/payjoin_disclaimer_repository.dart';
import 'package:bb_mobile/features/settings/domain/usecases/get_payjoin_disclaimer_shown_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/get_wallet_registration_options_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/export_signing_key_usecase.dart';
import 'package:bb_mobile/features/settings/domain/signing_key_account_session.dart';
import 'package:bb_mobile/features/settings/domain/usecases/release_signing_key_account_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/get_wallet_policy_usecase.dart';
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
import 'package:bb_mobile/features/settings/domain/usecases/set_screen_capture_protection_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_payjoin_enabled_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_payjoin_expire_after_sec_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_payjoin_min_amount_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_theme_mode_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/watch_payjoin_policy_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/update_wallet_signer_device_usecase.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/signing_key_export_cubit.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/wallet_details_cubit.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/wallet_registration_cubit.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:bb_mobile/features/settings/public/settings_entry_registry.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:get_it/get_it.dart';

class SettingsLocator {
  static void setup(GetIt locator) {
    locator.registerLazySingleton(SettingsEntryRegistry.new);
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

    locator.registerFactory<SetScreenCaptureProtectionUsecase>(
      () => SetScreenCaptureProtectionUsecase(
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
    locator.registerFactory<GetWalletPolicyUsecase>(
      () => GetWalletPolicyUsecase(bitcoinSigningPort: locator()),
    );
    locator.registerFactory<UpdateWalletSignerDeviceUsecase>(
      () => UpdateWalletSignerDeviceUsecase(walletSignerDevicePort: locator()),
    );
    locator.registerFactory<GetWalletRegistrationOptionsUsecase>(
      () => GetWalletRegistrationOptionsUsecase(bitcoinSigningPort: locator()),
    );

    locator.registerLazySingleton<SettingsFacade>(
      () => SettingsFacade(
        setPayjoinEnabledUsecase: locator<SetPayjoinEnabledUsecase>(),
        watchPayjoinPolicyUsecase: locator<WatchPayjoinPolicyUsecase>(),
        entryRegistry: locator<SettingsEntryRegistry>(),
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
    locator.registerFactory<SigningKeyExportCubit>(() {
      final accountSession = SigningKeyAccountSession(locator());
      return SigningKeyExportCubit(
        exportSigningKeyUsecase: ExportSigningKeyUsecase(
          accountSession,
          getDefaultSeedUsecase: locator(),
          getSettingsUsecase: locator(),
        ),
        releaseSigningKeyAccountUsecase: ReleaseSigningKeyAccountUsecase(
          accountSession,
        ),
      );
    });
    locator.registerFactory<WalletDetailsCubit>(
      () => WalletDetailsCubit(
        getWalletPolicyUsecase: locator(),
        updateWalletSignerDeviceUsecase: locator(),
      ),
    );
    locator.registerFactory<WalletRegistrationCubit>(
      () => WalletRegistrationCubit(locator()),
    );
  }
}
