import 'package:bb_mobile/core/ark/usecases/revoke_ark_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/settings/domain/usecases/revoke_sp_wallet_for_settings_usecase.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/get_old_seeds_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_bitcoin_unit_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_error_reporting_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_currency_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_environment_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_hide_amounts_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_is_dev_mode_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_exchange_testnet_basic_auth_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_is_superuser_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_language_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_theme_mode_usecase.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:package_info_plus/package_info_plus.dart';

part 'settings_cubit.freezed.dart';
part 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({
    required this._getSettingsUsecase,
    required this._setEnvironmentUsecase,
    required this._setBitcoinUnitUsecase,
    required this._setLanguageUsecase,
    required this._setCurrencyUsecase,
    required this._setHideAmountsUsecase,
    required this._setIsSuperuserUsecase,
    required this._setIsDevModeUsecase,
    required this._setThemeModeUsecase,
    required this._getOldSeedsUsecase,
    required this._revokeArkUsecase,
    required this._revokeSpWalletUsecase,
    required this._setErrorReportingUsecase,
    required this._setExchangeTestnetBasicAuthUsecase,
  }) : super(const SettingsState());

  final SetEnvironmentUsecase _setEnvironmentUsecase;
  final GetSettingsUsecase _getSettingsUsecase;
  final SetBitcoinUnitUsecase _setBitcoinUnitUsecase;
  final SetLanguageUsecase _setLanguageUsecase;
  final SetCurrencyUsecase _setCurrencyUsecase;
  final SetHideAmountsUsecase _setHideAmountsUsecase;
  final SetIsSuperuserUsecase _setIsSuperuserUsecase;
  final SetThemeModeUsecase _setThemeModeUsecase;
  final GetOldSeedsUsecase _getOldSeedsUsecase;
  final SetIsDevModeUsecase _setIsDevModeUsecase;
  final RevokeArkUsecase _revokeArkUsecase;
  final RevokeSpWalletForSettingsUsecase _revokeSpWalletUsecase;
  final SetErrorReportingUsecase _setErrorReportingUsecase;
  final SetExchangeTestnetBasicAuthUsecase _setExchangeTestnetBasicAuthUsecase;

  Future<void> init() async {
    final (storedSettings, appInfo) = await (
      _getSettingsUsecase.execute(),
      PackageInfo.fromPlatform(),
    ).wait;
    final appVersion = '${appInfo.version}+${appInfo.buildNumber}';

    emit(
      state.copyWith(storedSettings: storedSettings, appVersion: appVersion),
    );
    await checkHasLegacySeeds();
  }

  Future<void> toggleTestnetMode(bool active) async {
    final settings = state.storedSettings;
    log.config(
      'Testnet mode toggled: $active was ${settings?.environment.name}',
    );
    final environment = active ? Environment.testnet : Environment.mainnet;
    await _setEnvironmentUsecase.execute(environment);
    emit(
      state.copyWith(
        storedSettings: settings?.copyWith(environment: environment),
      ),
    );
  }

  Future<void> toggleSatsUnit(bool active) async {
    final settings = state.storedSettings;
    log.config(
      'Bitcoin unit toggled: $active was ${settings?.bitcoinUnit.name}',
    );
    final unit = active ? BitcoinUnit.sats : BitcoinUnit.btc;
    await _setBitcoinUnitUsecase.execute(unit);
    emit(state.copyWith(storedSettings: settings?.copyWith(bitcoinUnit: unit)));
  }

  Future<void> changeLanguage(Language language) async {
    final settings = state.storedSettings;
    log.config(
      'Language changed to: ${language.label} was ${settings?.language?.label}',
    );
    await _setLanguageUsecase.execute(language);
    emit(
      state.copyWith(storedSettings: settings?.copyWith(language: language)),
    );
  }

  Future<void> changeCurrency(String currencyCode) async {
    final settings = state.storedSettings;
    log.config(
      'Currency changed to: $currencyCode was ${settings?.currencyCode}',
    );
    await _setCurrencyUsecase.execute(currencyCode);
    emit(
      state.copyWith(
        storedSettings: settings?.copyWith(currencyCode: currencyCode),
      ),
    );
  }

  Future<void> toggleHideAmounts(bool hide) async {
    final settings = state.storedSettings;
    log.config('Hide amounts toggled: $hide was ${settings?.hideAmounts}');
    await _setHideAmountsUsecase.execute(hide);
    emit(state.copyWith(storedSettings: settings?.copyWith(hideAmounts: hide)));
  }

  Future<void> toggleSuperuserMode(bool active) async {
    final settings = state.storedSettings;
    log.config('Superuser mode toggled: $active was ${settings?.isSuperuser}');
    await _setIsSuperuserUsecase.execute(active);
    emit(
      state.copyWith(storedSettings: settings?.copyWith(isSuperuser: active)),
    );
  }

  Future<void> changeThemeMode(AppThemeMode themeMode) async {
    final settings = state.storedSettings;
    log.info(
      'Theme mode changed to: ${themeMode.name} + currentThemeMode: ${settings?.themeMode.name}',
    );
    await _setThemeModeUsecase.execute(themeMode);
    emit(
      state.copyWith(storedSettings: settings?.copyWith(themeMode: themeMode)),
    );
  }

  Future<void> checkHasLegacySeeds() async {
    final seeds = await _getOldSeedsUsecase.execute();
    emit(state.copyWith(hasLegacySeeds: seeds.isNotEmpty));
  }

  Future<void> toggleDevMode(bool isEnabled, {WalletBloc? walletBloc}) async {
    final settings = state.storedSettings;

    // Clear any previously surfaced SP revoke failure whenever the user
    // re-toggles dev mode; they're acknowledging / retrying.
    var revokeSpFailed = false;

    // If disabling dev mode, revoke Ark and SP first
    if (!isEnabled && settings?.isDevModeEnabled == true) {
      try {
        await _revokeArkUsecase.execute();
        // Only trigger refresh if walletBloc is provided
        walletBloc?.add(const RefreshArkWalletBalance());
      } catch (e) {
        log.severe(
          message: 'Failed to revoke Ark',
          error: e,
          trace: StackTrace.current,
        );
      }
      try {
        // The revoke use case disposes the live session, deletes the wallet,
        // and emits SpSetupChanged; the WalletBloc observes that and refreshes
        // itself, so settings never drives the wallet for SP.
        await _revokeSpWalletUsecase.execute();
      } catch (e) {
        // RevokeSpWalletUsecase writes a `.revoked` sentinel BEFORE attempting
        // the recursive delete, so even if delete failed the partial state is
        // no longer dangerous: GetSpWalletUsecase refuses to load any wallet
        // from a sentinel-marked directory. It also emits SpSetupChanged on the
        // failure path, so the wallet still drops the SP card. Therefore it is
        // safe to flip dev-mode off below; we flag the failure so the UI can
        // show a generic retry prompt. The raw cause stays in the log only.
        log.severe(
          message: 'Failed to revoke SP wallet (sentinel left in place)',
          error: e,
          trace: StackTrace.current,
        );
        revokeSpFailed = true;
      }
    }

    await _setIsDevModeUsecase.execute(isEnabled);
    emit(
      state.copyWith(
        storedSettings: settings?.copyWith(isDevModeEnabled: isEnabled),
        revokeSpFailed: revokeSpFailed,
      ),
    );
  }

  Future<void> setExchangeTestnetBasicAuth({
    String? username,
    String? password,
  }) async {
    final settings = state.storedSettings;
    final trimmedUsername = username?.trim();
    final trimmedPassword = password?.trim();
    final user = (trimmedUsername?.isEmpty ?? true) ? null : trimmedUsername;
    final pass = (trimmedPassword?.isEmpty ?? true) ? null : trimmedPassword;
    await _setExchangeTestnetBasicAuthUsecase.execute(
      username: user,
      password: pass,
    );
    emit(
      state.copyWith(
        storedSettings: settings?.copyWith(
          exchangeTestnetBasicAuthUsername: user,
          exchangeTestnetBasicAuthPassword: pass,
        ),
      ),
    );
  }

  Future<void> toggleErrorReporting(bool enabled) async {
    final settings = state.storedSettings;
    log.config(
      'Error reporting toggled: $enabled was ${settings?.isErrorReportingEnabled}',
    );
    await _setErrorReportingUsecase.execute(enabled);
    emit(
      state.copyWith(
        storedSettings: settings?.copyWith(isErrorReportingEnabled: enabled),
      ),
    );
  }
}
