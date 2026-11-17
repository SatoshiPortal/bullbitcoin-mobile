import 'package:primitives/primitives.dart';

/// Why the merchants could not be loaded or updated.
sealed class BullMapFailure extends Failure {
  const BullMapFailure([super.logMessage]);
}

/// BTC Map could not be reached or answered with an error.
final class BullMapNetworkFailure extends BullMapFailure {
  const BullMapNetworkFailure([super.logMessage]);
}

/// The device cache could not be read, or BTC Map answered with something
/// that is not a list of places.
final class BullMapUnexpectedFailure extends BullMapFailure {
  const BullMapUnexpectedFailure([super.logMessage]);
}
