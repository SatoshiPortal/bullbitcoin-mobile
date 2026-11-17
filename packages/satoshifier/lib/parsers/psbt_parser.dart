import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:satoshifier/satoshifier.dart';

class PsbtParser {
  static Future<Satoshifier> parse(String psbtBase64) async {
    try {
      final psbt = bdk.Psbt(psbtBase64: psbtBase64);
      return Satoshifier.psbt(psbt: psbt.serialize());
    } catch (_) {
      rethrow;
    }
  }

  static Future<Satoshifier?> tryParse(String psbtBase64) async {
    try {
      return await parse(psbtBase64);
    } catch (_) {
      return null;
    }
  }
}
