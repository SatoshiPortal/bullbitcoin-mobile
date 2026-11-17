import 'package:bull_sdk/boltz.dart' as boltz;
import 'package:satoshifier/satoshifier.dart';

class LnurlParser {
  static Future<Satoshifier> parse(String input) async {
    try {
      final normalized = input.trim().replaceFirst(
        RegExp(r'^lightning:', caseSensitive: false),
        '',
      );
      final isEmail = normalized.contains('@');
      final isPrefixed = normalized.toLowerCase().startsWith('lnurl');

      if (!isEmail && !isPrefixed) throw 'Invalid LNURL';

      final lnurl = boltz.Lnurl(value: normalized);
      final isValid = await lnurl.validate();
      if (!isValid) throw 'Invalid LNURL';

      return Satoshifier.lnurl(address: normalized);
    } catch (_) {
      rethrow;
    }
  }

  static Future<Satoshifier?> tryParse(String input) async {
    try {
      return await parse(input);
    } catch (_) {
      return null;
    }
  }
}
