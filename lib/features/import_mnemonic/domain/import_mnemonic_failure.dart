import 'package:bb_mobile/core/failures/failure.dart';

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
