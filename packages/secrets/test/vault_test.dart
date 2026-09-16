import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:recoverbull/recoverbull.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/src/crypto/crypto.dart' show Backup, Deriver;
import 'package:secrets/src/data/data.dart' show SecretRepository;

import 'fake_secure_storage_platform.dart';
import 'result_helpers.dart';

void main() {
  const words = [
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'about',
  ];
  const plainFingerprint = '73c5da0a';

  final mnemonicEntry = jsonEncode({
    'mnemonicWords': words,
    'passphrase': null,
    'runtimeType': 'mnemonic',
  });

  Secrets secretsWith(FakeSecureStoragePlatform storage) {
    storage.install();
    return Secrets(scratchDirectory: () async => '.');
  }

  Future<Secret> secretIn(Secrets secrets) async =>
      ok(await secrets.fetch(Fingerprint(plainFingerprint)));

  group('sealing a vault', () {
    late Secrets secrets;

    setUp(() {
      secrets = secretsWith(
        FakeSecureStoragePlatform(
          entries: {'seed_$plainFingerprint': mnemonicEntry},
        ),
      );
    });

    test('returns ciphertext, never the words', () async {
      final vault = anyScope(await (await secretIn(secrets)).backup.vault());

      // The property this whole group exists for: nothing a caller
      // receives contains the mnemonic.
      for (final word in {...words}) {
        expect(vault.file, isNot(contains(word)));
      }
      expect(vault.toString(), isNot(contains(vault.key)));
    });

    test('carries its derivation path so a restore can re-derive', () async {
      final vault = anyScope(await (await secretIn(secrets)).backup.vault());

      expect(vault.derivationPath, startsWith("1608'/0'/"));
      expect(
        (jsonDecode(vault.file) as Map<String, dynamic>)['path'],
        vault.derivationPath,
      );
    });

    test('two vaults of one secret never share a key', () async {
      final secret = await secretIn(secrets);
      final first = anyScope(await secret.backup.vault());
      final second = anyScope(await secret.backup.vault());

      expect(second.key, isNot(first.key));
      expect(second.derivationPath, isNot(first.derivationPath));
    });

    test('the caller cannot overwrite the mnemonic field', () async {
      // A programmer error, not a runtime failure: the reserved key is documented, and `metadata` is the app's own fields. It throws, so it is caught in development rather than reported as a recoverable failure in production.
      final secret = await secretIn(secrets);
      await expectLater(
        secret.backup.vault(
          metadata: const {
            'mnemonic': <String>['attacker'],
          },
        ),
        throwsArgumentError,
      );
    });
  });

  group('the passphrase is not in the file, and that is said', () {
    // Decision of 2026-09-15: the format does not change, so the caller is told instead — and the type makes it impossible to read the vault without meeting the case.
    const passphraseFingerprint = 'b4e3f5ed';
    String entryWith(String? passphrase) => jsonEncode({
      'mnemonicWords': words,
      'passphrase': passphrase,
      'runtimeType': 'mnemonic',
    });

    test('a secret without one seals as the whole secret', () async {
      final secrets = secretsWith(
        FakeSecureStoragePlatform(
          entries: {'seed_$plainFingerprint': entryWith(null)},
        ),
      );

      expect(
        ok(await (await secretIn(secrets)).backup.vault()),
        isA<WholeSecret<EncryptedVault>>(),
      );
    });

    test('a secret with one seals as words only', () async {
      final secrets = secretsWith(
        FakeSecureStoragePlatform(
          entries: {'seed_$passphraseFingerprint': entryWith('TREZOR')},
        ),
      );
      final secret = ok(
        await secrets.fetch(Fingerprint(passphraseFingerprint)),
      );

      expect(
        ok(await secret.backup.vault()),
        isA<WordsOnly<EncryptedVault>>(),
        reason: 'the file restores a different wallet; the caller must know',
      );
    });

    // The Liquid descriptor carries the same mark, and cannot be asserted
    // here: `liquidDescriptor` calls lwk before wrapping, so it needs the
    // FFI. What is checked instead is that it cannot disagree — one
    // private helper builds every scope, pinned in `invariants_test.dart`
    // — and the value itself lives in the integration suite.

    test('restoring with the passphrase restores the wallet', () async {
      // The path that makes the signal actionable: the user supplies the passphrase at restore time, and the words never leave the package to be re-imported.
      final source = secretsWith(
        FakeSecureStoragePlatform(
          entries: {'seed_$passphraseFingerprint': entryWith('TREZOR')},
        ),
      );
      final secret = ok(await source.fetch(Fingerprint(passphraseFingerprint)));
      final vault = anyScope(await secret.backup.vault());

      final without = secretsWith(FakeSecureStoragePlatform());
      final bare = ok(
        await without.restoreVault(file: vault.file, key: vault.key),
      );
      expect(bare, isA<WordsOnly<RestoredVault>>());
      expect(
        bare.value.secret.id.hex,
        plainFingerprint,
        reason: 'the file alone gives the passphrase-less sibling',
      );

      final with_ = secretsWith(FakeSecureStoragePlatform());
      final whole = ok(
        await with_.restoreVault(
          file: vault.file,
          key: vault.key,
          passphrase: 'TREZOR',
        ),
      );
      expect(whole, isA<WholeSecret<RestoredVault>>());
      expect(whole.value.secret.id.hex, passphraseFingerprint);
    });
  });

  group('restoring a vault', () {
    test('round-trips into a stored secret, words never surfacing', () async {
      final source = secretsWith(
        FakeSecureStoragePlatform(
          entries: {'seed_$plainFingerprint': mnemonicEntry},
        ),
      );
      final vault = anyScope(
        await (await secretIn(
          source,
        )).backup.vault(metadata: const {'isPhysicalBackupTested': true}),
      );

      // A fresh device: nothing stored yet.
      final target = FakeSecureStoragePlatform();
      final restored = anyScope(
        await secretsWith(
          target,
        ).restoreVault(file: vault.file, key: vault.key),
      );

      // Same wallet, filed under the same identity.
      expect(restored.secret.id.hex, plainFingerprint);
      expect(target.entries.keys, ['seed_$plainFingerprint']);
      // The caller's own fields come back; the words do not.
      expect(restored.metadata, {'isPhysicalBackupTested': true});
      expect(restored.metadata.containsKey('mnemonic'), isFalse);
      expect(restored.toString(), isNot(contains('abandon')));
    });

    test('a wrong key fails rather than restoring garbage', () async {
      final source = secretsWith(
        FakeSecureStoragePlatform(
          entries: {'seed_$plainFingerprint': mnemonicEntry},
        ),
      );
      final vault = anyScope(await (await secretIn(source)).backup.vault());

      final target = FakeSecureStoragePlatform();
      final result = await secretsWith(
        target,
      ).restoreVault(file: vault.file, key: 'f' * 64);

      // Its own failure, not a storage one: the UI can say "wrong key"
      // rather than "could not save".
      expect(err(result), isA<InvalidVaultFailure>());
      expect(target.entries, isEmpty);
    });

    test('a file that is not a vault is refused', () async {
      final target = FakeSecureStoragePlatform();

      final result = await secretsWith(
        target,
      ).restoreVault(file: 'not a vault', key: 'f' * 64);

      expect(err(result), isA<InvalidVaultFailure>());
      expect(target.entries, isEmpty);
    });

    test('a vault whose plaintext is not a word list is refused', () async {
      // Sealed directly with the library, bypassing `seal`, so the
      // plaintext can carry a shape `seal` would never write. Before the
      // check was made eager, `List.cast` let this through `open` and
      // it failed inside storage instead.
      final key = List<int>.filled(32, 1);
      final file = RecoverBull.createBackup(
        secret: utf8.encode(
          json.encode({
            'mnemonic': [1, 2, 3],
          }),
        ),
        backupKey: key,
      ).toJson();
      final target = FakeSecureStoragePlatform();

      final result = await secretsWith(
        target,
      ).restoreVault(file: file, key: '01' * 32);

      expect(err(result), isA<InvalidVaultFailure>());
      expect(target.entries, isEmpty);
    });
  });

  group('vaults already in users hands still open', () {
    // Two real vault files, taken from the app's own integration fixtures: one written by the pre-package path, one by the current one. They are the reason the format is frozen — a change here orphans a wallet whose only copy is that file.
    //
    // Their mnemonic is the public BIP39 vector for entropy ffffffff…ffff, not a user's.
    final vectors =
        (jsonDecode(
                  File(
                    'test/fixtures/recoverbull_vaults.json',
                  ).readAsStringSync(),
                )
                as List)
            .cast<Map<String, dynamic>>();

    const vaultWords = [
      'zoo',
      'zoo',
      'zoo',
      'zoo',
      'zoo',
      'zoo',
      'zoo',
      'zoo',
      'zoo',
      'zoo',
      'zoo',
      'wrong',
    ];

    for (final vector in vectors) {
      final label = vector['label'] as String;

      test('$label — the backup key is re-derived exactly', () async {
        FakeSecureStoragePlatform().install();
        final repository = SecretRepository();
        final info = ok(await repository.store(words: vaultWords));
        final material = ok(await repository.use(info, (m) => m));

        expect(
          Backup.recoverbull.backupKey(
            masterXprv: Deriver.bip85.root(material),
            path: vector['path'] as String,
          ),
          vector['key'],
        );
      });

      test('$label — the file opens and restores its words', () async {
        final secrets = secretsWith(FakeSecureStoragePlatform());

        final restored = anyScope(
          await secrets.restoreVault(
            file: vector['file'] as String,
            key: vector['key'] as String,
          ),
        );

        // Compared inside the package: the restored words are never read back out to be asserted on.
        expect(ok(await restored.secret.verifyWords(vaultWords)), isTrue);
        expect(restored.metadata.containsKey('mnemonic'), isFalse);
      });
    }
  });
}
