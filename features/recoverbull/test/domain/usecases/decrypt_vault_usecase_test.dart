import 'package:bull_recoverbull/src/domain/entities/decrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/entities/encrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/repositories/recoverbull_repository.dart';
import 'package:bull_recoverbull/src/domain/usecases/decrypt_vault_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _Repository extends Mock implements RecoverBullRepository {}

void main() {
  test('viewing a vault key does not mark the encrypted backup verified', () {
    final repository = _Repository();
    final vault = MockEncryptedVault();
    final decrypted = DecryptedVault(mnemonic: const ['abandon']);
    when(
      () => repository.restoreVault(vault: vault, vaultKey: 'key'),
    ).thenReturn(Ok(decrypted));

    final result = DecryptVaultUsecase(
      recoverBullRepository: repository,
    ).execute(vault: vault, vaultKey: 'key');

    result.fold(
      (value) => expect(value, decrypted),
      (failure) => fail('unexpected failure: $failure'),
    );
  });
}

class MockEncryptedVault extends Mock implements EncryptedVault {}
