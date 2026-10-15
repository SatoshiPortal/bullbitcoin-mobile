import 'package:bull_recoverbull/src/data/mappers/decrypted_vault_mapper.dart';
import 'package:bull_recoverbull/src/data/models/decrypted_vault_model.dart';
import 'package:bull_recoverbull/src/domain/entities/decrypted_vault.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preserves the existing vault map serialization contract', () {
    final encryptedBackup = DateTime.utc(2026, 8, 31, 12, 30);
    final physicalBackup = DateTime.utc(2026, 8, 30, 9, 15);
    final vault = DecryptedVault(
      mnemonic: const ['abandon', 'ability'],
      masterFingerprint: 'deadbeef',
      isEncryptedVaultTested: true,
      isPhysicalBackupTested: true,
      latestEncryptedBackup: encryptedBackup,
      latestPhysicalBackup: physicalBackup,
    );

    final encoded = DecryptedVaultMapper.fromEntity(vault).toMap();

    expect(encoded, {
      'mnemonic': ['abandon', 'ability'],
      'masterFingerprint': 'deadbeef',
      'isEncryptedVaultTested': true,
      'isPhysicalBackupTested': true,
      'latestEncryptedBackup': encryptedBackup.toIso8601String(),
      'latestPhysicalBackup': physicalBackup.toIso8601String(),
    });
    expect(
      DecryptedVaultMapper.toEntity(DecryptedVaultModel.fromMap(encoded)),
      vault,
    );
  });

  test('keeps mnemonic values immutable', () {
    final vault = DecryptedVault(mnemonic: ['abandon']);

    expect(() => vault.mnemonic.add('ability'), throwsUnsupportedError);
  });

  test('mnemonic input cannot mutate an existing domain vault', () {
    final words = ['abandon'];
    final vault = DecryptedVault(mnemonic: words);
    words.add('ability');
    expect(vault.mnemonic, ['abandon']);
  });

  test('copyWith can clear nullable backup timestamps', () {
    final vault = DecryptedVault(
      latestEncryptedBackup: DateTime.utc(2026, 8, 31),
      latestPhysicalBackup: DateTime.utc(2026, 8, 30),
    );

    expect(
      vault.copyWith(latestEncryptedBackup: null, latestPhysicalBackup: null),
      DecryptedVault(),
    );
  });
}
