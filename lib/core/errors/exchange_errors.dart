import 'package:bb_mobile/core/errors/bull_exception.dart';

class ApiKeyException extends BullException {
  ApiKeyException(super.message);
}

/// No exchange API key is stored; the user has to log in first.
class ApiKeyNotFoundException extends ApiKeyException {
  ApiKeyNotFoundException()
    : super('API key not found. Please login to your Bull Bitcoin account.');
}

/// A stored exchange credential could not be read or validated. Retrying must
/// not be presented as a logout or reported as an unexpected application bug.
final class ExchangeCredentialUnavailableException implements Exception {
  const ExchangeCredentialUnavailableException();

  @override
  String toString() => 'Exchange credential unavailable';
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

/// The API rejected a Confidential SEPA order because the recipient's virtual
/// payee is not active yet. See [BullBitcoinApiMinAmountException] for why
/// this lives here.
class BullBitcoinApiConfidentialSepaNotActivatedException implements Exception {
  const BullBitcoinApiConfidentialSepaNotActivatedException();
}
