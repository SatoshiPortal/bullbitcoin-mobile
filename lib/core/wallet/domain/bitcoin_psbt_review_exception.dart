sealed class BitcoinPsbtReviewException implements Exception {
  const BitcoinPsbtReviewException();
}

final class InvalidBitcoinPsbtException extends BitcoinPsbtReviewException {
  const InvalidBitcoinPsbtException();
}

final class BitcoinPsbtWalletMismatchException
    extends BitcoinPsbtReviewException {
  const BitcoinPsbtWalletMismatchException();
}

final class BitcoinPsbtMissingLocalOriginException
    extends BitcoinPsbtReviewException {
  const BitcoinPsbtMissingLocalOriginException();
}

final class BitcoinPsbtMissingUtxoException extends BitcoinPsbtReviewException {
  const BitcoinPsbtMissingUtxoException();
}

final class BitcoinPsbtFrozenUtxoException extends BitcoinPsbtReviewException {
  const BitcoinPsbtFrozenUtxoException();
}

final class BitcoinPsbtUnsupportedSighashException
    extends BitcoinPsbtReviewException {
  const BitcoinPsbtUnsupportedSighashException();
}

final class BitcoinPsbtUnsupportedSpendModeException
    extends BitcoinPsbtReviewException {
  const BitcoinPsbtUnsupportedSpendModeException();
}
