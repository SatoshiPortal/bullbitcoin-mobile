import 'package:bb_mobile/core/errors/bull_exception.dart';

/// No unspent, spendable UTXO exists to build a transaction from.
class NoSpendableUtxoException extends BullException {
  NoSpendableUtxoException(super.message);
}

/// A build failed because the wallet's confirmed L-BTC UTXO count exceeds
/// the Liquid confidential-tx input limit. Callers map this to their own
/// feature's typed exception/failure; never rethrow this type past the
/// use-case layer.
class LiquidInputLimitExceededException extends BullException {
  LiquidInputLimitExceededException(super.message);
}

/// Raised when the Liquid wallet holds more confirmed L-BTC UTXOs than a
/// single confidential transaction can spend; the wallet needs consolidating
/// before this send/swap can be built. Lives here (not inside `send`'s
/// domain) so any feature building a Liquid send/swap can catch it without
/// reaching into another feature's internals (AGENTS.md rule #1).
class ConsolidationRequiredException extends BullException {
  ConsolidationRequiredException(super.message);
}
