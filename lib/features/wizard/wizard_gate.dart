import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/wizard/wizard_choices.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bump this integer whenever the wizard gains new mandatory questions.
/// Users whose stored version is lower will see the wizard again on next
/// launch.
///
/// WARNING: bumping this re-shows the wizard. The pre-init wrapper
/// stages choices in prefs and `apply()` flushes them to SQLite via
/// `setLanguage` / `setThemeMode` / `setCurrency` / `setErrorReporting`
/// — even if the user just clicked through with defaults. Before
/// bumping, add a "user explicitly changed this field" sentinel on each
/// `WizardChoices` field (the `_unset` sentinel pattern already used
/// for `reportingConsent`) and skip the corresponding `settings.setX`
/// call when the field was not actively touched.
const int kCurrentWizardVersion = 1;

/// Coordinates whether the install/upgrade wizard must be shown and
/// stages user choices when the wizard runs **pre-locator**.
///
/// Two trigger paths share this gate:
///
/// - **Upgrade path** — wizard runs in `main()` before `Bull.init`, so it
///   can collect consent before migrations / Sentry init / Drift schema
///   work fires off. Choices are written to SharedPreferences via
///   [savePending] and flushed to the SQLite settings repository by
///   [apply] once the locator is up.
///
/// - **Fresh install path** — wizard runs as a `GoRoute` after Bull.init
///   from the Create/Recover buttons (`WizardRouteScreen`). That path
///   writes through `SettingsCubit` directly and only calls
///   [markComplete] here.
///
/// The two paths are gated apart in `main.dart` via [isSetupComplete] —
/// a flag set whenever the user has wallets (existing v6.x users get it
/// auto-set on first boot via `AppStartupBloc`; brand-new users get it
/// set by `OnboardingBloc` after a successful create/recover).
class WizardGate {
  static const String _versionKey = 'wizard_completed_version';
  static const String _setupCompleteKey = 'wizard_setup_complete';
  // Pre-rename key — read-once-then-erased on first `isSetupComplete`
  // call so existing v6.9 users don't lose their setup-complete signal.
  static const String _legacySetupCompleteKey = 'wallet_setup_complete';
  static const String _pendingVersionKey = 'wizard_pending_version';
  static const String _pendingLanguageKey = 'wizard_pending_language';
  static const String _pendingThemeKey = 'wizard_pending_theme_mode';
  static const String _pendingCurrencyKey = 'wizard_pending_currency';
  static const String _pendingErrorReportingKey =
      'wizard_pending_error_reporting';

  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(_versionKey) ?? 0;
    return stored < kCurrentWizardVersion;
  }

  static Future<void> markComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_versionKey, kCurrentWizardVersion);
  }

  /// `true` once the user has any default wallets — i.e. previous BULL
  /// install has reached the "active wallet" milestone. Used pre-locator
  /// in `main.dart` to distinguish upgrade (show wizard before
  /// migrations to collect consent in time) vs fresh install (defer
  /// wizard to the Create/Recover buttons).
  static Future<bool> isSetupComplete() async {
    final prefs = await SharedPreferences.getInstance();
    // One-shot migration: rename `wallet_setup_complete` →
    // `wizard_setup_complete` (the flag is conceptually about wizard
    // routing, not wallet setup). Carry the legacy value across so the
    // upgrade detection still fires for v6.9 users on first v7+ launch.
    if (prefs.containsKey(_legacySetupCompleteKey) &&
        !prefs.containsKey(_setupCompleteKey)) {
      final legacy = prefs.getBool(_legacySetupCompleteKey) ?? false;
      await prefs.setBool(_setupCompleteKey, legacy);
      await prefs.remove(_legacySetupCompleteKey);
    }
    return prefs.getBool(_setupCompleteKey) ?? false;
  }

  /// Set by:
  /// - `AppStartupBloc` when it detects an existing default wallet on
  ///   boot (auto-migration for v6.x users upgrading to a build that
  ///   ships this flag for the first time).
  /// - `OnboardingBloc` after a successful create/recover so the next
  ///   launch routes through the upgrade pre-init path.
  ///
  /// Idempotent — short-circuits when the flag is already set, so the
  /// 3 call sites can fire concurrently or repeatedly without piling
  /// up writes.
  static Future<void> markSetupComplete() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_setupCompleteKey) ?? false) return;
    await prefs.setBool(_setupCompleteKey, true);
  }

  /// Stages wizard choices in prefs so `Bull.init` (running right after
  /// the pre-init wizard finishes) can pass `wizardConsent` to
  /// `Report.init` and so [apply] can flush the rest to SQLite once the
  /// locator is up. Only used by the upgrade-path pre-init wizard.
  ///
  /// Only writes fields the user explicitly picked — see
  /// [WizardChoices.touched]. Stale values from a previous incomplete
  /// wizard run are wiped first so they can't resurrect on read.
  static Future<void> savePending(WizardChoices choices) async {
    await clearPending();
    final prefs = await SharedPreferences.getInstance();
    // Tag the staging blob with the version that wrote it so a future
    // `kCurrentWizardVersion` bump invalidates stale pending state from
    // an interrupted earlier wizard run, instead of letting `apply()`
    // flush v(N-1) defaults onto v(N) settings.
    await prefs.setInt(_pendingVersionKey, kCurrentWizardVersion);
    if (choices.touched.contains(WizardField.language)) {
      await prefs.setString(_pendingLanguageKey, choices.language.name);
    }
    if (choices.touched.contains(WizardField.themeMode)) {
      await prefs.setString(_pendingThemeKey, choices.themeMode.name);
    }
    if (choices.touched.contains(WizardField.defaultCurrency)) {
      await prefs.setString(_pendingCurrencyKey, choices.defaultCurrency);
    }
    final consent = choices.reportingConsent;
    if (choices.touched.contains(WizardField.reportingConsent) &&
        consent != null) {
      await prefs.setBool(_pendingErrorReportingKey, consent);
    }
  }

  /// Reconstructs a [WizardChoices] with `touched` derived from which
  /// keys are present in prefs — only fields the user picked end up in
  /// the touched set, so [apply] commits exactly those.
  ///
  /// Returns `null` if the staged blob is from a different
  /// `kCurrentWizardVersion` than the current build (also wiped as a
  /// side effect) — those values belong to a previous wizard schema
  /// and must not leak into the new one.
  static Future<WizardChoices?> readPending() async {
    final prefs = await SharedPreferences.getInstance();
    final languageName = prefs.getString(_pendingLanguageKey);
    final themeName = prefs.getString(_pendingThemeKey);
    final currency = prefs.getString(_pendingCurrencyKey);
    final errorReporting = prefs.getBool(_pendingErrorReportingKey);
    if (languageName == null &&
        themeName == null &&
        currency == null &&
        errorReporting == null) {
      return null;
    }
    // Pending data is present — verify the tag matches the build.
    // A missing tag (`0`) implies pre-versioning leftovers from an
    // older build and is treated as stale.
    final pendingVersion = prefs.getInt(_pendingVersionKey) ?? 0;
    if (pendingVersion != kCurrentWizardVersion) {
      await clearPending();
      return null;
    }

    final touched = <WizardField>{};
    if (languageName != null) touched.add(WizardField.language);
    if (themeName != null) touched.add(WizardField.themeMode);
    if (currency != null) touched.add(WizardField.defaultCurrency);
    if (errorReporting != null) touched.add(WizardField.reportingConsent);

    return WizardChoices(
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

  /// Flushes pending wizard choices (set by the pre-init wrapper via
  /// [savePending]) to the SQLite settings repository, clears the
  /// staging keys, then marks the wizard complete. Only commits fields
  /// the user actively picked — leaves any field they didn't touch
  /// alone. Safe to call when no answers are pending.
  static Future<void> apply(SettingsRepository settings) async {
    final choices = await readPending();
    if (choices == null) return;
    if (choices.touched.contains(WizardField.language)) {
      await settings.setLanguage(choices.language);
    }
    if (choices.touched.contains(WizardField.themeMode)) {
      await settings.setThemeMode(choices.themeMode);
    }
    if (choices.touched.contains(WizardField.defaultCurrency)) {
      await settings.setCurrency(choices.defaultCurrency);
    }
    final consent = choices.reportingConsent;
    if (choices.touched.contains(WizardField.reportingConsent) &&
        consent != null) {
      await settings.setErrorReportingEnabled(consent);
    }
    await clearPending();
    await markComplete();
  }

  static Future<void> clearPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingVersionKey);
    await prefs.remove(_pendingLanguageKey);
    await prefs.remove(_pendingThemeKey);
    await prefs.remove(_pendingCurrencyKey);
    await prefs.remove(_pendingErrorReportingKey);
  }
}
