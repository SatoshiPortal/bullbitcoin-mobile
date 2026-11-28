import 'dart:convert';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';

import '../domain/entities/encrypted_vault.dart';
import '../domain/entities/vault_passkey.dart';
import '../domain/passkey_password_port.dart';

/// Derives the RecoverBull server password without exposing the PRF to it.
final class PasskeyPasswordDeriver implements PasskeyPasswordPort {
  const PasskeyPasswordDeriver();

  /// The caller owns [prf] and must erase it after this operation.
  @override
  String derive(Uint8List prf, EncryptedVault vault) {
    final passkey = vault.passkey;
    if (prf.length != 32 || passkey == null) {
      throw ArgumentError('Missing passkey derivation input');
    }
    final data = BytesBuilder(copy: false);
    void append(List<int> value) {
      final size = ByteData(4)..setUint32(0, value.length, Endian.big);
      data.add(size.buffer.asUint8List());
      data.add(value);
    }

    append(utf8.encode('bull-recoverbull-passkey-password-v1'));
    append([VaultPasskey.version]);
    append(utf8.encode(passkey.rpId));
    append(passkey.credentialId);
    append(passkey.prfSalt);
    append(hex.decode(vault.id));
    append(hex.decode(vault.salt));
    append(sha256.convert(vault.ciphertext).bytes);
    final path = vault.derivationPath;
    append(path == null ? [0] : [1, ...utf8.encode(path)]);
    final timestamp = ByteData(8)
      ..setInt64(0, vault.createdAt.millisecondsSinceEpoch, Endian.big);
    append(timestamp.buffer.asUint8List());

    // HKDF-SHA256: one 32-byte expand block. All inputs are bound in info.
    final extracted = Uint8List.fromList(
      Hmac(sha256, Uint8List(32)).convert(prf).bytes,
    );
    try {
      final expanded = Uint8List.fromList(
        Hmac(sha256, extracted).convert([...data.takeBytes(), 1]).bytes,
      );
      try {
        return base64Url.encode(expanded).replaceAll('=', '');
      } finally {
        expanded.fillRange(0, expanded.length, 0);
      }
    } finally {
      extracted.fillRange(0, extracted.length, 0);
    }
  }
}
