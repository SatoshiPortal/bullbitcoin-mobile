import 'btc_network.dart';
import 'order.dart';

enum DcaBuyFrequency { hourly, daily, weekly, monthly }

class Dca {
  final double amount;
  final FiatCurrency currency;
  final DcaBuyFrequency frequency;
  final BtcNetwork network;
  final String address;
  final DateTime nextPurchaseDate;

  Dca({
    required this.amount,
    required this.currency,
    required this.frequency,
    required this.network,
    required this.address,
    required this.nextPurchaseDate,
  });
}
