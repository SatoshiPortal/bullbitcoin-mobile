import 'package:primitives/primitives.dart' show Failure;

sealed class ImportMnemonicFailure extends Failure {
  const ImportMnemonicFailure([super.logMessage]);
}

final class ImportMnemonicDuplicateFailure extends ImportMnemonicFailure {
  const ImportMnemonicDuplicateFailure();
}

final class ImportMnemonicEmptyLabelFailure extends ImportMnemonicFailure {
  const ImportMnemonicEmptyLabelFailure();
}

/// Guard: [ImportMnemonicCubit.import] called before mnemonic was set.
final class ImportMnemonicNullMnemonicFailure extends ImportMnemonicFailure {
  const ImportMnemonicNullMnemonicFailure();
}

/// Catch-all. [logMessage] is for logs/Sentry ONLY and MUST never reach the UI.
final class ImportMnemonicUnexpectedFailure extends ImportMnemonicFailure {
  const ImportMnemonicUnexpectedFailure([super.logMessage]);
}

/// The chain scan of one script type before import did not complete.
///
/// Informational: the import stays possible. Only the type is kept, never the words, descriptors or a foreign message.
sealed class ImportMnemonicScanFailure extends ImportMnemonicFailure {
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

/// Catch-all. [logMessage] holds the error type only and MUST never reach the UI.
final class ImportMnemonicScanUnexpectedFailure
    extends ImportMnemonicScanFailure {
  const ImportMnemonicScanUnexpectedFailure([super.logMessage]);
}
