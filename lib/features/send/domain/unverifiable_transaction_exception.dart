import 'package:bb_mobile/core/errors/bull_exception.dart';

/// A wallet transaction whose input signatures could not be verified —
/// missing from the local store, or no wallet-owned prevout could be
/// resolved. Not proof of manipulation, but operations that trust the
/// stored transaction (fee bumping) must refuse it all the same.
class UnverifiableTransactionException extends BullException {
  UnverifiableTransactionException(super.message);
}
