import 'dart:convert';
import 'dart:typed_data';

import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';

abstract final class WalletBackupFileSignature {
  static const domain = 'bullbitcoin-wallet-backup-file-v1';
  static final _publicKeyPattern = RegExp(r'^[0-9a-f]{64}$');
  static final _signaturePattern = RegExp(r'^[0-9a-f]{128}$');

  static Uint8List digest(Uint8List canonicalUnsignedJson) =>
      Uint8List.fromList(
        sha256.convert([
          ...utf8.encode(domain),
          0,
          ...canonicalUnsignedJson,
        ]).bytes,
      );

  static bool isValidSignature(String value) =>
      _signaturePattern.hasMatch(value);

  static bool verify({
    required Uint8List canonicalUnsignedJson,
    required String publicKeyHex,
    required String signatureHex,
  }) {
    if (!_publicKeyPattern.hasMatch(publicKeyHex) ||
        !_signaturePattern.hasMatch(signatureHex)) {
      return false;
    }
    try {
      return ECPublic.fromHex('02$publicKeyHex').verifyBip340Signature(
        digest: digest(canonicalUnsignedJson),
        signature: hex.decode(signatureHex),
        tweak: false,
      );
    } on Exception {
      return false;
    }
  }
}
