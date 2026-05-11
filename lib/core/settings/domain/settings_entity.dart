import 'dart:ui';

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
  arabic('ar', null, 'العربية'),
  bulgarian('bg', null, 'Български'),
  bengali('bn', null, 'বাংলা'),
  czech('cs', null, 'Čeština'),
  german('de', 'DE', 'Deutsch'),
  greek('el', null, 'Ελληνικά'),
  spanish('es', 'ES', 'Español'),
  persian('fa', null, 'فارسی'),
  finnish('fi', 'FI', 'Suomi'),
  franceFrench('fr', 'FR', 'Français'),
  hindi('hi', null, 'हिन्दी'),
  italian('it', 'IT', 'Italiano'),
  korean('ko', null, '한국어'),
  portuguese('pt', 'PT', 'Português'),
  brazilianPortuguese('pt', 'BR', 'Português (Brasil)'),
  russian('ru', 'RU', 'Русский'),
  thai('th', null, 'ภาษาไทย'),
  turkish('tr', null, 'Türkçe'),
  ukrainian('uk', 'UA', 'Українська'),
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

  static Language fromKeyboard() {
    final locale = PlatformDispatcher.instance.locale;
    final exact = Language.values.where(
      (l) =>
          l.languageCode == locale.languageCode &&
          l.countryCode == locale.countryCode,
    );
    if (exact.isNotEmpty) return exact.first;
    final langOnly = Language.values.where(
      (l) => l.languageCode == locale.languageCode,
    );
    if (langOnly.isNotEmpty) return langOnly.first;
    return Language.unitedStatesEnglish;
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
    @Default(false) bool isErrorReportingEnabled,
  }) = _SettingsEntity;
  const SettingsEntity._();
}
