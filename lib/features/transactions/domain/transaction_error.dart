import 'package:bb_mobile/core/errors/bull_exception.dart';

class TransactionError extends BullException {
  TransactionError(super.message);
}

class TransactionNotFoundError extends TransactionError {
  TransactionNotFoundError() : super('Transaction not found');
}
