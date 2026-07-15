import 'package:bb_mobile/core/ark/usecases/revoke_ark_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/settings/domain/update_payjoin_expire_after_sec_usecase.dart';
import 'package:bb_mobile/core/settings/domain/update_payjoin_min_amount_usecase.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/get_old_seeds_usecase.dart';
import 'package:bb_mobile/core/utils/constants.dart' show PayjoinConstants;
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
    required this._setErrorReportingUsecase,
    required this._setExchangeTestnetBasicAuthUsecase,
    required this._updatePayjoinMinAmountUsecase,
    required this._updatePayjoinExpireAfterSecUsecase,
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
  final SetErrorReportingUsecase _setErrorReportingUsecase;
  final SetExchangeTestnetBasicAuthUsecase _setExchangeTestnetBasicAuthUsecase;
  final UpdatePayjoinMinAmountUsecase _updatePayjoinMinAmountUsecase;
  final UpdatePayjoinExpireAfterSecUsecase _updatePayjoinExpireAfterSecUsecase;

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

  Future<void> setPayjoinMinAmount(int amountSat) async {
    await _updatePayjoinMinAmountUsecase.execute(
      payjoinMinAmountSat: amountSat,
    );
    final settings = state.storedSettings;
    emit(
      state.copyWith(
        storedSettings: settings?.copyWith(payjoinMinAmountSat: amountSat),
      ),
    );
  }

  /// Encapsulates the enabled/disabled sentinel (see
  /// [SettingsEntity.isPayjoinEnabled]) so callers never write the magic
  /// ceiling value directly — only this method and
  /// [UpdatePayjoinMinAmountUsecase] (for the amount field itself) touch
  /// `payjoinMinAmountSat`.
  Future<void> setPayjoinEnabled(bool enabled) async {
    final amountSat = enabled
        ? PayjoinConstants.defaultMinAmountSat
        : PayjoinConstants.maxMinAmountSat;
    await setPayjoinMinAmount(amountSat);
  }

  Future<void> setPayjoinExpireAfterSec(int expireAfterSec) async {
    await _updatePayjoinExpireAfterSecUsecase.execute(
      payjoinExpireAfterSec: expireAfterSec,
    );
    final settings = state.storedSettings;
    emit(
      state.copyWith(
        storedSettings: settings?.copyWith(
          payjoinExpireAfterSec: expireAfterSec,
        ),
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

    // If disabling dev mode, revoke Ark first
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
    }

    await _setIsDevModeUsecase.execute(isEnabled);
    emit(
      state.copyWith(
        storedSettings: settings?.copyWith(isDevModeEnabled: isEnabled),
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
