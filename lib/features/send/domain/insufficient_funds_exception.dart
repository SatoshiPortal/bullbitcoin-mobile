import 'package:bb_mobile/core/errors/bull_exception.dart';

/// The wallet's spendable coins don't cover the amount plus the network fee.
///
/// Thrown by both wallet datasources so callers can tell a shortfall apart
/// from a real build failure.
class InsufficientFundsException extends BullException {
  InsufficientFundsException(super.message);
}
