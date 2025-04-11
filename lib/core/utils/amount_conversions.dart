class AmountConversion {
  double satsToBtc(int satsValue) {
    final btcValue = satsValue / 100000000;
    return double.parse(btcValue.toStringAsFixed(8));
  }

  int btcToSats(double btcValue) {
    return (btcValue * 100000000).round();
  }

  double btcToFiat(double btcValue, double exchangeRate) {
    final fiatValue = btcValue * exchangeRate;
    return double.parse(fiatValue.toStringAsFixed(2));
  }

  double fiatToBtc(double fiatValue, double exchangeRate) {
    final btcValue = fiatValue / exchangeRate;
    return double.parse(btcValue.toStringAsFixed(8));
  }

  double satsToFiat(int satsValue, double exchangeRate) {
    final btcValue = satsToBtc(satsValue);
    return btcToFiat(btcValue, exchangeRate);
  }

  int fiatToSats(double fiatValue, double exchangeRate) {
    final btcValue = fiatToBtc(fiatValue, exchangeRate);
    return btcToSats(btcValue);
  }
}
