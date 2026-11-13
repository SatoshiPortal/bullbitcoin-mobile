import 'dart:convert';

import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/wizard/data/datasource/wizard_local_datasource.dart';
import 'package:bb_mobile/features/wizard/domain/entity/wizard_choices.dart';
import 'package:bb_mobile/features/wizard/domain/repository/wizard_repository.dart';

/// Keep version 1: adding optional exchange access must not replay onboarding.
const int kCurrentWizardVersion = 1;

class WizardRepositoryImpl implements WizardRepository {
  WizardRepositoryImpl(this._datasource);

  final WizardLocalDatasource _datasource;

  @override
  Future<bool> isComplete() async {
    final stored = await _datasource.readCompletedVersion() ?? 0;
    return stored >= kCurrentWizardVersion;
  }

  @override
  Future<void> markComplete() =>
      _datasource.writeCompletedVersion(kCurrentWizardVersion);

  @override
  Future<void> savePending(WizardChoices choices) async {
    final payload = <String, Object?>{'version': kCurrentWizardVersion};
    if (choices.touched.contains(WizardField.language)) {
      payload['language'] = choices.language.name;
    }
    if (choices.touched.contains(WizardField.themeMode)) {
      payload['themeMode'] = choices.themeMode.name;
    }
    if (choices.touched.contains(WizardField.defaultCurrency)) {
      payload['currency'] = choices.defaultCurrency;
    }
    if (choices.touched.contains(WizardField.exchangeAccess)) {
      payload['exchangeAccess'] = choices.exchangeAccess;
    }
    if (choices.touched.contains(WizardField.reportingConsent)) {
      payload['reportingConsent'] = choices.reportingConsent;
    }
    await _datasource.writePendingPayload(jsonEncode(payload));
  }

  /// Returns `null` when nothing is staged OR when the staged blob was
  /// written by a different `kCurrentWizardVersion` (also wiped as a
  /// side effect — those values belong to a previous wizard schema and
  /// must not leak into the new one).
  @override
  Future<WizardChoices?> readPending() async {
    final payload = await _datasource.readPendingPayload();
    String? languageName;
    String? themeName;
    String? currency;
    bool? errorReporting;
    bool? exchangeAccess;
    int? pendingVersion;
    if (payload != null) {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid wizard choices');
      }
      pendingVersion = decoded['version'] as int?;
      languageName = decoded['language'] as String?;
      themeName = decoded['themeMode'] as String?;
      currency = decoded['currency'] as String?;
      errorReporting = decoded['reportingConsent'] as bool?;
      exchangeAccess = decoded['exchangeAccess'] as bool?;
    } else {
      pendingVersion = await _datasource.readPendingVersion();
      languageName = await _datasource.readPendingLanguage();
      themeName = await _datasource.readPendingThemeMode();
      currency = await _datasource.readPendingCurrency();
      errorReporting = await _datasource.readPendingErrorReporting();
      exchangeAccess = await _datasource.readPendingExchangeAccess();
    }
    if (languageName == null &&
        themeName == null &&
        currency == null &&
        errorReporting == null &&
        exchangeAccess == null) {
      return null;
    }
    if (pendingVersion != kCurrentWizardVersion) {
      await clearPending();
      return null;
    }
    final touched = <WizardField>{};
    if (languageName != null) touched.add(WizardField.language);
    if (themeName != null) touched.add(WizardField.themeMode);
    if (currency != null) touched.add(WizardField.defaultCurrency);
    if (errorReporting != null) touched.add(WizardField.reportingConsent);
    if (exchangeAccess != null) touched.add(WizardField.exchangeAccess);
    return WizardChoices(
      exchangeAccess: exchangeAccess ?? true,
      language: languageName == null
          ? Language.unitedStatesEnglish
          : Language.fromName(languageName),
      themeMode: themeName == null
          ? AppThemeMode.system
          : AppThemeMode.fromName(themeName),
      defaultCurrency: currency ?? 'USD',
      reportingConsent: errorReporting,
      touched: touched,
    );
  }

  @override
  Future<void> clearPending() => _datasource.writePendingPayload(
    jsonEncode({'version': kCurrentWizardVersion}),
  );
}
