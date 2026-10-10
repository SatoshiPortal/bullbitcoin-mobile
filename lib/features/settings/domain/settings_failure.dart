import 'package:bb_mobile/core/failures/failure.dart';

sealed class SettingsFailure extends Failure {
  const SettingsFailure([super.logMessage]);
}

/// A setting could not be written, so the stored value still holds whatever it
/// held before — the toggle the user just moved did not stick.
final class SettingsStorageFailure extends SettingsFailure {
  const SettingsStorageFailure([super.logMessage]);
}

/// The user declined, or could not be shown, the consent a setting requires.
final class SettingsConsentFailure extends SettingsFailure {
  const SettingsConsentFailure([super.logMessage]);
}

/// Reading or attaching the diagnostic logs failed.
final class SettingsLogsFailure extends SettingsFailure {
  const SettingsLogsFailure([super.logMessage]);
}

/// The app-side setting saved, but mirroring it onto the exchange account
/// did not — the exchange still holds the previous value.
final class SettingsExchangeSyncFailure extends SettingsFailure {
  const SettingsExchangeSyncFailure([super.logMessage]);
}

/// Catch-all. [logMessage] is for logs ONLY and MUST never reach the UI —
/// the presentation extension returns the shared generic string.
final class SettingsUnexpectedFailure extends SettingsFailure {
  const SettingsUnexpectedFailure([super.logMessage]);
}
