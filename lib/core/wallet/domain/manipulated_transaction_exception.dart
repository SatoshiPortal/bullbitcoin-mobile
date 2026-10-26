import 'package:bb_mobile/core/errors/bull_exception.dart';

/// A wallet transaction whose wallet-owned input signatures fail
/// verification. It cannot have been produced by this wallet's keys and was
/// most likely planted in the wallet's history by the connected Electrum
/// server to bait a fee bump that pays an attacker (GHSA-6jp4-8v48-cc5v).
class ManipulatedTransactionException extends BullException {
  ManipulatedTransactionException(super.message);
}
