import 'package:rust_bindings/boltz.dart' as boltz;
import 'package:satoshifier/satoshifier.dart';

class Bolt11Parser {
  static Future<Satoshifier> parse(String data) async {
    try {
      final input = Utils.isUppercaseAlphanumeric(data)
          ? data.toLowerCase()
          : data;

      final invoice = await boltz.DecodedInvoice.fromString(s: input);
      final msats = invoice.msats.toInt();
      final sats = Utils.msatsToSats(msats);

      return Satoshifier.bolt11(
        invoice: data,
        sats: sats,
        msats: msats,
        paymentHash: invoice.preimageHash,
        description: invoice.description,
        expiresAt: invoice.expiresAt.toInt(),
        isTestnet: invoice.network != 'bitcoin',
      );
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
