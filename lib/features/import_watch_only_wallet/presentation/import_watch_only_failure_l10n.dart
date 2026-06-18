import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/domain/import_watch_only_failure.dart';
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
        ImportWatchOnlyUnexpectedFailure() =>
          context.loc.oopsSomethingWentWrong,
      };
}
