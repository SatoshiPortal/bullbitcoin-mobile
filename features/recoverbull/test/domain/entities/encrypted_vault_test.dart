import 'dart:convert';

import 'package:bull_recoverbull/src/domain/entities/encrypted_vault.dart';
import 'package:convert/convert.dart' as convert;
import 'package:flutter_test/flutter_test.dart';
import 'package:recoverbull/recoverbull.dart' as sdk;

void main() {
  final backup = sdk.RecoverBull.createBackup(
    secret: const [1, 2, 3],
    backupKey: List<int>.filled(32, 9),
  );

  test('a valid file is parsed once and read back unchanged', () {
    final vault = EncryptedVault(file: backup.toJson());

    expect(vault.id, convert.hex.encode(backup.id));
    expect(vault.salt, convert.hex.encode(backup.salt));
    expect(jsonDecode(vault.toFile()), jsonDecode(backup.toJson()));
  });

  for (final (name, file) in [
    ('not JSON', '{not-json'),
    ('a JSON object without vault fields', '{"not":"a vault"}'),
    ('an empty string', ''),
  ]) {
    test('rejects $name at construction', () {
      expect(EncryptedVault.isValid(file), isFalse);
      expect(() => EncryptedVault(file: file), throwsA(anything));
    });
  }
}
