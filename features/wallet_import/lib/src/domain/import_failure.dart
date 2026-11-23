import 'package:primitives/primitives.dart' show Failure;

sealed class ImportFailure extends Failure {
  const ImportFailure([super.logMessage]);
}

/// The chain scan of one script type before import did not complete.
///
/// Informational: the import stays possible. Only the type is kept, never the words, descriptors or a foreign message.
sealed class ImportMnemonicScanFailure extends ImportFailure {
  const ImportMnemonicScanFailure([super.logMessage]);
}

/// No Electrum server could be reached, or none is configured.
final class ImportMnemonicScanServerUnavailableFailure
    extends ImportMnemonicScanFailure {
  const ImportMnemonicScanServerUnavailableFailure();
}

/// The server did not answer in time.
final class ImportMnemonicScanTimeoutFailure extends ImportMnemonicScanFailure {
  const ImportMnemonicScanTimeoutFailure();
}

/// The words did not derive to a wallet that can be scanned.
final class ImportMnemonicScanInvalidMnemonicFailure
    extends ImportMnemonicScanFailure {
  const ImportMnemonicScanInvalidMnemonicFailure();
}

/// This script cannot be imported in the selected network environment.
final class ImportMnemonicScanUnsupportedFailure
    extends ImportMnemonicScanFailure {
  const ImportMnemonicScanUnsupportedFailure();
}

/// Catch-all. [logMessage] holds the error type only and MUST never reach the UI.
final class ImportMnemonicScanUnexpectedFailure
    extends ImportMnemonicScanFailure {
  const ImportMnemonicScanUnexpectedFailure([super.logMessage]);
}

final class InvalidWatchOnlyInputFailure extends ImportFailure {
  const InvalidWatchOnlyInputFailure();
}

final class WatchOnlyNetworkMismatchFailure extends ImportFailure {
  const WatchOnlyNetworkMismatchFailure();
}
