import 'dart:convert';
import 'dart:core';

const bip21 = BIP21Codec();

/// A codec that converts [BIP21]'s to [String] or [String]'s to [BIP21].
///
/// Reference: https://github.com/bitcoin/bips/blob/master/bip-0021.mediawiki
class BIP21Codec extends Codec<BIP21, String> {
  const BIP21Codec();

  @override
  BIP21Decoder get decoder => bip21Decoder;

  @override
  BIP21Encoder get encoder => bip21Encoder;

  @override
  BIP21 decode(String encoded, [String urnScheme = 'bitcoin']) {
    return decoder.convert(encoded, urnScheme);
  }

  @override
  String encode(BIP21 input) {
    return encoder.convert(input);
  }

  String tryEncode(
    String address, [
    Map<String, dynamic>? options,
    String urnScheme = 'bitcoin',
  ]) {
    return encode(BIP21(address, options ?? <String, dynamic>{}, urnScheme));
  }
}

/// The canonical instance of [BIP21Encoder].
const bip21Encoder = BIP21Encoder();

/// BIP21 Encoder
///
/// A converter that encodes [BIP21] to [String].
class BIP21Encoder extends Converter<BIP21, String> {
  const BIP21Encoder();

  @override
  String convert(BIP21 input) {
    final options = Map<String, dynamic>.from(input.options).map(
      (key, value) => MapEntry(
        Uri.encodeQueryComponent(key),
        value is num ? value : Uri.encodeQueryComponent(value as String),
      ),
    );
    if (options['amount'] != null) {
      final amount = num.tryParse(options['amount'].toString());
      if (amount == null || !amount.isFinite || amount < 0) {
        throw const FormatException('Invalid amount');
      }
    }

    final query = options.keys.map((key) => '$key=${options[key]}').join('&');

    return [
      input.urnScheme,
      ':',
      input.address,
      if (options.keys.isNotEmpty) '?' else '',
      query,
    ].join();
  }
}

/// The canonical instance of [BIP21Decoder].
const bip21Decoder = BIP21Decoder();

/// BIP21 Decoder
///
/// A converter that encodes [String] to [BIP21].
class BIP21Decoder extends Converter<String, BIP21> {
  const BIP21Decoder();

  @override
  BIP21 convert(String input, [String urnScheme = 'bitcoin']) {
    final urnSchemeActual = input.substring(0, urnScheme.length).toLowerCase();
    if (urnSchemeActual != urnScheme || input[urnScheme.length] != ':') {
      throw Exception('Invalid BIP21 URI: $input');
    }
    final split = input.indexOf('?');
    final address =
        input.substring(urnScheme.length + 1, split == -1 ? null : split);
    final query = split == -1 ? '' : input.substring(split + 1);
    final options = Map<String, dynamic>.from(Uri.splitQueryString(query));

    if (options.containsKey('amount')) {
      final amountStr = options['amount'].toString();
      final amountStrSplit = amountStr.split('.');
      String finalAmountInString = '';
      if (amountStr.contains('.')) {
        final int lastIndex =
            amountStrSplit[1].length < 8 ? amountStrSplit[1].length : 8;
        finalAmountInString =
            amountStrSplit[0] + '.' + amountStrSplit[1].substring(0, lastIndex);
      } else {
        finalAmountInString = amountStr;
      }
      final amount = num.tryParse(finalAmountInString);
      if (amount == null) {
        throw const FormatException('Invalid amount');
      }
      if (!amount.isFinite) throw const FormatException('Invalid amount');
      if (amount < 0) throw const FormatException('Invalid amount');
      options['amount'] = amount;
    }

    return BIP21(address, options);
  }
}

class BIP21 {
  BIP21(this.address, this.options, [this.urnScheme = 'bitcoin']);
  String urnScheme;

  /// Address
  String address;

  /// Query Options
  Map<String, dynamic> options;

  @override
  String toString() {
    return bip21.encode(this);
  }
}
