# Preferences

Preferences owns application settings and active environment selection. The legacy application database still composes the `Settings`, `Recoverbull` and `DismissedAnnouncements` tables at schema 16; this extraction does not migrate data or open a separate database.

```dart
final preferences = Preferences.open(database: database);
final settings = await preferences.fetch();
final changed = await preferences.setCurrency('CAD');
final display = preferences.watchDisplayPreferences();
await preferences.close();
```

`open` performs no I/O and borrows the database. `close` closes the preference notification streams without closing the database. The application owns the database lifecycle.

All fallible commands and queries return `Result<T, PreferencesFailure>`. The failure family distinguishes missing settings, invalid persisted values, read failures and write failures. Diagnostics contain failure categories, never stored values. Programmer errors are not converted to recoverable failures.

Display observations emit `Stream<Result<AmountDisplayPreferences, PreferencesFailure>>`. A missing row, unknown Bitcoin unit or recoverable stream error emits a failure. The subscription remains active and can recover on the next valid row. Consumers must hide amounts while preferences are unavailable. Currency and environment notifications also carry results and are emitted only after successful writes; a failed write does not announce a change.

The ordinary library exports `Preferences`, owned domain types, failures and narrow reader/writer contracts. Consumers needing only environment, currency, Tor or display preferences can depend on those contracts. `announcementDismissals` and `recoverBull` expose the legacy table capabilities through the same failure family. Exchange web credentials are returned only for testnet. Full settings reads retain the transactional repair of unauthorized developer networks before returning the active environment.

Storage declarations and the DAO are for the database composer. `package:preferences/testing.dart` supplies DAO injection for boundary tests; application composition uses `Preferences.open`.
