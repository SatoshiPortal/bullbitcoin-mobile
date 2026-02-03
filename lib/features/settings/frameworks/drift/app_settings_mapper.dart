import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/settings/domain/entities/app_settings.dart'
    as domain;
import 'package:bb_mobile/features/settings/domain/primitives/bitcoin_unit.dart';
import 'package:bb_mobile/features/settings/domain/primitives/environment_mode.dart';
import 'package:bb_mobile/features/settings/domain/primitives/feature_level.dart';
import 'package:bb_mobile/features/settings/domain/primitives/fiat_currency.dart';
import 'package:bb_mobile/features/settings/domain/primitives/language.dart';
import 'package:bb_mobile/features/settings/domain/primitives/theme_mode.dart';
import 'package:bb_mobile/features/settings/domain/value_objects/currency_settings.dart';
import 'package:bb_mobile/features/settings/domain/value_objects/display_settings.dart';
import 'package:bb_mobile/features/settings/domain/value_objects/environment_settings.dart';
import 'package:bb_mobile/features/settings/frameworks/drift/app_settings_db_enums.dart';
import 'package:drift/drift.dart';

/// Mapper to convert between Drift AppSettingsRow and domain AppSettings.
///
/// This mapper decouples the domain from persistence by:
/// - Storing currency codes (USD, EUR) instead of enum names
/// - Storing BCP-47 language tags (en-US, fr-FR, nl-BE) for full locale support
/// - Using DB-specific enums that can remain stable even if domain enums change
class AppSettingsMapper {
  /// Convert from Drift row to domain entity
  static domain.AppSettings toDomain(AppSettingsRow row) {
    return domain.AppSettings(
      currency: CurrencySettings(
        fiatCurrency: row.fiatCurrencyCode.toFiatCurrency(),
        bitcoinUnit: row.bitcoinUnit.toDomain(),
      ),
      display: DisplaySettings(
        language: row.languageTag.toLanguage(),
        themeMode: row.themeMode.toDomain(),
        hideAmounts: row.hideAmounts,
      ),
      environment: EnvironmentSettings(
        environmentMode: row.environmentMode.toDomain(),
        superuserModeEnabled: row.superuserModeEnabled,
        featureLevel: row.featureLevel.toDomain(),
      ),
    );
  }

  /// Convert from domain entity to Drift companion for insert/update
  static AppSettingsCompanion toCompanion(domain.AppSettings settings) {
    return AppSettingsCompanion.insert(
      fiatCurrencyCode: Value(settings.currency.fiatCurrency.code),
      bitcoinUnit: Value(settings.currency.bitcoinUnit.toDb()),
      languageTag: Value(settings.display.language.toBcp47()),
      themeMode: Value(settings.display.themeMode.toDb()),
      hideAmounts: Value(settings.display.hideAmounts),
      environmentMode: Value(settings.environment.environmentMode.toDb()),
      superuserModeEnabled: Value(settings.environment.superuserModeEnabled),
      featureLevel: Value(settings.environment.featureLevel.toDb()),
    );
  }
}

// === FiatCurrency extensions ===

extension FiatCurrencyCodeMapper on String {
  /// Parse FiatCurrency from currency code (USD, EUR, etc.)
  FiatCurrency toFiatCurrency() {
    return FiatCurrency.values.firstWhere(
      (e) => e.code == this,
      orElse: () => FiatCurrency.usd,
    );
  }
}

// === BitcoinUnit extensions ===

extension BitcoinUnitDbMapper on BitcoinUnitDb {
  BitcoinUnit toDomain() {
    return switch (this) {
      BitcoinUnitDb.btc => BitcoinUnit.btc,
      BitcoinUnitDb.sats => BitcoinUnit.sats,
    };
  }
}

extension BitcoinUnitDomainMapper on BitcoinUnit {
  BitcoinUnitDb toDb() {
    return switch (this) {
      BitcoinUnit.btc => BitcoinUnitDb.btc,
      BitcoinUnit.sats => BitcoinUnitDb.sats,
    };
  }
}

// === Language extensions ===

extension LanguageBcp47Mapper on String {
  /// Parse Language from BCP-47 language tag (e.g., "en-US", "fr-FR", "nl-BE")
  Language toLanguage() {
    final parts = split('-');
    final languageCode = parts.first.toLowerCase();
    final countryCode = parts.length > 1 ? parts[1].toUpperCase() : null;

    return Language.values.firstWhere(
      (e) => e.languageCode == languageCode && e.countryCode == countryCode,
      orElse: () => Language.unitedStatesEnglish,
    );
  }
}

extension LanguageToBcp47Mapper on Language {
  /// Convert Language to BCP-47 language tag (e.g., "en-US", "fr-FR", "nl-BE")
  String toBcp47() {
    if (countryCode != null) {
      return '$languageCode-$countryCode';
    }
    return languageCode;
  }
}

// === ThemeMode extensions ===

extension ThemeModeDbMapper on ThemeModeDb {
  ThemeMode toDomain() {
    return switch (this) {
      ThemeModeDb.system => ThemeMode.system,
      ThemeModeDb.light => ThemeMode.light,
      ThemeModeDb.dark => ThemeMode.dark,
    };
  }
}

extension ThemeModeDomainMapper on ThemeMode {
  ThemeModeDb toDb() {
    return switch (this) {
      ThemeMode.system => ThemeModeDb.system,
      ThemeMode.light => ThemeModeDb.light,
      ThemeMode.dark => ThemeModeDb.dark,
    };
  }
}

// === EnvironmentMode extensions ===

extension EnvironmentModeDbMapper on EnvironmentModeDb {
  EnvironmentMode toDomain() {
    return switch (this) {
      EnvironmentModeDb.production => EnvironmentMode.production,
      EnvironmentModeDb.test => EnvironmentMode.test,
    };
  }
}

extension EnvironmentModeDomainMapper on EnvironmentMode {
  EnvironmentModeDb toDb() {
    return switch (this) {
      EnvironmentMode.production => EnvironmentModeDb.production,
      EnvironmentMode.test => EnvironmentModeDb.test,
    };
  }
}

// === FeatureLevel extensions ===

extension FeatureLevelDbMapper on FeatureLevelDb {
  FeatureLevel toDomain() {
    return switch (this) {
      FeatureLevelDb.stable => FeatureLevel.stable,
      FeatureLevelDb.alpha => FeatureLevel.alpha,
    };
  }
}

extension FeatureLevelDomainMapper on FeatureLevel {
  FeatureLevelDb toDb() {
    return switch (this) {
      FeatureLevel.stable => FeatureLevelDb.stable,
      FeatureLevel.alpha => FeatureLevelDb.alpha,
    };
  }
}
