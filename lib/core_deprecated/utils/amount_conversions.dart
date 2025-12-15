class ConvertAmount {
  static double satsToBtc(int satsValue) {
    final btcValue = satsValue / 100000000;
    return double.parse(btcValue.toStringAsFixed(8));
  }

  static int btcToSats(double btcValue) {
    return (btcValue * 100000000).round();
  }

  static double btcToFiat(double btcValue, double exchangeRate) {
    final fiatValue = btcValue * exchangeRate;
    return double.parse(fiatValue.toStringAsFixed(2));
  }

  static double fiatToBtc(double fiatValue, double exchangeRate) {
    final btcValue = fiatValue / exchangeRate;
    return double.parse(btcValue.toStringAsFixed(8));
  }

  static double satsToFiat(int satsValue, double exchangeRate) {
    final btcValue = satsToBtc(satsValue);
    return btcToFiat(btcValue, exchangeRate);
  }

  static int fiatToSats(double fiatValue, double exchangeRate) {
    final btcValue = fiatToBtc(fiatValue, exchangeRate);
    return btcToSats(btcValue);
  }
}
