import 'package:bb_mobile/core_deprecated/exchange/domain/entity/order.dart';

enum DcaBuyFrequency { hourly, daily, weekly, monthly }

enum DcaNetwork { bitcoin, lightning, liquid }

class Dca {
  final double amount;
  final FiatCurrency currency;
  final DcaBuyFrequency frequency;
  final DcaNetwork network;
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
