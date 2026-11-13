import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/src/data/secrets_vault_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/secrets.dart' as custody;
import 'package:secrets/testing.dart';

void main() {
  test('a French mnemonic is sealed and restores to the same seed', () async {
    FakeSecureStoragePlatform().install();
    final secrets = custody.Secrets(scratchDirectory: () async => '.');
    // Published BIP39 zero-entropy vector in French, never a user's wallet.
    final words = [...List.filled(11, 'abaisser'), 'abeille'];
    final secret = switch (await secrets.import(
      words: words,
      language: custody.Language.french,
    )) {
      Ok(:final value) => value,
      Err() => throw StateError('public vector import failed'),
    };
    final repository = SecretsVaultRepository(secrets);

    final backup = switch (await repository.create(
      VaultContext(fingerprint: secret.id, network: BitcoinNetwork.mainnet),
    )) {
      Ok(:final value) => value,
      Err(:final failure) => fail('vault creation failed: $failure'),
    };

    // The vault carries the words' language: restoring them as English would
    // derive another seed, hence another fingerprint.
    switch (await secrets.trash(secret.id)) {
      case Ok():
        break;
      case Err(:final failure):
        fail('trash failed: $failure');
    }
    final restored = await secrets.recoverbull.restore(
      vault: custody.EncryptedVault(json: repository.encode(backup.vault)),
      key: backup.key,
    );
    switch (restored) {
      case Ok(:final value):
        expect(value.secret.id, secret.id);
      case Err(:final failure):
        fail('vault restoration failed: $failure');
    }
  });
}
