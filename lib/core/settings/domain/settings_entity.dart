import 'package:bb_mobile/core/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'settings_entity.freezed.dart';

enum Environment {
  mainnet,
  testnet;

  factory Environment.fromName(String name) {
    return Environment.values.firstWhere(
      (environment) => environment.name == name,
    );
  }

  bool get isMainnet => this == Environment.mainnet;
  bool get isTestnet => this == Environment.testnet;
}

enum BitcoinUnit {
  btc(code: 'BTC', decimals: 8),
  sats(code: 'sats', decimals: 0);

  final String code;
  final int decimals;

  const BitcoinUnit({required this.code, required this.decimals});

  factory BitcoinUnit.fromName(String name) {
    return BitcoinUnit.values.firstWhere(
      (bitcoinUnit) => bitcoinUnit.name == name,
    );
  }
  factory BitcoinUnit.fromCode(String code) {
    return BitcoinUnit.values.firstWhere(
      (bitcoinUnit) => bitcoinUnit.code == code,
    );
  }
}

enum Language {
  unitedStatesEnglish('en', 'US', 'English'),
  franceFrench('fr', 'FR', 'Français'),
  spanish('es', 'ES', 'Español'),
  finnish('fi', 'FI', 'Suomi'),
  ukrainian('uk', 'UA', 'Українська'),
  russian('ru', 'RU', 'Русский'),
  german('de', 'DE', 'Deutsch'),
  italian('it', 'IT', 'Italiano'),
  portuguese('pt', 'PT', 'Português'),
  simplifiedChinese('zh', 'CN', '简体中文');

  final String languageCode;
  final String? countryCode;
  final String label;

  const Language(this.languageCode, this.countryCode, this.label);

  static Language fromName(String name) {
    try {
      return Language.values.firstWhere((language) => language.name == name);
    } catch (e) {
      log.warning('unsupported language fallback on default');
      return Language.unitedStatesEnglish;
    }
  }
}

enum AppThemeMode {
  light,
  dark,
  system;

  factory AppThemeMode.fromName(String name) {
    return AppThemeMode.values.firstWhere(
      (themeMode) => themeMode.name == name,
      orElse: () => AppThemeMode.system,
    );
  }
}

extension LanguageExtension on Language {
  Locale get locale => Locale(languageCode, countryCode);
  bool isLocale(Locale locale) =>
      locale.languageCode == languageCode && locale.countryCode == countryCode;
}

@freezed
abstract class SettingsEntity with _$SettingsEntity {
  const factory SettingsEntity({
    required Environment environment,
    required BitcoinUnit bitcoinUnit,
    Language? language,
    required String currencyCode,
    bool? hideAmounts,
    bool? isSuperuser,
    bool? isDevModeEnabled,
    @Default(false) bool useTorProxy,
    @Default(9050) int torProxyPort,
    @Default(AppThemeMode.system) AppThemeMode themeMode,
  }) = _SettingsEntity;
  const SettingsEntity._();
}
