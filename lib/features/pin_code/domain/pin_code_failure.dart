import 'package:bb_mobile/core/failures/failure.dart';

/// Closed set of every failure the PIN-code flow surfaces to the user.
/// `sealed` keeps it closed (exhaustive switches; no foreign variants). Pure
/// Dart — the user-facing message lives in the presentation extension
/// `pin_code_failure_l10n.dart`, never here.
sealed class PinCodeFailure extends Failure {
  const PinCodeFailure([super.logMessage]);
}

final class PinCodeSaveFailure extends PinCodeFailure {
  const PinCodeSaveFailure();
}

final class PinCodeDeleteFailure extends PinCodeFailure {
  const PinCodeDeleteFailure();
}

final class PinCodeNotSetFailure extends PinCodeFailure {
  const PinCodeNotSetFailure();
}

/// Catch-all. [logMessage] is for logs ONLY and MUST never reach the UI —
/// the presentation extension returns the shared generic string.
final class PinCodeUnexpectedFailure extends PinCodeFailure {
  const PinCodeUnexpectedFailure([super.logMessage]);
}
