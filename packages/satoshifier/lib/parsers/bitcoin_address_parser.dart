import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:satoshifier/satoshifier.dart';

class BitcoinAddressParser {
  static Future<Satoshifier> parse(String data) async {
    // Classify from the address encoding, then validate against that one
    // network. Previously this returned the first bdk.Network whose
    // constructor did not throw, so the answer was decided by the order of
    // bdk.Network.values rather than by the address: reordering that enum
    // upstream would have silently changed the result.
    final network = Network.fromBitcoinAddress(data);
    if (network == null) {
      throw 'Invalid bitcoin address';
    }

    try {
      bdk.Address(address: data, network: network.toBdk);
    } catch (_) {
      throw 'Invalid bitcoin address';
    }

    return Satoshifier.bitcoinAddress(address: data, network: network);
  }

  static Future<Satoshifier?> tryParse(String data) async {
    try {
      return await parse(data);
    } catch (_) {
      return null;
    }
  }
}
