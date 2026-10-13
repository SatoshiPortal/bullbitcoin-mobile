import 'package:bull_recoverbull/src/domain/entities/encrypted_vault.dart';
import 'package:bull_recoverbull/src/data/mappers/encrypted_vault_mapper.dart';
import 'dart:convert';

import 'package:convert/convert.dart' as convert;
import 'package:flutter_test/flutter_test.dart';
import 'package:recoverbull/recoverbull.dart' as sdk;

void main() {
  final backup = sdk.RecoverBull.createBackup(
    secret: const [1, 2, 3],
    backupKey: List<int>.filled(32, 9),
  );

  test('domain invariants reject malformed identifiers and ciphertext', () {
    final valid = EncryptedVaultMapper.parse(backup.toJson());
    for (final (id, salt, ciphertext) in [
      ('bad-id', valid.salt, valid.ciphertext),
      (valid.id, 'bad-salt', valid.ciphertext),
      (valid.id, valid.salt, <int>[]),
      (valid.id, valid.salt, List<int>.filled(64, 256)),
    ]) {
      expect(
        () => EncryptedVault(
          id: id,
          salt: salt,
          ciphertext: ciphertext,
          createdAt: valid.createdAt,
        ),
        throwsArgumentError,
      );
    }
  });

  test('normalizes equivalent identifiers and salts', () {
    final valid = EncryptedVaultMapper.parse(backup.toJson());
    final vault = EncryptedVault(
      id: valid.id.toUpperCase(),
      salt: valid.salt.toUpperCase(),
      ciphertext: valid.ciphertext,
      createdAt: valid.createdAt,
    );
    expect(vault.id, valid.id);
    expect(vault.salt, valid.salt);
  });

  test('ciphertext is detached from input and immutable', () {
    final bytes = List<int>.filled(64, 0);
    final valid = EncryptedVaultMapper.parse(backup.toJson());
    final vault = EncryptedVault(
      id: valid.id,
      salt: valid.salt,
      ciphertext: bytes,
      createdAt: valid.createdAt,
    );
    bytes[0] = 1;
    expect(vault.ciphertext.first, 0);
    expect(() => vault.ciphertext[0] = 2, throwsUnsupportedError);
  });

  test('a valid file is parsed once and read back unchanged', () {
    final vault = EncryptedVaultMapper.parse(backup.toJson());

    expect(vault.id, convert.hex.encode(backup.id));
    expect(vault.salt, convert.hex.encode(backup.salt));
    expect(
      jsonDecode(EncryptedVaultMapper.fromEntity(vault).toFile()),
      jsonDecode(backup.toJson()),
    );
  });

  for (final (name, file) in [
    ('not JSON', '{not-json'),
    ('a JSON object without vault fields', '{"not":"a vault"}'),
    ('an empty string', ''),
  ]) {
    test('rejects $name at construction', () {
      expect(() => EncryptedVaultMapper.parse(file), throwsA(anything));
    });
  }
}
