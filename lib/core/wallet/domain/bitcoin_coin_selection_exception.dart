import 'package:bb_mobile/core/errors/bull_exception.dart';

sealed class BitcoinCoinSelectionException extends BullException {
  BitcoinCoinSelectionException(super.message);
}

final class SelectedBitcoinCoinsUnavailableException
    extends BitcoinCoinSelectionException {
  SelectedBitcoinCoinsUnavailableException()
    : super('One or more selected coins are no longer available');
}

final class SelectedBitcoinCoinsInsufficientException
    extends BitcoinCoinSelectionException {
  SelectedBitcoinCoinsInsufficientException()
    : super('Selected coins do not cover the amount and network fees');
}
