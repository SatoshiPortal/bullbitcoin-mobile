import 'package:bb_mobile/core/settings/domain/settings_entity.dart';

/// One per user-controllable wizard field. Used as the membership type
/// of [WizardChoices.touched] so that the gate (pre-init upgrade path)
/// only commits to settings the fields the user actively picked. Fields
/// the wizard merely *displayed* (e.g. brightness-detected theme,
/// keyboard-detected language) stay out of the touched set and never
/// clobber existing user values when `kCurrentWizardVersion` bumps.
enum WizardField { language, themeMode, defaultCurrency, reportingConsent }

class WizardChoices {
  const WizardChoices({
    this.language = Language.unitedStatesEnglish,
    this.themeMode = AppThemeMode.system,
    this.defaultCurrency = 'USD',
    this.reportingConsent,
    this.touched = const <WizardField>{},
  });

  final Language language;
  final AppThemeMode themeMode;
  final String defaultCurrency;
  // `null` means the user has not yet answered the error-reporting question.
  // Page 3 of the wizard requires an explicit Yes/No before the wizard can
  // be completed via Next/Skip/Get started.
  final bool? reportingConsent;

  /// Tracks which fields the user explicitly picked via the wizard's UI
  /// controls (theme/language/currency pickers, mission Yes/No buttons).
  /// Auto-detected values (e.g. `WizardScreen.initState` brightness +
  /// keyboard probes) update the corresponding field via [copyWithSilent]
  /// without joining this set, so they update the wizard's display
  /// without committing to user settings.
  final Set<WizardField> touched;

  /// User-initiated change — marks the touched field so it'll be
  /// committed by `WizardGate.apply`/`savePending` (pre-init path) and
  /// by `WizardRouteScreen` (in-app path).
  WizardChoices copyWith({
    Language? language,
    AppThemeMode? themeMode,
    String? defaultCurrency,
    Object? reportingConsent = _unset,
  }) {
    final t = Set<WizardField>.from(touched);
    if (language != null) t.add(WizardField.language);
    if (themeMode != null) t.add(WizardField.themeMode);
    if (defaultCurrency != null) t.add(WizardField.defaultCurrency);
    if (!identical(reportingConsent, _unset)) {
      t.add(WizardField.reportingConsent);
    }
    return WizardChoices(
      language: language ?? this.language,
      themeMode: themeMode ?? this.themeMode,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      reportingConsent: identical(reportingConsent, _unset)
          ? this.reportingConsent
          : reportingConsent as bool?,
      touched: t,
    );
  }

  /// System-initiated change (brightness detection, keyboard locale).
  /// Updates the value for display purposes only — does NOT mark the
  /// field as touched, so it won't be committed to settings unless the
  /// user later confirms via the corresponding picker.
  WizardChoices copyWithSilent({Language? language, AppThemeMode? themeMode}) {
    return WizardChoices(
      language: language ?? this.language,
      themeMode: themeMode ?? this.themeMode,
      defaultCurrency: defaultCurrency,
      reportingConsent: reportingConsent,
      touched: touched,
    );
  }
}

const Object _unset = Object();
