import 'package:bb_mobile/core/failures/failure.dart';

/// Closed set of every failure the labels feature surfaces to the user.
/// `sealed` keeps it closed (exhaustive switches; no foreign variants). Pure
/// Dart — the user-facing message lives in the presentation extension
/// `label_failure_l10n.dart`, never here.
sealed class LabelFailure extends Failure {
  const LabelFailure([super.logMessage]);
}

/// Catch-all. [logMessage] is for logs ONLY and MUST never reach the UI —
/// the presentation extension returns the shared generic string.
final class LabelUnexpectedFailure extends LabelFailure {
  const LabelUnexpectedFailure([super.logMessage]);
}
