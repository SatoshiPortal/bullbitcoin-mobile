import 'package:satoshifier/satoshifier.dart';

typedef ParserFunction = Future<Satoshifier> Function(String data);

class Registry {
  Registry._();

  static final List<(Type, ParserFunction)> _parsers = [
    (BitcoinAddressParser, BitcoinAddressParser.parse),
    (Bip21Parser, Bip21Parser.parse),
    (PsbtParser, PsbtParser.parse),
    (Bolt11Parser, Bolt11Parser.parse),
    (LiquidAddressParser, LiquidAddressParser.parse),
    (WatchOnlyXpubParser, WatchOnlyXpubParser.parse),
    (WatchOnlyDescriptorParser, WatchOnlyDescriptorParser.parse),
    (LnurlParser, LnurlParser.parse),
  ];

  static Future<Satoshifier> parse(String data) async {
    if (data.trim().isEmpty) throw 'Input is empty';

    // bull_sdk init is the host app's responsibility (see README); calling
    // BullSdk.init() here would re-init flutter_rust_bridge and throw.
    final trimmed = data.trim();

    for (final (_, parser) in _parsers) {
      try {
        return await parser(trimmed);
      } catch (e) {
        continue;
      }
    }
    // Deliberately without the input. A user pasting a seed phrase or a
    // private key into a scan or send field is an ordinary mistake, and host
    // apps route uncaught errors to crash reporting and log files, so
    // anything interpolated here is persisted outside the app's control.
    throw 'No parser found for the given input '
        '(${data.length} characters)';
  }

  static Future<Satoshifier?> tryParse(String data) async {
    try {
      return await parse(data);
    } catch (_) {
      return null;
    }
  }
}
