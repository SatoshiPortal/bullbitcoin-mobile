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

  group('vault keys', () {
    test('normalizes case and whitespace without changing the key', () {
      expect(VaultKey('AB ' * 32).hex, 'ab' * 32);
    });

    test('rejects malformed keys without echoing them', () {
      const sentinel = 'SYNTHETIC_KEY_SENTINEL';
      for (final malformed in ['', '0' * 63, '0' * 65, sentinel]) {
        expect(
          () => VaultKey(malformed),
          throwsA(
            isA<FormatException>().having(
              (error) => error.toString(),
              'redacted message',
              isNot(contains(sentinel)),
            ),
          ),
        );
      }
    });
  });

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
      final vault = ok(await (await secretIn(secrets)).backup.recoverbull());

      // The property this whole group exists for: nothing a caller
      // receives contains the mnemonic.
      for (final word in {...words}) {
        expect(vault.vault.json, isNot(contains(word)));
      }
      expect(vault.toString(), isNot(contains(vault.key.hex)));
      expect(vault.key.toString(), isNot(contains(vault.key.hex)));
    });

    test('carries its derivation path so a restore can re-derive', () async {
      final vault = ok(await (await secretIn(secrets)).backup.recoverbull());

      expect(
        (jsonDecode(vault.vault.json) as Map<String, dynamic>)['path'],
        startsWith("1608'/0'/"),
      );
    });

    test('two vaults of one secret never share a key', () async {
      final secret = await secretIn(secrets);
      final first = ok(await secret.backup.recoverbull());
      final second = ok(await secret.backup.recoverbull());

      expect(second.key.hex, isNot(first.key.hex));
      expect(
        (jsonDecode(second.vault.json) as Map<String, dynamic>)['path'],
        isNot((jsonDecode(first.vault.json) as Map<String, dynamic>)['path']),
      );
    });

    test('the caller cannot overwrite the mnemonic field', () async {
      // A programmer error, not a runtime failure: the reserved key is documented, and `metadata` is the app's own fields. It throws, so it is caught in development rather than reported as a recoverable failure in production.
      final secret = await secretIn(secrets);
      await expectLater(
        secret.backup.recoverbull(
          metadata: const {
            'mnemonic': <String>['attacker'],
          },
        ),
        throwsArgumentError,
      );
    });
  });

  group('the vault contains only the words', () {
    const passphraseFingerprint = 'b4e3f5ed';
    String entryWith(String? passphrase) => jsonEncode({
      'mnemonicWords': words,
      'passphrase': passphrase,
      'runtimeType': 'mnemonic',
    });

    test('restoring with the passphrase restores the wallet', () async {
      // The caller supplies the passphrase separately at restore time; the vault itself carries only the words.
      final source = secretsWith(
        FakeSecureStoragePlatform(
          entries: {'seed_$passphraseFingerprint': entryWith('TREZOR')},
        ),
      );
      final secret = ok(await source.fetch(Fingerprint(passphraseFingerprint)));
      final vault = ok(await secret.backup.recoverbull());

      final without = secretsWith(FakeSecureStoragePlatform());
      final bare = ok(
        await without.recoverbull.restore(vault: vault.vault, key: vault.key),
      );
      expect(
        bare.secret.id.hex,
        plainFingerprint,
        reason: 'the file alone gives the passphrase-less sibling',
      );

      final with_ = secretsWith(FakeSecureStoragePlatform());
      final whole = ok(
        await with_.recoverbull.restore(
          vault: vault.vault,
          key: vault.key,
          passphrase: 'TREZOR',
        ),
      );
      expect(whole.secret.id.hex, passphraseFingerprint);
    });
  });

  group('restoring a vault', () {
    test(
      'repeated restoration keeps the existing secret byte for byte',
      () async {
        final secrets = secretsWith(
          FakeSecureStoragePlatform(
            entries: {'seed_$plainFingerprint': mnemonicEntry},
          ),
        );
        final backup = ok(await (await secretIn(secrets)).backup.recoverbull());
        final historical = jsonEncode({
          'runtimeType': 'mnemonic',
          'passphrase': null,
          'mnemonicWords': words,
        });
        final storage = FakeSecureStoragePlatform(
          entries: {'seed_$plainFingerprint': historical},
        );
        final target = secretsWith(storage);

        final first = ok(
          await target.recoverbull.restore(
            vault: backup.vault,
            key: backup.key,
          ),
        );
        final second = ok(
          await target.recoverbull.restore(
            vault: backup.vault,
            key: backup.key,
          ),
        );

        expect(first.secret.id, Fingerprint(plainFingerprint));
        expect(second.secret.id, first.secret.id);
        expect(storage.entries, {'seed_$plainFingerprint': historical});
      },
    );

    test('round-trips into a stored secret, words never surfacing', () async {
      final source = secretsWith(
        FakeSecureStoragePlatform(
          entries: {'seed_$plainFingerprint': mnemonicEntry},
        ),
      );
      final vault = ok(
        await (await secretIn(
          source,
        )).backup.recoverbull(metadata: const {'isPhysicalBackupTested': true}),
      );

      // A fresh device: nothing stored yet.
      final target = FakeSecureStoragePlatform();
      final restored = ok(
        await secretsWith(
          target,
        ).recoverbull.restore(vault: vault.vault, key: vault.key),
      );

      // Same wallet, filed under the same fingerprint.
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
      final vault = ok(await (await secretIn(source)).backup.recoverbull());

      final target = FakeSecureStoragePlatform();
      final result = await secretsWith(
        target,
      ).recoverbull.restore(vault: vault.vault, key: VaultKey('f' * 64));

      // Its own failure, not a storage one: the UI can say "wrong key"
      // rather than "could not save".
      expect(err(result), isA<InvalidVaultFailure>());
      expect(target.entries, isEmpty);
    });

    test('a file that is not a vault is refused', () async {
      final target = FakeSecureStoragePlatform();

      final result = await secretsWith(target).recoverbull.restore(
        vault: const EncryptedVault(json: 'not a vault'),
        key: VaultKey('f' * 64),
      );

      expect(err(result), isA<InvalidVaultFailure>());
      expect(target.entries, isEmpty);
    });

    test(
      'a vault whose words are regrouped into fewer elements is refused',
      () async {
        // bip39 joins the list and splits it straight back, so a list of
        // twelve elements whose join is a valid fifteen-word mnemonic used
        // to pass both the count check, which reads the list, and the
        // checksum check, which reads the sentence — and it is the list
        // that gets stored, rendered and compared. The join here is byte
        // for byte the published `abandon` fifteen-word vector.
        const fifteen = [
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
          'abandon',
          'abandon',
          'abandon',
          'address',
        ];
        final regrouped = <String>[
          '${fifteen[0]} ${fifteen[1]} ${fifteen[2]} ${fifteen[3]}',
          ...fifteen.sublist(4),
        ];
        expect(regrouped, hasLength(12));
        expect(regrouped.join(' '), fifteen.join(' '));

        final file = RecoverBull.createBackup(
          secret: utf8.encode(json.encode({'mnemonic': regrouped})),
          backupKey: List<int>.filled(32, 1),
        ).toJson();
        final target = FakeSecureStoragePlatform();

        final result = await secretsWith(target).recoverbull.restore(
          vault: EncryptedVault(json: file),
          key: VaultKey('01' * 32),
        );

        expect(err(result), isA<InvalidVaultFailure>());
        expect(target.entries, isEmpty);
      },
    );

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

      final result = await secretsWith(target).recoverbull.restore(
        vault: EncryptedVault(json: file),
        key: VaultKey('01' * 32),
      );

      expect(err(result), isA<InvalidVaultFailure>());
      expect(target.entries, isEmpty);
    });
  });

  group('inspecting a vault without storing its words', () {
    final key = VaultKey('01' * 32);

    EncryptedVault sealed(Map<String, dynamic> plaintext) => EncryptedVault(
      json: RecoverBull.createBackup(
        secret: utf8.encode(jsonEncode(plaintext)),
        backupKey: List<int>.filled(32, 1),
      ).toJson(),
    );

    test(
      'derives the fingerprint from words and ignores forged metadata',
      () async {
        final storage = _UntouchedStorage();
        final secrets = secretsWith(storage);
        final vault = sealed({
          'mnemonic': words,
          'fingerprint': 'deadbeef',
          'masterFingerprint': 'deadbeef',
        });

        expect(
          ok(await secrets.recoverbull.fingerprint(vault: vault, key: key)),
          Fingerprint(plainFingerprint),
        );
        expect(storage.calls, 0);
      },
    );

    test('a wrong key fails without touching the keystore', () async {
      final storage = _UntouchedStorage();
      final secrets = secretsWith(storage);

      final result = await secrets.recoverbull.fingerprint(
        vault: sealed({'mnemonic': words}),
        key: VaultKey('02' * 32),
      );

      expect(err(result), isA<InvalidVaultFailure>());
      expect(storage.calls, 0);
    });

    test('invalid words fail without touching the keystore', () async {
      final storage = _UntouchedStorage();
      final secrets = secretsWith(storage);
      const sentinel = 'SYNTHETIC_MNEMONIC_SENTINEL';

      final result = await secrets.recoverbull.fingerprint(
        vault: sealed({'mnemonic': List.filled(12, sentinel)}),
        key: key,
      );

      final failure = err(result);
      expect(failure, isA<InvalidVaultFailure>());
      expect(failure.logMessage, isNot(contains(sentinel)));
      expect(storage.calls, 0);
    });

    test('a malformed file fails without touching the keystore', () async {
      final storage = _UntouchedStorage();
      final secrets = secretsWith(storage);

      final result = await secrets.recoverbull.fingerprint(
        vault: const EncryptedVault(json: 'not a vault'),
        key: key,
      );

      expect(err(result), isA<InvalidVaultFailure>());
      expect(storage.calls, 0);
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

      test(
        '$label — inspection derives the original fingerprint without storage',
        () async {
          final storage = _UntouchedStorage();
          final secrets = secretsWith(storage);

          final fingerprint = ok(
            await secrets.recoverbull.fingerprint(
              vault: EncryptedVault(json: vector['file'] as String),
              key: VaultKey(vector['key'] as String),
            ),
          );

          expect(fingerprint, Fingerprint('3f635a63'));
          expect(storage.calls, 0);
        },
      );

      test('$label — the file opens and restores its words', () async {
        final secrets = secretsWith(FakeSecureStoragePlatform());

        final restored = ok(
          await secrets.recoverbull.restore(
            vault: EncryptedVault(json: vector['file'] as String),
            key: VaultKey(vector['key'] as String),
          ),
        );

        // Compared inside the package: the restored words are never read back out to be asserted on.
        expect(ok(await restored.secret.verify.mnemonic(vaultWords)), isTrue);
        expect(restored.metadata.containsKey('mnemonic'), isFalse);
      });
    }
  });
}

/// Any keystore access makes a stateless inspection fail, including reads that would otherwise return absence.
final class _UntouchedStorage extends FakeSecureStoragePlatform {
  int calls = 0;

  Never _access() {
    calls++;
    throw StateError('vault inspection must not access secure storage');
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => _access();

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async => _access();

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async => _access();

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async => _access();

  @override
  Future<void> deleteAll({required Map<String, String> options}) async =>
      _access();

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => _access();
}
