final _keyOriginPattern = RegExp(r'\[([a-fA-F0-9]+)/(\d+h)/(\d+h)/\d+h\]');

/// Exports the key origin only if import can reconstruct the wallet's
/// derivation origin. The internal regtest suffix is outside that origin.
/// Liquid testnet and regtest share coin type 1 with Bitcoin testnet, so
/// their descriptor prefix cannot be recovered from a bare key origin.
String? bip329OriginFromWalletId(String walletId) {
  final start = walletId.indexOf('[');
  final end = walletId.indexOf(']');
  if (start == -1 || end <= start) return null;

  final keyOrigin = walletId.substring(start, end + 1);
  final roundTrip = _canonicalWalletOrigin(keyOrigin);
  if (roundTrip == null) return null;
  return walletId == roundTrip || walletId == '$roundTrip:regtest'
      ? keyOrigin
      : null;
}

/// Rebuilds the historical default-account descriptor without choosing an
/// active wallet network. An unsupported origin leaves the freeze unattributed.
String? walletIdFromBip329Origin(String? origin) =>
    origin == null ? null : _canonicalWalletOrigin(origin.replaceAll("'", 'h'));

String? _canonicalWalletOrigin(String keyOrigin) {
  final match = _keyOriginPattern.firstMatch(keyOrigin);
  final fingerprint = match?.group(1);
  final purpose = match?.group(2);
  final coinType = match?.group(3);
  if (fingerprint == null ||
      (coinType != '0h' && coinType != '1h' && coinType != '1776h')) {
    return null;
  }

  final prefix = coinType == '1776h' ? 'el' : '';
  final path = '[$fingerprint/$purpose/$coinType/0h]';
  return switch (purpose) {
    '84h' => '${prefix}wpkh($path)',
    '49h' => '${prefix}sh(wpkh($path))',
    '44h' => '${prefix}pkh($path)',
    _ => null,
  };
}
