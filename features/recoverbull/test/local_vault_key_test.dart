import 'dart:convert';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/src/data/secrets_vault_repository.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:bull_recoverbull/src/domain/usecases/derive_vault_key_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/secrets.dart' as custody;
import 'package:secrets/testing.dart';

void main() {
  late FakeSecureStoragePlatform storage;
  late custody.Secrets secrets;
  late SecretsVaultRepository repository;
  late DeriveVaultKeyUsecase usecase;
  late EncryptedVault vault;
  late VaultKey expectedKey;
  setUp(() async {
    storage = FakeSecureStoragePlatform()..install();
    secrets = custody.Secrets(scratchDirectory: () async => '.');
    final secret =
        (await secrets.import(words: [...List.filled(11, 'zoo'), 'wrong'])
                as Ok<custody.Secret, custody.SecretFailure>)
            .value;
    repository = SecretsVaultRepository(secrets);
    final backup =
        (await repository.create(
                  VaultContext(
                    fingerprint: secret.id,
                    network: BitcoinNetwork.mainnet,
                  ),
                )
                as Ok<VaultBackup, RecoverBullFailure>)
            .value;
    vault = backup.vault;
    expectedKey = backup.key;
    usecase = DeriveVaultKeyUsecase(repository);
  });
  test(
    'authenticates a server key without local seed access or writes',
    () async {
      storage.locked = true;
      storage.writesFail = true;
      expect(await repository.fingerprint(vault, expectedKey), isA<Ok>());
      expect(
        await repository.fingerprint(vault, VaultKey('11' * 32)),
        isA<Err>(),
      );
    },
  );
  test('finds the matching local mnemonic without changing storage', () async {
    expect(
      await secrets.import(words: [...List.filled(11, 'abandon'), 'about']),
      isA<Ok>(),
    );
    final reordered = Map<String, String>.fromEntries(
      storage.entries.entries.toList().reversed,
    );
    storage.entries
      ..clear()
      ..addAll(reordered);
    storage.writesFail = true;
    expect(
      (await usecase.execute(vault) as Ok<VaultKey, RecoverBullFailure>)
          .value
          .hex,
      expectedKey.hex,
    );
    expect(storage.entries, reordered);
  });
  test(
    'distinguishes unavailable seeds from seeds that cannot open the file',
    () async {
      final original = Map.of(storage.entries);
      storage.entries.clear();
      expect(
        (await usecase.execute(vault) as Err).failure,
        isA<VaultSeedUnavailableFailure>(),
      );
      expect(
        await secrets.import(words: [...List.filled(11, 'abandon'), 'about']),
        isA<Ok>(),
      );
      expect(
        (await usecase.execute(vault) as Err).failure,
        isA<VaultLocalKeyMismatchFailure>(),
      );
      storage.entries
        ..clear()
        ..addAll(original);
      storage.locked = true;
      expect(
        (await usecase.execute(vault) as Err).failure,
        isA<VaultSeedUnavailableFailure>(),
      );
    },
  );
  test('does not guess a missing derivation path', () async {
    final file = jsonDecode(repository.encode(vault)) as Map<String, dynamic>;
    file.remove('path');
    vault =
        (repository.parse(jsonEncode(file))
                as Ok<EncryptedVault, RecoverBullFailure>)
            .value;
    expect(
      (await usecase.execute(vault) as Err).failure,
      isA<VaultKeyPathUnavailableFailure>(),
    );
  });
}
