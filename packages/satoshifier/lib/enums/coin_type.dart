import 'package:satoshifier/enums/network.dart';

enum CoinType {
  bitcoin(0, 0x80000000),
  testnet(1, 0x80000001),
  liquid(1776, 0x800006f0);

  const CoinType(this.value, this.pathComponent);

  final int value;
  final int pathComponent;

  static CoinType fromInt(int number) {
    switch (number) {
      case 0:
        return CoinType.bitcoin;
      case 1:
        return CoinType.testnet;
      case 1776:
        return CoinType.liquid;
      default:
        throw 'Unhandled coin type: $number';
    }
  }

  Network toNetwork() {
    switch (this) {
      case CoinType.bitcoin:
        return Network.bitcoinMainnet;
      case CoinType.testnet:
        return Network.bitcoinTestnet;
      case CoinType.liquid:
        return Network.liquidMainnet;
    }
  }
}
