class SwapCreationException implements Exception {
  final String message;

  SwapCreationException(this.message);

  @override
  String toString() => message;
  String get displayMessage => 'Failed to create swap.';
}

class InsufficientBalanceException implements Exception {
  final String message;

  InsufficientBalanceException({
    this.message = 'Not enough balance to cover this payment',
  });

  @override
  String toString() => message;
}

class InvalidBitcoinStringException implements Exception {
  final String message;

  InvalidBitcoinStringException({
    this.message = 'Invalid Bitcoin Payment Address or Invoice',
  });

  @override
  String toString() => message;
}

class SwapLimitsException implements Exception {
  final String message;

  SwapLimitsException(this.message);

  @override
  String toString() => message;
}

class BuildTransactionException implements Exception {
  final String message;

  BuildTransactionException(this.message);

  @override
  String toString() => message;

  String get title => 'Build Failed';
}

class ConfirmTransactionException implements Exception {
  final String message;

  ConfirmTransactionException(this.message);

  @override
  String toString() => message;

  String get title => 'Confirmation Failed';
}

class BroadcastTransactionException implements Exception {
  final String message;

  BroadcastTransactionException(this.message);

  @override
  String toString() => message;

  String get title => 'Broadcast Failed';
}
