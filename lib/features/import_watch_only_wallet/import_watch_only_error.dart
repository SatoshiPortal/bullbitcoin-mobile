import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/widgets.dart';

/// Closed set of every failure the watch-only import flow surfaces to the user.
/// `sealed` keeps it closed (no foreign variants; exhaustive switches). The
/// abstract `toTranslated` makes a user-facing message mandatory and keeps it
/// next to its variant.
sealed class ImportWatchOnlyError {
  const ImportWatchOnlyError();

  /// Localized, user-safe message. Never returns raw/technical detail.
  String toTranslated(BuildContext context);
}

final class NoWalletSelectedError extends ImportWatchOnlyError {
  const NoWalletSelectedError();

  @override
  String toTranslated(BuildContext context) =>
      context.loc.importWatchOnlyErrorNoWalletSelected;
}

final class LabelRequiredError extends ImportWatchOnlyError {
  const LabelRequiredError();

  @override
  String toTranslated(BuildContext context) =>
      context.loc.importWatchOnlyErrorLabelRequired;
}

final class InvalidFormatError extends ImportWatchOnlyError {
  const InvalidFormatError();

  @override
  String toTranslated(BuildContext context) =>
      context.loc.importWatchOnlyErrorInvalidFormat;
}

final class ImportFailedError extends ImportWatchOnlyError {
  const ImportFailedError();

  @override
  String toTranslated(BuildContext context) =>
      context.loc.importWatchOnlyErrorImportFailed;
}

/// Catch-all. [message] is for logs only and MUST never reach the UI —
/// `toTranslated` returns the shared generic string, not [message].
final class UnexpectedImportError extends ImportWatchOnlyError {
  final String message;

  const UnexpectedImportError(this.message);

  @override
  String toTranslated(BuildContext context) =>
      context.loc.oopsSomethingWentWrong;
}
