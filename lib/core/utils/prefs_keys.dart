/// Canonical keys for values read from [SharedPreferences] by code that
/// runs before the locator is ready (consent, FSS library mirror, app
/// version marker). Keep all such keys here so that write sites and read
/// sites cannot silently drift apart.
class PrefsKeys {
  PrefsKeys._();

  /// Mirror of the SQLite `isErrorReportingEnabled` field so Sentry init
  /// can read consent before the SQLite locator is available.
  static const String errorReportingEnabled = 'pref_error_reporting_enabled';

  /// Mirror of the `SeedStoreTypeDatasource` flag so migration reporting
  /// can include the current FSS library (fss9 / fss10) before the
  /// locator is ready.
  static const String fssLibrary = 'pref_fss_library';

  /// The app version we saw on the previous successful `Bull.init`. Used
  /// to fire a one-shot `migration_app_upgrade` Sentry event on upgrade.
  static const String lastSeenAppVersion = 'last_seen_app_version';
}
