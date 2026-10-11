import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// The BULL contract allows at most 1 MiB, including nonce and authentication.
final class WalletBackupCiphertext {
  static const maximumBytes = 1048576;
  final Uint8List _bytes;
  final String hash;

  factory WalletBackupCiphertext(List<int> bytes) {
    if (bytes.length < 64 ||
        bytes.length > maximumBytes ||
        bytes.length % 16 != 0 ||
        bytes.any((byte) => byte < 0 || byte > 255)) {
      throw const FormatException('Invalid encrypted backup length');
    }
    return WalletBackupCiphertext._(
      Uint8List.fromList(bytes),
      sha256.convert(bytes).toString(),
    );
  }

  const WalletBackupCiphertext._(this._bytes, this.hash);

  Uint8List get bytes => Uint8List.fromList(_bytes);
  int get length => _bytes.length;
}
