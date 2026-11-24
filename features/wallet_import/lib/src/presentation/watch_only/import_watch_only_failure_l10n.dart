import 'package:wallet_import/src/presentation/import_l10n.dart';
import 'package:wallet_import/src/domain/import_failure.dart';
import 'package:flutter/widgets.dart';

/// User-facing, localized message for each [ImportWatchOnlyFailure]. The
/// `sealed` switch makes a missing message a compile error. Never returns the
/// raw `logMessage`.
extension ImportWatchOnlyFailureL10n on ImportWatchOnlyFailure {
  String toTranslated(BuildContext context) => switch (this) {
    NoWalletSelectedFailure() =>
      context.loc.importWatchOnlyErrorNoWalletSelected,
    LabelRequiredFailure() => context.loc.importWatchOnlyErrorLabelRequired,
    InvalidFormatFailure() => context.loc.importWatchOnlyErrorInvalidFormat,
    ImportFailedFailure() => context.loc.importWatchOnlyErrorImportFailed,
    NetworkMismatchFailure() => context.loc.importWatchOnlyErrorNetworkMismatch,
    WalletAlreadyExistsFailure() =>
      context.loc.importWatchOnlyErrorAlreadyExists,
  };
}
