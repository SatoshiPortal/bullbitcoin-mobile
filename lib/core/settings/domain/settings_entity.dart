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
  unitedStatesEnglish('en', label: 'English'),
  arabic('ar', label: 'العربية'),
  bulgarian('bg', label: 'Български'),
  bengali('bn', label: 'বাংলা'),
  czech('cs', label: 'Čeština'),
  german('de', label: 'Deutsch'),
  greek('el', label: 'Ελληνικά'),
  spanish('es', label: 'Español'),
  persian('fa', label: 'فارسی'),
  finnish('fi', label: 'Suomi'),
  franceFrench('fr', label: 'Français'),
  hindi('hi', label: 'हिन्दी'),
  hinglish('hi', label: 'Hinglish', scriptCode: 'Latn'),
  italian('it', label: 'Italiano'),
  korean('ko', label: '한국어'),
  portuguese('pt', label: 'Português'),
  brazilianPortuguese('pt', label: 'Português (Brasil)', countryCode: 'BR'),
  russian('ru', label: 'Русский'),
  thai('th', label: 'ภาษาไทย'),
  turkish('tr', label: 'Türkçe'),
  ukrainian('uk', label: 'Українська'),
  simplifiedChinese('zh', label: '简体中文'),
  assamese('as', label: 'অসমীয়া');

  final String languageCode;
  final String? countryCode;
  final String? scriptCode;
  final String label;

  const Language(
    this.languageCode, {
    required this.label,
    this.countryCode,
    this.scriptCode,
  });

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
          l.countryCode == locale.countryCode &&
          l.scriptCode == locale.scriptCode,
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
  Locale get locale => Locale.fromSubtags(
    languageCode: languageCode,
    scriptCode: scriptCode,
    countryCode: countryCode,
  );
  bool isLocale(Locale locale) =>
      locale.languageCode == languageCode &&
      locale.scriptCode == scriptCode &&
      locale.countryCode == countryCode;
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
