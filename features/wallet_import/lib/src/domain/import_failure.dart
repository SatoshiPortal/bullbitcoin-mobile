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

sealed class ImportMnemonicFailure extends ImportFailure {
  const ImportMnemonicFailure([super.logMessage]);
}

/// Custody state needs explicit repair; importing must not reset its evidence.
final class ImportMnemonicCustodyMetadataFailure extends ImportMnemonicFailure {
  const ImportMnemonicCustodyMetadataFailure();
}

final class ImportMnemonicDuplicateFailure extends ImportMnemonicFailure {
  const ImportMnemonicDuplicateFailure();
}

final class ImportMnemonicEmptyLabelFailure extends ImportMnemonicFailure {
  const ImportMnemonicEmptyLabelFailure();
}

/// Import was requested before the mnemonic was set.
final class ImportMnemonicNullMnemonicFailure extends ImportMnemonicFailure {
  const ImportMnemonicNullMnemonicFailure();
}

/// Catch-all. [logMessage] is for logs/Sentry ONLY and MUST never reach the UI.
final class ImportMnemonicUnexpectedFailure extends ImportMnemonicFailure {
  const ImportMnemonicUnexpectedFailure([super.logMessage]);
}

/// Closed set of every failure the watch-only import flow surfaces to the user.
/// `sealed` keeps it closed (exhaustive switches; no foreign variants). Pure
/// Dart — the user-facing message lives in the presentation extension
/// `import_watch_only_failure_l10n.dart`, never here.
sealed class ImportWatchOnlyFailure extends ImportFailure {
  const ImportWatchOnlyFailure([super.logMessage]);
}

final class NoWalletSelectedFailure extends ImportWatchOnlyFailure {
  const NoWalletSelectedFailure();
}

final class LabelRequiredFailure extends ImportWatchOnlyFailure {
  const LabelRequiredFailure();
}

final class InvalidFormatFailure extends ImportWatchOnlyFailure {
  const InvalidFormatFailure();
}

final class ImportFailedFailure extends ImportWatchOnlyFailure {
  const ImportFailedFailure();
}

final class NetworkMismatchFailure extends ImportWatchOnlyFailure {
  const NetworkMismatchFailure();
}

final class WalletAlreadyExistsFailure extends ImportWatchOnlyFailure {
  const WalletAlreadyExistsFailure();
}
