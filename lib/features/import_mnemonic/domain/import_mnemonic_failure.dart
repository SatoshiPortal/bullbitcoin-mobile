import 'package:primitives/primitives.dart' show Failure;

sealed class ImportMnemonicFailure extends Failure {
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

/// Guard: [ImportMnemonicCubit.import] called before mnemonic was set.
final class ImportMnemonicNullMnemonicFailure extends ImportMnemonicFailure {
  const ImportMnemonicNullMnemonicFailure();
}

/// Catch-all. [logMessage] is for logs/Sentry ONLY and MUST never reach the UI.
final class ImportMnemonicUnexpectedFailure extends ImportMnemonicFailure {
  const ImportMnemonicUnexpectedFailure([super.logMessage]);
}
