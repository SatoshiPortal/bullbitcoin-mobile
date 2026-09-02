import 'package:bb_mobile/core/errors/bull_exception.dart';

class ApiKeyException extends BullException {
  ApiKeyException(super.message);
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
