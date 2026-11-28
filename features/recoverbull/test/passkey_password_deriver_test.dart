import 'dart:typed_data';

import 'package:bull_recoverbull/src/data/passkey_password_deriver.dart';
import 'package:bull_recoverbull/src/domain/entities/encrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/entities/vault_passkey.dart';
import 'package:flutter_test/flutter_test.dart';

EncryptedVault vault({
  String id =
      'abababababababababababababababababababababababababababababababab',
  String salt = 'cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd',
  int ciphertextByte = 42,
  int timestamp = 123456,
  String path = "1608'/0'/1'",
  String rpId = 'passkey.example.com',
  List<int> credentialId = const [0, 128, 255],
  int saltOffset = 0,
}) => EncryptedVault(
  id: id,
  salt: salt,
  ciphertext: List.filled(64, ciphertextByte),
  createdAt: DateTime.fromMillisecondsSinceEpoch(timestamp),
  derivationPath: path,
  passkey: VaultPasskey(
    rpId: rpId,
    credentialId: credentialId,
    prfSalt: List.generate(32, (i) => i + saltOffset),
  ),
);

void main() {
  const deriver = PasskeyPasswordDeriver();
  final prf = Uint8List.fromList(List.generate(32, (i) => i));

  test('matches independent HKDF-SHA256 vector', () {
    expect(
      deriver.derive(prf, vault()),
      'OKCqy1EWTSMrtDwvszBI0qwQsTa-qhG3__j9Jg_lZ4Q',
    );
  });

  test('binds every public context field', () {
    final expected = deriver.derive(prf, vault());
    for (final changed in [
      vault(id: 'ab' * 31 + 'ac'),
      vault(salt: 'cd' * 15 + 'ce'),
      vault(ciphertextByte: 41),
      vault(timestamp: 123457),
      vault(path: "1608'/0'/2'"),
      vault(rpId: 'other.example.com'),
      vault(credentialId: [1, 128, 255]),
      vault(saltOffset: 1),
    ]) {
      expect(deriver.derive(prf, changed), isNot(expected));
    }
    expect(() => deriver.derive(Uint8List(31), vault()), throwsArgumentError);
  });
}
