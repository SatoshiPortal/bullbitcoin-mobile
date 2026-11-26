# Preferences

Preferences owns application settings, active environment selection and RecoverBull authorization. The owner database is `databases/preferences.sqlite`, encrypted with the `preferences/main` database key provided by Secrets.

```dart
final opened = await Preferences.open(
  file: preferencesFile,
  admission: runtimeAdmission,
);
// Once opened successfully:
final preferences = opened.fold((value) => value, onPreferencesUnavailable);
final settings = await preferences.fetch();
final changed = await preferences.setCurrency('CAD');
final display = preferences.watchDisplayPreferences();
await preferences.close();
```

`open` opens only an existing schema-1 owner database with a committed receipt under shared runtime admission. `close` closes the notification streams and the tracked owner connection.

All fallible commands and queries return `Result<T, PreferencesFailure>`. The failure family distinguishes missing settings, invalid persisted values, read failures and write failures. Diagnostics contain failure categories, never stored values. Programmer errors are not converted to recoverable failures.

Display observations emit `Stream<Result<AmountDisplayPreferences, PreferencesFailure>>`. A missing row, unknown Bitcoin unit or recoverable stream error emits a failure. The subscription remains active and can recover on the next valid row. Consumers must hide amounts while preferences are unavailable. Currency and environment notifications also carry results and are emitted only after successful writes; a failed write does not announce a change.

The ordinary library exports `Preferences`, owned domain types, failures and narrow reader/writer contracts. Consumers needing only environment, currency, Tor or display preferences can depend on those contracts. Ordinary settings reads use only the owner database and retain the transactional repair of unauthorized developer networks. The Exchange testnet Basic Auth belongs to the Exchange module's database; Preferences neither reads nor writes it, and it holds no connection to the legacy database. Announcements owns its dismissal store. RecoverBull authorization uses a newer standalone v1 permission when available and otherwise uses the imported legacy normal permission. A failed standalone read aborts the import. Regtest starts without authorization and can store its own permission independently. No historical URL is read or copied.

`package:preferences/migration.dart` exposes the participant for foreground cutover and background readiness checks. The foreground copies and verifies all owned rows and both `sqlite_sequence` entries before committing the import receipt. Fresh setup seeds the owner with a distinct receipt. Neither path deletes the legacy database or migrates Exchange credentials, which the Exchange participant imports. DAO injection is available only through `package:preferences/testing.dart`.
