class ReplaceByFeeError implements Exception {
  final String message;
  ReplaceByFeeError(this.message);

  @override
  String toString() => message;
}

class NoFeeRateSelectedError extends ReplaceByFeeError {
  NoFeeRateSelectedError() : super('Please select a fee rate');
}

class ReplaceByFeeUsecaseError extends ReplaceByFeeError {
  ReplaceByFeeUsecaseError(super.message);
}
