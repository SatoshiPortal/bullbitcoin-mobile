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

/// The requested compact-block-filter wallet birthday could not be resolved
/// to a concrete checkpoint (see `WalletBirthdayCheckpointFailure`, lifted
/// from that core failure family at `ImportWalletUsecase`'s boundary — the
/// raw core type never reaches this feature's presentation layer). The user
/// can retry the same birthday or fall back to the earliest possible one
/// (genesis), which never requires a network lookup. [logMessage] is for
/// logs/Sentry ONLY and MUST never reach the UI.
final class ImportMnemonicBirthdayCheckpointFailure
    extends ImportMnemonicFailure {
  const ImportMnemonicBirthdayCheckpointFailure([super.logMessage]);
}
