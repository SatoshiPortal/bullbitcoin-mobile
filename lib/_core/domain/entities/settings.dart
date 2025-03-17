import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'settings.freezed.dart';

enum Environment {
  mainnet,
  testnet;

  factory Environment.fromName(String name) {
    return Environment.values
        .firstWhere((environment) => environment.name == name);
  }

  bool get isMainnet => this == Environment.mainnet;
  bool get isTestnet => this == Environment.testnet;
}

enum BitcoinUnit {
  btc(decimals: 8),
  sats(decimals: 0);

  final int decimals;

  const BitcoinUnit({
    required this.decimals,
  });

  factory BitcoinUnit.fromName(String name) {
    return BitcoinUnit.values
        .firstWhere((bitcoinUnit) => bitcoinUnit.name == name);
  }
}

enum Language {
  unitedStatesEnglish('en', 'US'),
  canadianFrench('fr', 'CA'),
  franceFrench('fr', 'FR');

  final String languageCode;
  final String? countryCode;

  const Language(this.languageCode, this.countryCode);

  static Language? fromName(String name) {
    try {
      return Language.values.firstWhere((language) => language.name == name);
    } catch (e) {
      return null;
    }
  }
}

extension LanguageExtension on Language {
  Locale get locale => Locale(languageCode, countryCode);
  bool isLocale(Locale locale) =>
      locale.languageCode == languageCode && locale.countryCode == countryCode;
}

@freezed
class SettingsState with _$SettingsState {
  const factory SettingsState({
    required Environment environment,
    required BitcoinUnit bitcoinUnit,
    Language? language,
    required String currencyCode,
    bool? hideAmounts,
  }) = _SettingsState;
  const SettingsState._();
}
