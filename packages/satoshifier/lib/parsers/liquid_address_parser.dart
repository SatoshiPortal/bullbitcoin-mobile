import 'package:rust_bindings/lwk.dart' as lwk;
import 'package:satoshifier/satoshifier.dart';

class LiquidAddressParser {
  static Future<Satoshifier> parse(String data) async {
    try {
      final input = Utils.isUppercaseAlphanumeric(data)
          ? data.toLowerCase()
          : data;

      final lwkNetwork = await lwk.Address.validate(addressString: input);
      final network = Network.fromLwkNetwork(lwkNetwork);
      return Satoshifier.liquidAddress(address: data, network: network);
    } catch (e) {
      rethrow;
    }
  }

  static Future<Satoshifier?> tryParse(String data) async {
    try {
      return await parse(data);
    } catch (_) {
      return null;
    }
  }
}
