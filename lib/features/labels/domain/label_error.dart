import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/widgets.dart';

/// Closed set of every failure the labels feature surfaces to the user.
/// `sealed` keeps it closed (no foreign variants; exhaustive switches). The
/// abstract `toTranslated` makes a user-facing message mandatory and keeps it
/// next to its variant.
sealed class LabelError {
  const LabelError();

  /// Localized, user-safe message. Never returns raw/technical detail.
  String toTranslated(BuildContext context);
}

final class LabelNotFound extends LabelError {
  final String label;

  const LabelNotFound({required this.label});

  @override
  String toTranslated(BuildContext context) =>
      context.loc.labelErrorNotFound(label);
}

final class UnsupportedLabelType extends LabelError {
  const UnsupportedLabelType();

  @override
  String toTranslated(BuildContext context) =>
      context.loc.labelErrorUnsupportedType;
}

final class SystemLabelCannotBeDeletedError extends LabelError {
  const SystemLabelCannotBeDeletedError();

  @override
  String toTranslated(BuildContext context) =>
      context.loc.labelErrorSystemCannotDelete;
}

/// Catch-all. [message] is for logs only and MUST never reach the UI —
/// `toTranslated` returns the shared generic string, not [message].
final class UnexpectedLabelError extends LabelError {
  final String? message;

  const UnexpectedLabelError(this.message);

  @override
  String toTranslated(BuildContext context) =>
      context.loc.oopsSomethingWentWrong;
}
