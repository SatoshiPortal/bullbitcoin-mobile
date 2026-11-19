import 'package:bip21_uri/bip21_uri.dart';
import 'package:satoshifier/satoshifier.dart';

class Bip21Parser {
  static Future<Satoshifier> parse(String data) async {
    final uri = bip21.decode(data);

    Network network;
    switch (uri.scheme.toLowerCase()) {
      case 'bitcoin':
        final address = await BitcoinAddressParser.parse(uri.address);
        network = (address as BitcoinAddress).network;
      case 'liquid':
        final address = await LiquidAddressParser.parse(uri.address);
        network = (address as LiquidAddress).network;
      case 'liquidnetwork':
        final address = await LiquidAddressParser.parse(uri.address);
        network = (address as LiquidAddress).network;
      case 'liquidtestnet':
        final address = await LiquidAddressParser.parse(uri.address);
        network = (address as LiquidAddress).network;
      default:
        throw 'Unhandled BIP21 scheme: ${uri.scheme}';
    }

    // The address decides the network, so a scheme that claims a different one
    // has to be refused rather than carried alongside it. Satoshifier.bip21
    // exposes both `scheme` and `network`, and a consumer reading only one of
    // them would otherwise act on an unchecked, contradictory pair: a mainnet
    // Liquid address inside a 'liquidtestnet:' URI parsed cleanly and reported
    // liquidMainnet.
    if (!schemeMatchesNetwork(uri.scheme, network)) {
      throw FormatException(
        'BIP21 scheme ${uri.scheme} does not match the address network '
        '${network.name}',
      );
    }
    // The raw query string is the source of truth. The decoded double is only
    // a fallback, and toStringAsFixed(8) is used rather than toString()
    // because it is never rendered in scientific notation.
    final rawAmount = _rawAmount(data);
    final decodedAmount = uri.amount;
    final int sats;
    if (rawAmount != null) {
      sats = Utils.btcToSats(rawAmount);
    } else if (decodedAmount != null) {
      sats = Utils.btcToSats(decodedAmount.toStringAsFixed(8));
    } else {
      sats = 0;
    }

    return Satoshifier.bip21(
      scheme: uri.scheme,
      address: uri.address,
      uri: uri.toString(),
      network: network,
      label: uri.label ?? '',
      message: uri.message ?? '',
      sats: sats,
      lightning: uri.options['lightning'] as String? ?? '',
      pj: uri.options['pj'] as String? ?? '',
      pjos: uri.options['pjos'] as String? ?? '',
    );
  }

  /// Whether the network a URI scheme claims agrees with the network the
  /// address actually belongs to.
  ///
  /// `bitcoin:` is used for every Bitcoin chain by convention, so it only
  /// asserts that the address is a Bitcoin one; the Liquid schemes name their
  /// network and are held to it.
  static bool schemeMatchesNetwork(String scheme, Network network) {
    switch (scheme.toLowerCase()) {
      case 'bitcoin':
        return network.isBitcoin;
      case 'liquid':
      case 'liquidnetwork':
        return network == Network.liquidMainnet;
      case 'liquidtestnet':
        return network == Network.liquidTestnet;
      default:
        return false;
    }
  }

  /// Reads the `amount` parameter straight out of the URI query.
  ///
  /// The decoded model exposes the amount as a `double`, and
  /// `double.toString()` switches to scientific notation below 1e-6: a
  /// one-satoshi URI renders as `1e-8`, which [Utils.btcToSats] rejects. That
  /// made every BIP21 amount under 1000 sats fail to parse — and because
  /// [tryParse] swallows the exception, it failed silently. Keeping the
  /// original decimal string also keeps the satoshi conversion exact integer
  /// arithmetic instead of round-tripping through a binary float.
  ///
  /// The key lookup is case-insensitive: QR codes commonly carry the whole
  /// URI uppercased to use the denser alphanumeric mode, and the decoder only
  /// recognises a lowercase `amount`, so those URIs silently decoded to a null
  /// amount and a zero-sat result.
  static String? _rawAmount(String data) {
    final Map<String, String> query;
    try {
      final parsed = Uri.tryParse(data);
      if (parsed == null) return null;
      query = parsed.queryParameters;
    } on FormatException {
      return null;
    }
    for (final entry in query.entries) {
      if (entry.key.toLowerCase() != 'amount') continue;
      final value = entry.value.trim();
      return value.isEmpty ? null : value;
    }
    return null;
  }

  static Future<Satoshifier?> tryParse(String data) async {
    try {
      return await parse(data);
    } catch (_) {
      return null;
    }
  }
}
