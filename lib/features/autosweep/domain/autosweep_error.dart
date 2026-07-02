import 'package:bb_mobile/core/errors/bull_exception.dart';

sealed class AutosweepError extends BullException {
  AutosweepError(super.message);
}

/// A wallet lookup, address selection, or drain transaction
/// construction/signing operation failed in the underlying wallet stack.
final class AutosweepWalletOperationException extends AutosweepError {
  AutosweepWalletOperationException(super.message);
}

/// The sweep failed for a reason the feature does not classify further
/// (for example a broadcast failure).
final class AutosweepUnexpectedException extends AutosweepError {
  AutosweepUnexpectedException(super.message);
}
