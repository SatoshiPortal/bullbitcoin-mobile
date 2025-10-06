import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/get_old_seeds_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_bitcoin_unit_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_currency_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_environment_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_hide_amounts_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_is_superuser_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_language_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_theme_mode_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:package_info_plus/package_info_plus.dart';

part 'settings_cubit.freezed.dart';
part 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({
    required GetSettingsUsecase getSettingsUsecase,
    required SetEnvironmentUsecase setEnvironmentUsecase,
    required SetBitcoinUnitUsecase setBitcoinUnitUsecase,
    required SetLanguageUsecase setLanguageUsecase,
    required SetCurrencyUsecase setCurrencyUsecase,
    required SetHideAmountsUsecase setHideAmountsUsecase,
    required SetIsSuperuserUsecase setIsSuperuserUsecase,
    required SetThemeModeUsecase setThemeModeUsecase,
    required GetOldSeedsUsecase getOldSeedsUsecase,
  }) : _setEnvironmentUsecase = setEnvironmentUsecase,
       _setBitcoinUnitUsecase = setBitcoinUnitUsecase,
       _getSettingsUsecase = getSettingsUsecase,
       _setLanguageUsecase = setLanguageUsecase,
       _setCurrencyUsecase = setCurrencyUsecase,
       _setHideAmountsUsecase = setHideAmountsUsecase,
       _setIsSuperuserUsecase = setIsSuperuserUsecase,
       _setThemeModeUsecase = setThemeModeUsecase,
       _getOldSeedsUsecase = getOldSeedsUsecase,
       super(const SettingsState());

  final SetEnvironmentUsecase _setEnvironmentUsecase;
  final GetSettingsUsecase _getSettingsUsecase;
  final SetBitcoinUnitUsecase _setBitcoinUnitUsecase;
  final SetLanguageUsecase _setLanguageUsecase;
  final SetCurrencyUsecase _setCurrencyUsecase;
  final SetHideAmountsUsecase _setHideAmountsUsecase;
  final SetIsSuperuserUsecase _setIsSuperuserUsecase;
  final SetThemeModeUsecase _setThemeModeUsecase;
  final GetOldSeedsUsecase _getOldSeedsUsecase;

  Future<void> init() async {
    final (storedSettings, appInfo) =
        await (_getSettingsUsecase.execute(), PackageInfo.fromPlatform()).wait;
    final appVersion = '${appInfo.version}+${appInfo.buildNumber}';

    emit(
      state.copyWith(storedSettings: storedSettings, appVersion: appVersion),
    );
    await checkHasLegacySeeds();
  }

  Future<void> toggleTestnetMode(bool active) async {
    final settings = state.storedSettings;
    // Log the action
    log.info(
      'Testnet mode toggled: $active + currentEnvironment: ${settings?.environment.name}',
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
    // Log the action
    log.info(
      'Bitcoin unit toggled: $active + currentBitcoinUnit: ${settings?.bitcoinUnit.name}',
    );
    final unit = active ? BitcoinUnit.sats : BitcoinUnit.btc;
    await _setBitcoinUnitUsecase.execute(unit);
    emit(state.copyWith(storedSettings: settings?.copyWith(bitcoinUnit: unit)));
  }

  Future<void> changeLanguage(Language language) async {
    final settings = state.storedSettings;
    // Log the action
    log.info(
      'Language changed to: ${language.name} + currentLanguage: ${settings?.language?.name}',
    );
    await _setLanguageUsecase.execute(language);
    emit(
      state.copyWith(storedSettings: settings?.copyWith(language: language)),
    );
  }

  Future<void> changeCurrency(String currencyCode) async {
    final settings = state.storedSettings;
    // Log the action
    log.info(
      'Currency changed to: $currencyCode + currentCurrency: ${settings?.currencyCode}',
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
    // Log the action
    log.info(
      'Hide amounts toggled: $hide + currentHideAmounts: ${settings?.hideAmounts}',
    );
    await _setHideAmountsUsecase.execute(hide);
    emit(state.copyWith(storedSettings: settings?.copyWith(hideAmounts: hide)));
  }

  Future<void> toggleSuperuserMode(bool active) async {
    final settings = state.storedSettings;
    // Log the action
    log.info(
      'Superuser mode toggled: $active + currentSuperuserMode: ${settings?.isSuperuser}',
    );
    await _setIsSuperuserUsecase.execute(active);
    emit(
      state.copyWith(storedSettings: settings?.copyWith(isSuperuser: active)),
    );
  }

  Future<void> changeThemeMode(AppThemeMode themeMode) async {
    final settings = state.storedSettings;
    // Log the action
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
}
