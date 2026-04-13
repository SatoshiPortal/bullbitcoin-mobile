import 'package:bb_mobile/features/settings/aplication/settings_application_errors.dart';
import 'package:bb_mobile/features/settings/aplication/usecases/get_app_settings_usecase.dart';
import 'package:bb_mobile/features/settings/aplication/usecases/watch_app_settings_usecase.dart';
import 'package:bb_mobile/features/settings/domain/primitives/bitcoin_unit.dart';
import 'package:bb_mobile/features/settings/domain/primitives/environment_mode.dart';
import 'package:bb_mobile/features/settings/domain/primitives/feature_level.dart';
import 'package:bb_mobile/features/settings/domain/primitives/fiat_currency.dart';
import 'package:bb_mobile/features/settings/domain/primitives/language.dart';
import 'package:bb_mobile/features/settings/domain/primitives/theme_mode.dart';
import 'package:bb_mobile/features/settings/public/settings_facade_errors.dart';

class SettingsFacade {
  final GetAppSettingsUsecase _getAppSettingsUsecase;
  final WatchAppSettingsUsecase _watchAppSettingsUsecase;

  const SettingsFacade({
    required GetAppSettingsUsecase getAppSettingsUsecase,
    required WatchAppSettingsUsecase watchAppSettingsUsecase,
  }) : _getAppSettingsUsecase = getAppSettingsUsecase,
       _watchAppSettingsUsecase = watchAppSettingsUsecase;

  // Get specific currency settings
  Future<FiatCurrency> getFiatCurrency() async {
    try {
      final settings = await _getAppSettingsUsecase.execute();
      return settings.currency.fiatCurrency;
    } on SettingsApplicationError catch (e) {
      throw SettingsFacadeError.fromApplicationError(e);
    }
  }

  Future<BitcoinUnit> getBitcoinUnit() async {
    try {
      final settings = await _getAppSettingsUsecase.execute();
      return settings.currency.bitcoinUnit;
    } on SettingsApplicationError catch (e) {
      throw SettingsFacadeError.fromApplicationError(e);
    }
  }

  // Get specific display settings
  Future<Language> getLanguage() async {
    try {
      final settings = await _getAppSettingsUsecase.execute();
      return settings.display.language;
    } on SettingsApplicationError catch (e) {
      throw SettingsFacadeError.fromApplicationError(e);
    }
  }

  Future<ThemeMode> getThemeMode() async {
    try {
      final settings = await _getAppSettingsUsecase.execute();
      return settings.display.themeMode;
    } on SettingsApplicationError catch (e) {
      throw SettingsFacadeError.fromApplicationError(e);
    }
  }

  Future<bool> getAmountVisibility() async {
    try {
      final settings = await _getAppSettingsUsecase.execute();
      return settings.display.hideAmounts;
    } on SettingsApplicationError catch (e) {
      throw SettingsFacadeError.fromApplicationError(e);
    }
  }

  // Get specific environment settings
  Future<EnvironmentMode> getEnvironmentMode() async {
    try {
      final settings = await _getAppSettingsUsecase.execute();
      return settings.environment.environmentMode;
    } on SettingsApplicationError catch (e) {
      throw SettingsFacadeError.fromApplicationError(e);
    }
  }

  Future<bool> getSuperuserMode() async {
    try {
      final settings = await _getAppSettingsUsecase.execute();
      return settings.environment.superuserModeEnabled;
    } on SettingsApplicationError catch (e) {
      throw SettingsFacadeError.fromApplicationError(e);
    }
  }

  Future<FeatureLevel> getFeatureLevel() async {
    try {
      final settings = await _getAppSettingsUsecase.execute();
      return settings.environment.featureLevel;
    } on SettingsApplicationError catch (e) {
      throw SettingsFacadeError.fromApplicationError(e);
    }
  }

  // Watch specific currency settings (most commonly needed by other features)
  Stream<FiatCurrency> watchFiatCurrency() => _watchAppSettingsUsecase
      .execute()
      .map((s) => s.currency.fiatCurrency)
      .distinct();

  Stream<BitcoinUnit> watchBitcoinUnit() => _watchAppSettingsUsecase
      .execute()
      .map((s) => s.currency.bitcoinUnit)
      .distinct();

  // Watch specific display settings
  Stream<Language> watchLanguage() => _watchAppSettingsUsecase
      .execute()
      .map((s) => s.display.language)
      .distinct();

  Stream<ThemeMode> watchThemeMode() => _watchAppSettingsUsecase
      .execute()
      .map((s) => s.display.themeMode)
      .distinct();

  Stream<bool> watchAmountVisibility() => _watchAppSettingsUsecase
      .execute()
      .map((s) => s.display.hideAmounts)
      .distinct();

  // Watch specific environment settings
  Stream<EnvironmentMode> watchEnvironmentMode() => _watchAppSettingsUsecase
      .execute()
      .map((s) => s.environment.environmentMode)
      .distinct();

  Stream<bool> watchSuperuserMode() => _watchAppSettingsUsecase
      .execute()
      .map((s) => s.environment.superuserModeEnabled)
      .distinct();

  Stream<FeatureLevel> watchFeatureLevel() => _watchAppSettingsUsecase
      .execute()
      .map((s) => s.environment.featureLevel)
      .distinct();
}
