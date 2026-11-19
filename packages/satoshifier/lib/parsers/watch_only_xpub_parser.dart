import 'package:satoshifier/satoshifier.dart';

class WatchOnlyXpubParser {
  static Future<Satoshifier> parse(String data) async {
    try {
      final extendedPubkey = ExtendedPubkey.parse(data);
      return Satoshifier.watchOnlyXpub(extendedPubkey: extendedPubkey);
    } catch (_) {}

    throw 'Invalid watch only xpub';
  }

  static Future<Satoshifier?> tryParse(String data) async {
    try {
      return await parse(data);
    } catch (_) {
      return null;
    }
  }
}
