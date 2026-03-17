import 'package:bb_mobile/core/errors/bull_exception.dart';

class SwapCreationException extends BullException {
  SwapCreationException(super.message);
}

class InsufficientBalanceException extends BullException {
  InsufficientBalanceException([
    super.message = 'sendErrorInsufficientBalanceForPayment',
  ]);
}

class InvalidBitcoinStringException extends BullException {
  InvalidBitcoinStringException([
    super.message = 'sendErrorInvalidAddressOrInvoice',
  ]);
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
