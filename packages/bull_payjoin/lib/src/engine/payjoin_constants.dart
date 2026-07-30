import 'dart:math';

abstract final class PayjoinConstants {
  static const ohttpRelayUrlsBase = [
    'https://ohttp.achow101.com',
    'https://pj.bobspacebkk.com',
    'https://ohttp.cakewallet.com',
  ];

  static List<String> get ohttpRelayUrls {
    final relays = [...ohttpRelayUrlsBase]..shuffle(Random.secure());
    return relays;
  }

  static const directoryUrl = 'https://payjo.in';
  static const directoryPollingInterval = 5;
  static const defaultExpireAfterSec = 60 * 60 * 24;
  static const defaultMinAmountSat = 10000;
}
