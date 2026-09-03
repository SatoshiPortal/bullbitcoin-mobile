import 'package:bb_mobile/core/errors/bull_exception.dart';

class ApiKeyException extends BullException {
  ApiKeyException(super.message);
}

/// No exchange API key is stored; the user has to log in first.
class ApiKeyNotFoundException extends ApiKeyException {
  ApiKeyNotFoundException()
    : super('API key not found. Please login to your Bull Bitcoin account.');
}

/// The stored exchange API key is no longer active.
class ApiKeyInactiveException extends ApiKeyException {
  ApiKeyInactiveException()
    : super(
        'API key is inactive. Please login again to your Bull Bitcoin account.',
      );
}

/// The API returned an order of a different type than the endpoint implies.
class UnexpectedOrderTypeException extends BullException {
  UnexpectedOrderTypeException(String expected)
    : super('Expected $expected but received a different order type');
}

/// The API rejected an order because the amount is under its minimum.
///
/// Declared here rather than beside the datasource that throws it.
class BullBitcoinApiMinAmountException extends BullException {
  final double minAmount;
  final String currency;

  BullBitcoinApiMinAmountException({
    required this.minAmount,
    required this.currency,
  }) : super('Minimum amount is $minAmount $currency');
}

/// The API rejected an order because the amount is over its maximum. See
/// [BullBitcoinApiMinAmountException] for why this lives here.
class BullBitcoinApiMaxAmountException extends BullException {
  final double maxAmount;
  final String currency;

  BullBitcoinApiMaxAmountException({
    required this.maxAmount,
    required this.currency,
  }) : super('Maximum amount is $maxAmount $currency');
}
