import 'package:primitives/legacy_exceptions.dart';

class SwapCreationException extends BullException {
  SwapCreationException(super.message);
}

class InsufficientFundsSwapException extends SwapCreationException {
  InsufficientFundsSwapException() : super('insufficient_funds');
}

class InsufficientBalanceException extends BullException {
  InsufficientBalanceException(super.message);
}

class InvalidBitcoinStringException extends BullException {
  InvalidBitcoinStringException(super.message);
}

class SwapLimitsException extends BullException {
  SwapLimitsException(super.message);
}

class BuildTransactionException extends BullException {
  BuildTransactionException(super.message);
}

class ConfirmTransactionException extends BullException {
  ConfirmTransactionException(super.message);
}

class BroadcastTransactionException extends BullException {
  BroadcastTransactionException(super.message);
}

/// Raised when a Liquid wallet holds more confirmed L-BTC UTXOs than a
/// single confidential transaction can spend; the wallet needs consolidating
/// before this send/swap can be built.
///
/// Lives here (a pure, Flutter-free domain file with no repository/datasource
/// dependency) rather than inside `lwk_wallet_datasource.dart`, so it can be
/// imported both by the `data/` layer that throws it and by the `domain`/
/// `presentation` layers (across the `send` and `swap` features) that catch
/// it, without either direction crossing the domain/data boundary the wrong
/// way (AGENTS.md rule #6).
class ConsolidationRequiredException extends BullException {
  ConsolidationRequiredException(super.message);
}
