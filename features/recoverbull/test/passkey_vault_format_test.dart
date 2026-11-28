import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:bull_recoverbull/src/data/mappers/encrypted_vault_mapper.dart';
import 'package:bull_recoverbull/src/domain/entities/encrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/entities/vault_passkey.dart';

void main() {
  final vault = EncryptedVault(
    id: 'ab' * 32,
    salt: 'cd' * 16,
    ciphertext: List.filled(64, 42),
    createdAt: DateTime.fromMillisecondsSinceEpoch(123456),
    derivationPath: "1608'/0'/1'",
    passkey: VaultPasskey(
      rpId: 'passkey.example.com',
      credentialId: [0, 128, 255],
      prfSalt: List.generate(32, (i) => i),
    ),
  );

  test('preserves passkey metadata across parse and serialization', () {
    final file = EncryptedVaultMapper.fromEntity(vault).toFile();
    final parsed = EncryptedVaultMapper.parse(file);
    expect(parsed.passkey?.rpId, 'passkey.example.com');
    expect(parsed.passkey?.credentialId, [0, 128, 255]);
    expect(parsed.passkey?.prfSalt, List.generate(32, (i) => i));
    expect(EncryptedVaultMapper.fromEntity(parsed).toFile(), file);
  });

  test('historical vault has no passkey block', () {
    final file = jsonDecode(
      EncryptedVaultMapper.fromEntity(vault).toFile(),
    ) as Map<String, dynamic>;
    file.remove('passkey');
    expect(EncryptedVaultMapper.parse(jsonEncode(file)).passkey, isNull);
  });

  test('rejects malformed and unknown passkey blocks', () {
    final file = jsonDecode(
      EncryptedVaultMapper.fromEntity(vault).toFile(),
    ) as Map<String, dynamic>;
    for (final invalid in [
      null,
      <String, Object>{},
      {
        'version': 1.0,
        'rp_id': 'passkey.example.com',
        'credential_id': 'AA',
        'prf_salt': base64Url.encode(List.filled(32, 0)).replaceAll('=', ''),
      },
      {
        'version': 2,
        'rp_id': 'passkey.example.com',
        'credential_id': 'AA',
        'prf_salt': 'AA',
      },
      {
        'version': 1,
        'rp_id': 'passkey.example.com',
        'credential_id': 'AA==',
        'prf_salt': 'AA',
      },
      {
        'version': 1,
        'rp_id': 'passkey.example.com',
        'credential_id': 'AA',
        'prf_salt': 'AA',
      },
    ]) {
      file['passkey'] = invalid;
      expect(
        () => EncryptedVaultMapper.parse(jsonEncode(file)),
        throwsFormatException,
      );
    }
  });
}
