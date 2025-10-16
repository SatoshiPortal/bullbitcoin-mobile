import 'package:bb_mobile/core/errors/bull_exception.dart';

class SwapCreationException extends BullException {
  SwapCreationException(super.message);

  String get displayMessage => 'Failed to create swap.';
}

class InsufficientBalanceException extends BullException {
  InsufficientBalanceException([
    super.message = 'Not enough balance to cover this payment',
  ]);
}

class InvalidBitcoinStringException extends BullException {
  InvalidBitcoinStringException([
    super.message = 'Invalid Bitcoin Payment Address or Invoice',
  ]);
}

class SwapLimitsException extends BullException {
  SwapLimitsException(super.message);
}

class BuildTransactionException extends BullException {
  BuildTransactionException(super.message);

  String get title => 'Build Failed';
}

class ConfirmTransactionException extends BullException {
  ConfirmTransactionException(super.message);

  String get title => 'Confirmation Failed';
}

class BroadcastTransactionException extends BullException {
  BroadcastTransactionException(super.message);

  String get title => 'Broadcast Failed';
}
