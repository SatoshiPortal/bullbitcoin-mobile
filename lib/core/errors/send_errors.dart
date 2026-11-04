import 'package:primitives/primitives.dart' show BullException;

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
