class ReplaceByFeeError implements Exception {
  final String message;
  ReplaceByFeeError(this.message);

  @override
  String toString() => message;
}

class NoFeeRateSelectedError extends ReplaceByFeeError {
  NoFeeRateSelectedError() : super('Please select a fee rate');
}

class TransactionAlreadyConfirmedError extends ReplaceByFeeError {
  TransactionAlreadyConfirmedError()
    : super('The original transaction has been confirmed');
}

class FeeRateTooLowError extends ReplaceByFeeError {
  FeeRateTooLowError()
    : super(
        'You need to increase the fee rate by at least 1 sat/vbyte compared to the original transaction',
      );
}
