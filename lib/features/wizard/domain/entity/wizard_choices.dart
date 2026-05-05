import 'package:bb_mobile/core/settings/domain/settings_entity.dart';

/// One per user-controllable wizard field. Used as the membership type
/// of [WizardChoices.touched] so that `ApplyPendingWizardChoicesUsecase`
/// only commits to settings the fields the user actively picked. Fields
/// the wizard merely *displayed* (e.g. brightness-detected theme,
/// keyboard-detected language) stay out of the touched set and never
/// clobber existing user values when `kCurrentWizardVersion` bumps.
enum WizardField { language, themeMode, defaultCurrency, reportingConsent }

/// Tagged variant for the `reportingConsent` parameter of
/// [WizardChoices.copyWith].
///
/// `null` is itself a valid [WizardChoices.reportingConsent] value
/// ("user has not yet answered"), so the usual nullable-named-arg
/// pattern can't distinguish "caller didn't supply a value" from
/// "caller wants to reset to null". This sealed type makes the two
/// cases statically distinguishable without resorting to `Object?` and
/// runtime casts.
sealed class ConsentArg {
  const ConsentArg();
}

class _ConsentUnset extends ConsentArg {
  const _ConsentUnset();
}

class ConsentValue extends ConsentArg {
  const ConsentValue(this.value);
  final bool? value;
}

const ConsentArg _consentUnset = _ConsentUnset();

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

  /// User-initiated change — marks the touched field so the bloc's
  /// `SavePendingWizardChoicesUsecase` (on completion) stages it for
  /// `ApplyPendingWizardChoicesUsecase` to flush post-locator.
  WizardChoices copyWith({
    Language? language,
    AppThemeMode? themeMode,
    String? defaultCurrency,
    ConsentArg reportingConsent = _consentUnset,
  }) {
    final t = Set<WizardField>.from(touched);
    if (language != null) t.add(WizardField.language);
    if (themeMode != null) t.add(WizardField.themeMode);
    if (defaultCurrency != null) t.add(WizardField.defaultCurrency);
    if (reportingConsent is ConsentValue) {
      t.add(WizardField.reportingConsent);
    }
    return WizardChoices(
      language: language ?? this.language,
      themeMode: themeMode ?? this.themeMode,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      reportingConsent: switch (reportingConsent) {
        ConsentValue(:final value) => value,
        _ConsentUnset() => this.reportingConsent,
      },
      touched: t,
    );
  }

  /// System-initiated theme update (brightness detection). Updates the
  /// value for display purposes only — does NOT mark the field as
  /// touched, so it won't be committed to settings unless the user
  /// later confirms via the theme picker.
  WizardChoices copyWithSilent({AppThemeMode? themeMode}) {
    return WizardChoices(
      language: language,
      themeMode: themeMode ?? this.themeMode,
      defaultCurrency: defaultCurrency,
      reportingConsent: reportingConsent,
      touched: touched,
    );
  }
}
