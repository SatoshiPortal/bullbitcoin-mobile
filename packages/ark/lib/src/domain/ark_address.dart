import 'package:primitives/primitives.dart';

/// Paste classifier only. Bech32m policy-version checksum + main/test HRP.
/// Testnet, signet and regtest share tark: only native quote can distinguish
/// the account's server/network and validate the policy and delivery payload.
bool isArkAddress(String input, {required BitcoinNetwork network}) {
  if (input.length > 4096 ||
      input.length < 12 ||
      input.trim() != input ||
      (input != input.toLowerCase() && input != input.toUpperCase())) {
    return false;
  }
  final text = input.toLowerCase();
  final separator = text.lastIndexOf('1');
  if (separator < 1 || separator + 7 >= text.length) return false;
  final hrp = text.substring(0, separator);
  if (hrp != (network == BitcoinNetwork.mainnet ? 'ark' : 'tark')) return false;
  const alphabet = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';
  final values = <int>[];
  for (final code in text.substring(separator + 1).codeUnits) {
    final value = alphabet.indexOf(String.fromCharCode(code));
    if (value < 0) return false;
    values.add(value);
  }
  if (values.first != 1 || values.length <= 7) return false;
  var checksum = 1;
  final expanded = [
    ...hrp.codeUnits.map((c) => c >> 5),
    0,
    ...hrp.codeUnits.map((c) => c & 31),
    ...values,
  ];
  const generators = [
    0x3b6a57b2,
    0x26508e6d,
    0x1ea119fa,
    0x3d4233dd,
    0x2a1462b3,
  ];
  for (final value in expanded) {
    final top = checksum >> 25;
    checksum = ((checksum & 0x1ffffff) << 5) ^ value;
    for (var bit = 0; bit < 5; bit++) {
      if (((top >> bit) & 1) != 0) checksum ^= generators[bit];
    }
  }
  return checksum == 0x2bc830a3;
}
