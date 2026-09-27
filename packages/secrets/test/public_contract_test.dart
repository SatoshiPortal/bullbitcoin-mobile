import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

import 'result_helpers.dart';

void main() {
  final words = [...List.filled(11, 'abandon'), 'about'];
  final id = Fingerprint('73c5da0a');
  final entry = jsonEncode({
    'mnemonicWords': words,
    'passphrase': null,
    'runtimeType': 'mnemonic',
  });

  Secrets service(FakeSecureStoragePlatform storage) {
    storage.install();
    return Secrets(scratchDirectory: () async => '/tmp');
  }

  group('strict import', () {
    test(
      'a duplicate returns its fingerprint and preserves the exact bytes',
      () async {
        final historical = jsonEncode({
          'runtimeType': 'mnemonic',
          'passphrase': null,
          'mnemonicWords': words,
        });
        final storage = FakeSecureStoragePlatform(
          entries: {'seed_${id.hex}': historical},
        );
        final secrets = service(storage);

        for (final passphrase in [null, '']) {
          final failure = err(
            await secrets.import(words: words, passphrase: passphrase),
          );
          expect(
            failure,
            isA<SecretAlreadyExistsFailure>().having(
              (failure) => failure.id,
              'id',
              id,
            ),
          );
          expect(storage.entries, {'seed_${id.hex}': historical});
        }
      },
    );

    test(
      'two services racing to import produce one creation and one duplicate',
      () async {
        final storage = _RecordingStorage();
        final first = service(storage);
        final second = Secrets(scratchDirectory: () async => '/tmp');

        final results = await Future.wait([
          first.import(words: words),
          second.import(words: words),
        ]);

        final created = results
            .whereType<Ok<Secret, SecretFailure>>()
            .single
            .value;
        final duplicate = results
            .whereType<Err<Secret, SecretFailure>>()
            .single
            .failure;
        expect(created.id, id);
        expect(
          duplicate,
          isA<SecretAlreadyExistsFailure>().having(
            (failure) => failure.id,
            'id',
            id,
          ),
        );
        expect(
          storage.writes,
          [entry],
          reason: 'the losing import never rewrites the first value',
        );
        expect(storage.entries, {'seed_${id.hex}': storage.writes.single});
      },
    );
  });

  group('contains', () {
    test('stored checksum corruption is a read failure', () async {
      final corrupt = jsonEncode({
        'mnemonicWords': List.filled(12, 'abandon'),
        'passphrase': null,
        'runtimeType': 'mnemonic',
      });
      final storage = FakeSecureStoragePlatform(
        entries: {'seed_${id.hex}': corrupt},
      );
      final secrets = service(storage);

      expect(
        err(await secrets.contains(words: words)),
        isA<FetchSecretFailure>(),
      );
      expect(storage.entries, {'seed_${id.hex}': corrupt});
    });

    test('an invalid candidate remains an invalid mnemonic failure', () async {
      final storage = FakeSecureStoragePlatform();
      final secrets = service(storage);

      expect(
        err(await secrets.contains(words: List.filled(12, 'abandon'))),
        isA<InvalidMnemonicFailure>(),
      );
      expect(storage.reads, 0);
      expect(storage.entries, isEmpty);
    });

    test('matches words and passphrase without creating an entry', () async {
      final storage = FakeSecureStoragePlatform(
        entries: {'seed_${id.hex}': entry},
      );
      final secrets = service(storage);

      expect(ok(await secrets.contains(words: words)), isTrue);
      expect(
        ok(await secrets.contains(words: words, passphrase: 'TREZOR')),
        isFalse,
      );
      expect(storage.entries, {'seed_${id.hex}': entry});
    });

    test('a matching storage key alone is not a matching secret', () async {
      final stored = jsonEncode({
        'mnemonicWords': words,
        'passphrase': 'TREZOR',
        'runtimeType': 'mnemonic',
      });
      final storage = FakeSecureStoragePlatform(
        entries: {'seed_${id.hex}': stored},
      );
      final secrets = service(storage);

      expect(ok(await secrets.contains(words: words)), isFalse);
      expect(storage.entries, {'seed_${id.hex}': stored});
    });
  });

  group('seed verification', () {
    // Published BIP39 zero-entropy vector with the passphrase TREZOR, also pinned by bip39_mnemonic's vectors.dart.
    const seedHex =
        'c55257c360c07c72029aebc1b53c05ed0362ada38ead3e3e9efa3708e53495531f09a6987599d18264c1e1c92f2cf141630c7a3c4ab7c81b2f001698e7463b04';
    final protectedId = Fingerprint('b4e3f5ed');

    test(
      'mnemonic verification uses words while seed verification includes the passphrase',
      () async {
        final secrets = service(
          FakeSecureStoragePlatform(
            entries: {
              'seed_${id.hex}': entry,
              'seed_${protectedId.hex}': jsonEncode({
                'mnemonicWords': words,
                'passphrase': 'TREZOR',
                'runtimeType': 'mnemonic',
              }),
            },
          ),
        );
        final plain = ok(await secrets.fetch(id));
        final protected = ok(await secrets.fetch(protectedId));

        expect(ok(await plain.verify.mnemonic(words)), isTrue);
        expect(ok(await protected.verify.mnemonic(words)), isTrue);
        expect(ok(await protected.verify.seed(seedHex)), isTrue);
        expect(ok(await protected.verify.seed(seedHex.toUpperCase())), isTrue);
        expect(ok(await plain.verify.seed(seedHex)), isFalse);
      },
    );

    test(
      'legacy seeds verify every stored byte but cannot verify words',
      () async {
        final bytes = [
          for (var i = 0; i < seedHex.length; i += 2)
            int.parse(seedHex.substring(i, i + 2), radix: 16),
        ];
        final secrets = service(
          FakeSecureStoragePlatform(
            entries: {
              'seed_${protectedId.hex}': jsonEncode({
                'bytes': bytes,
                'runtimeType': 'bytes',
              }),
            },
          ),
        );
        final secret = ok(await secrets.fetch(protectedId));

        expect(secret.info.kind, SecretKind.seed);
        expect(ok(await secret.verify.seed(seedHex)), isTrue);
        expect(
          ok(await secret.verify.seed('00${seedHex.substring(2)}')),
          isFalse,
        );
        expect(
          err(await secret.verify.mnemonic(words)),
          isA<MnemonicRequiredFailure>(),
        );
        for (final invalid in ['', '0', 'gg' * 64, seedHex.substring(2)]) {
          expect(ok(await secret.verify.seed(invalid)), isFalse);
        }
      },
    );

    test(
      'an unavailable keystore produces an error, never a false comparison',
      () async {
        final storage = FakeSecureStoragePlatform(
          entries: {'seed_${id.hex}': entry},
        );
        final secret = ok(await service(storage).fetch(id));
        storage.locked = true;

        expect(
          err(await secret.verify.seed(seedHex)),
          isA<KeystoreLockedFailure>(),
        );
        expect(
          err(await secret.verify.mnemonic(words)),
          isA<KeystoreLockedFailure>(),
        );
      },
    );
  });

  test(
    'numeric programmer errors are rejected before any keystore read',
    () async {
      final storage = FakeSecureStoragePlatform(
        entries: {'seed_${id.hex}': entry},
      );
      final secret = ok(await service(storage).fetch(id));
      storage.locked = true;
      final before = storage.reads;

      for (final index in [-1, 0x80000000]) {
        expect(
          () => secret.derive.xpub(
            network: BitcoinNetwork.mainnet,
            scriptType: ScriptType.bip84,
            accountIndex: index,
          ),
          throwsArgumentError,
        );
        expect(
          () => secret.derive.descriptors.bitcoin(
            network: BitcoinNetwork.mainnet,
            scriptType: ScriptType.bip84,
            accountIndex: index,
          ),
          throwsArgumentError,
        );
        expect(
          () => secret.sign.psbt(
            'invalid psbt',
            network: BitcoinNetwork.mainnet,
            scriptType: ScriptType.bip84,
            accountIndex: index,
          ),
          throwsArgumentError,
        );
        expect(
          () => secret.derive.bip85.hex(numBytes: 32, index: index),
          throwsArgumentError,
        );
        expect(
          () => secret.derive.bip85.mnemonic(
            wordCount: MnemonicWordCount.words12,
            index: index,
          ),
          throwsArgumentError,
        );
      }
      for (final numBytes in [15, 65]) {
        expect(
          () => secret.derive.bip85.hex(numBytes: numBytes, index: 0),
          throwsArgumentError,
        );
      }
      expect(storage.reads, before);

      for (final index in [0, 0x7fffffff]) {
        expect(
          err(
            await secret.derive.xpub(
              network: BitcoinNetwork.mainnet,
              scriptType: ScriptType.bip84,
              accountIndex: index,
            ),
          ),
          isA<KeystoreLockedFailure>(),
        );
      }
      expect(
        storage.reads,
        before + 2,
        reason: 'both valid account boundaries reach storage',
      );
    },
  );
}

final class _RecordingStorage extends FakeSecureStoragePlatform {
  final writes = <String>[];

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    await super.write(key: key, value: value, options: options);
    writes.add(value);
  }
}
