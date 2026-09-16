import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:recoverbull/recoverbull.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

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
  final id = Fingerprint('73c5da0a');

  final mnemonicEntry = jsonEncode({
    'mnemonicWords': words,
    'passphrase': null,
    'runtimeType': 'mnemonic',
  });
  final bytesEntry = jsonEncode({
    'bytes': List<int>.filled(64, 7),
    'runtimeType': 'bytes',
  });

  // `Secrets` builds its own keystore from a `Keystore` value in
  // production; only this package can substitute one.
  // Nothing under test signs, so the scratch directory lwk would use is
  // never reached.
  Secrets secretsWith(FakeSecureStoragePlatform storage) {
    storage.install();
    return Secrets(scratchDirectory: () async => Directory.systemTemp.path);
  }

  group('a sealed keystore is not a missing secret', () {
    // The property this whole distinction exists for. If a locked
    // keychain reported "not found", callers such as
    // CheckForExistingDefaultWalletsUsecase would read a transient,
    // self-healing state as "the wallet seed is gone" and could offer a
    // destructive recovery flow.
    test('info reports the lock, not an absence', () async {
      final secrets = secretsWith(
        FakeSecureStoragePlatform(
          entries: {'seed_73c5da0a': mnemonicEntry},
          locked: true,
        ),
      );

      final result = await secrets.fetch(id);

      expect(result, isA<Err<Secret, SecretFailure>>());
      final failure = (result as Err<Secret, SecretFailure>).failure;
      expect(failure, isA<SecretStoreLockedFailure>());
      expect(failure, isNot(isA<SecretNotFoundFailure>()));
    });

    test(
      'a genuinely absent secret still reports not-found',
      () async {
        final secrets = secretsWith(FakeSecureStoragePlatform());

        final result = await secrets.fetch(id);

        expect(
          (result as Err<Secret, SecretFailure>).failure,
          isA<SecretNotFoundFailure>(),
        );
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );

    test('every wire shape of -25308 is recognised as a lock', () async {
      // The plugin has carried this OSStatus in `details`, in `code` as
      // a string, and inside `message`, across versions. All three are
      // matched, and this is the first test that can say so: the
      // translation lives under the package's own storage instance, so
      // it is only reachable by faking the plugin's platform.
      for (final error in [
        PlatformException(
          code: 'Unexpected security result code',
          details: -25308,
        ),
        PlatformException(code: '-25308'),
        PlatformException(code: 'Unexpected', message: 'status: -25308'),
      ]) {
        final result = await secretsWith(
          FakeSecureStoragePlatform(scripted: [error]),
        ).fetch(id);

        expect(
          (result as Err<Secret, SecretFailure>).failure,
          isA<SecretStoreLockedFailure>(),
          reason: '$error',
        );
      }
    });

    test(
      'an unrelated platform error is a read failure, not a lock',
      () async {
        final result = await secretsWith(
          FakeSecureStoragePlatform(
            scripted: List.filled(5, PlatformException(code: 'StorageError')),
          ),
        ).fetch(id);

        final failure = (result as Err<Secret, SecretFailure>).failure;
        expect(failure, isA<SecretFetchFailure>());
        expect(failure, isNot(isA<SecretStoreLockedFailure>()));
        expect(failure, isNot(isA<SecretNotFoundFailure>()));
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );

    test('the lock is reported without burning the retry budget', () async {
      // Retrying cannot help: the lock clears on user unlock, not on
      // backoff. Five attempts would spend ~4.5s reaching the same
      // sealed keystore, which is the budget a genuine absence pays.
      final storage = FakeSecureStoragePlatform(locked: true);

      await secretsWith(storage).fetch(id);

      expect(storage.reads, 1);
    });
  });

  group('a corrupt entry is a read failure, not an absence', () {
    // The other way the seed could be reported gone. Not-found sends
    // callers towards recovery; a value that is present but unreadable
    // must send them towards support instead. And it must not burn the
    // retry budget: the next read returns the same bytes.
    for (final (label, value) in [
      ('not JSON', 'not json at all'),
      ('JSON of the wrong shape', '[1,2,3]'),
      (
        'a secret with non-string words',
        '{"mnemonicWords":[1,2,3],"passphrase":null,"runtimeType":"mnemonic"}',
      ),
    ]) {
      test(label, () async {
        final storage = FakeSecureStoragePlatform(
          entries: {'seed_73c5da0a': value},
        );

        final result = await secretsWith(storage).fetch(id);

        final failure = (result as Err<Secret, SecretFailure>).failure;
        expect(failure, isA<SecretFetchFailure>());
        expect(failure, isNot(isA<SecretNotFoundFailure>()));
        expect(storage.reads, 1);
        // The stored value is the secret; the failure must not quote it.
        expect(failure.toString(), isNot(contains('1,2,3')));
      });
    }
  });

  group('the retry loop', () {
    // The plugin's observed misbehaviour on Android is a read that comes
    // back null or "" for an entry that exists, or a read that throws
    // once. Each is retried; only a clean null at the end is an absence.
    test('an empty value is retried like an absent one', () async {
      final storage = FakeSecureStoragePlatform(
        entries: {'seed_73c5da0a': mnemonicEntry},
        scripted: ['', null],
      );

      final result = await secretsWith(storage).fetch(id);

      expect(result, isA<Ok<Secret, SecretFailure>>());
      expect(storage.reads, 3);
    });

    test('a read that throws is retried', () async {
      final storage = FakeSecureStoragePlatform(
        entries: {'seed_73c5da0a': mnemonicEntry},
        scripted: [Exception('flaky keystore')],
      );

      final result = await secretsWith(storage).fetch(id);

      expect(result, isA<Ok<Secret, SecretFailure>>());
      expect(storage.reads, 2);
    });

    test(
      'a keystore that keeps throwing is a read failure, not an absence',
      () async {
        // Five reads that threw are not five reads that found nothing.
        final storage = FakeSecureStoragePlatform(
          scripted: List.filled(5, Exception('keystore error')),
        );

        final result = await secretsWith(storage).fetch(id);

        final failure = (result as Err<Secret, SecretFailure>).failure;
        expect(failure, isA<SecretFetchFailure>());
        expect(failure, isNot(isA<SecretNotFoundFailure>()));
        expect(storage.reads, 5);
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );

    test(
      'an entry that reads as "" to the end is a read failure, not an absence',
      () async {
        // A missing key reads as null; "" means the key is there and its
        // value never came. Nothing this package writes is empty.
        final storage = FakeSecureStoragePlatform(scripted: List.filled(5, ''));

        final result = await secretsWith(storage).fetch(id);

        final failure = (result as Err<Secret, SecretFailure>).failure;
        expect(failure, isA<SecretFetchFailure>());
        expect(failure, isNot(isA<SecretNotFoundFailure>()));
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );

    test(
      'an early error followed by a clean null is still an absence',
      () async {
        final storage = FakeSecureStoragePlatform(
          scripted: [Exception('once')],
        );

        final result = await secretsWith(storage).fetch(id);

        expect(
          (result as Err<Secret, SecretFailure>).failure,
          isA<SecretNotFoundFailure>(),
        );
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );
  });

  group('stored words that fail bip39 are a corrupt entry', () {
    // Only user-typed words can be an "invalid mnemonic". Stored words
    // were validated on the way in, so a refusal on the way out is a
    // read failure — and must not be reported as the words being wrong,
    // nor as the seed being absent.
    final corruptWithPassphrase = jsonEncode({
      'mnemonicWords': List.filled(12, 'abandon'),
      'passphrase': 'x',
      'runtimeType': 'mnemonic',
    });

    test('fetch reports a read failure', () async {
      final result = await secretsWith(
        FakeSecureStoragePlatform(
          entries: {'seed_73c5da0a': corruptWithPassphrase},
        ),
      ).fetch(id);

      final failure = (result as Err<Secret, SecretFailure>).failure;
      expect(failure, isA<SecretFetchFailure>());
      expect(failure, isNot(isA<InvalidMnemonicFailure>()));
    });

    test('an operation on such a secret reports a read failure', () async {
      // Without a passphrase, describing derives nothing, so the handle
      // comes back; the first derivation is where the words are used.
      final corruptPlain = jsonEncode({
        'mnemonicWords': List.filled(12, 'abandon'),
        'passphrase': null,
        'runtimeType': 'mnemonic',
      });
      final secrets = secretsWith(
        FakeSecureStoragePlatform(entries: {'seed_73c5da0a': corruptPlain}),
      );
      final secret =
          (await secrets.fetch(id) as Ok<Secret, SecretFailure>).value;

      final result = await secret.derive.xpub(
        network: BitcoinNetwork.mainnet,
        scriptType: ScriptType.bip84,
      );

      final failure = (result as Err<String, SecretFailure>).failure;
      expect(failure, isA<SecretFetchFailure>());
      expect(failure, isNot(isA<InvalidMnemonicFailure>()));
    });

    test('list skips it and keeps the others', () async {
      final result = await secretsWith(
        FakeSecureStoragePlatform(
          entries: {
            'seed_73c5da0a': mnemonicEntry,
            'seed_deadbeef': corruptWithPassphrase,
          },
        ),
      ).list();

      final listed = (result as Ok<List<Secret>, SecretFailure>).value;
      expect(listed.map((s) => s.id), [id]);
    });
  });

  group('import refuses words that are not a mnemonic', () {
    test('a bad checksum', () async {
      final storage = FakeSecureStoragePlatform();

      final result = await secretsWith(
        storage,
      ).import(words: List.filled(12, 'abandon'));

      expect(
        (result as Err<Secret, SecretFailure>).failure,
        isA<InvalidMnemonicFailure>(),
      );
      expect(storage.entries, isEmpty);
    });

    test('an unknown word, without repeating it', () async {
      // bip39 names the word in its message. The failure must not.
      final result = await secretsWith(
        FakeSecureStoragePlatform(),
      ).import(words: [...words.sublist(0, 11), 'zzzzbogus']);

      final failure = (result as Err<Secret, SecretFailure>).failure;
      expect(failure, isA<InvalidMnemonicFailure>());
      expect(failure.toString(), isNot(contains('zzzzbogus')));
    });

    test('idOf agrees', () async {
      final result = await secretsWith(
        FakeSecureStoragePlatform(),
      ).idOf(words: List.filled(12, 'abandon'));

      expect(
        (result as Err<Fingerprint, SecretFailure>).failure,
        isA<InvalidMnemonicFailure>(),
      );
    });
  });

  group('verifyWords answers without exposing anything', () {
    late Secrets secrets;

    setUp(() {
      secrets = secretsWith(
        FakeSecureStoragePlatform(entries: {'seed_73c5da0a': mnemonicEntry}),
      );
    });

    Future<Secret> secretOf() async =>
        (await secrets.fetch(id) as Ok<Secret, SecretFailure>).value;

    test('accepts the right words', () async {
      final result = await (await secretOf()).verifyWords(words);
      expect((result as Ok<bool, SecretFailure>).value, isTrue);
    });

    test('rejects a wrong word', () async {
      final wrong = [...words]..[5] = 'zoo';
      final result = await (await secretOf()).verifyWords(wrong);
      expect((result as Ok<bool, SecretFailure>).value, isFalse);
    });

    test('rejects a wrong length', () async {
      final result = await (await secretOf()).verifyWords(
        words.take(11).toList(),
      );
      expect((result as Ok<bool, SecretFailure>).value, isFalse);
    });
  });

  group('operations a secret cannot serve are refused, not guessed', () {
    test('a seed-only secret cannot produce a Liquid descriptor', () async {
      final secrets = secretsWith(
        FakeSecureStoragePlatform(entries: {'seed_aabbccdd': bytesEntry}),
      );
      final secret =
          (await secrets.fetch(Fingerprint('aabbccdd'))
                  as Ok<Secret, SecretFailure>)
              .value;

      final result = await secret.derive.descriptors.liquid(
        network: LiquidNetwork.mainnet,
      );

      expect(err(result), isA<MnemonicRequiredFailure>());
    });

    test('Liquid regtest is refused rather than served as testnet', () async {
      // lwk's LiquidNetwork has mainnet and testnet only. Elements
      // regtest is a different chain, so substituting testnet would hand
      // back addresses that do not belong to the chain the caller named.
      final secrets = secretsWith(
        FakeSecureStoragePlatform(entries: {'seed_73c5da0a': mnemonicEntry}),
      );
      final secret =
          (await secrets.fetch(id) as Ok<Secret, SecretFailure>).value;

      final result = await secret.derive.descriptors.liquid(
        network: LiquidNetwork.regtest,
      );

      expect(err(result), isA<UnsupportedNetworkFailure>());
    });
  });

  group('signing refuses what it cannot sign', () {
    // Both refusals happen before any FFI call, which is what makes them
    // testable here: the real signer is used, not a stand-in.
    test('a seed-only secret cannot sign a PSBT', () async {
      final secrets = secretsWith(
        FakeSecureStoragePlatform(entries: {'seed_aabbccdd': bytesEntry}),
      );
      final secret =
          (await secrets.fetch(Fingerprint('aabbccdd'))
                  as Ok<Secret, SecretFailure>)
              .value;

      final result = await secret.sign.psbt(
        'cHNidP8=',
        network: BitcoinNetwork.mainnet,
        scriptType: ScriptType.bip84,
      );

      expect(
        (result as Err<String, SecretFailure>).failure,
        isA<MnemonicRequiredFailure>(),
      );
    });

    test('Liquid regtest is refused rather than signed on testnet', () async {
      // A signature produced against testnet's chain would be valid for
      // the wrong chain — worse than a refusal.
      final secrets = secretsWith(
        FakeSecureStoragePlatform(entries: {'seed_73c5da0a': mnemonicEntry}),
      );
      final secret =
          (await secrets.fetch(id) as Ok<Secret, SecretFailure>).value;

      final result = await secret.sign.pset(
        'cHNldP8=',
        network: LiquidNetwork.regtest,
      );

      expect(
        (result as Err<String, SecretFailure>).failure,
        isA<UnsupportedNetworkFailure>(),
      );
    });
  });

  group('the swap key is derived, not revealed', () {
    test('a seed-only secret has no swap key', () async {
      // Refused from the description, before anything is loaded: boltz
      // derives from BIP39 words.
      final secrets = secretsWith(
        FakeSecureStoragePlatform(entries: {'seed_aabbccdd': bytesEntry}),
      );
      final secret =
          (await secrets.fetch(Fingerprint('aabbccdd'))
                  as Ok<Secret, SecretFailure>)
              .value;

      final result = await secret.derive.swapKey(
        network: BitcoinNetwork.mainnet,
      );

      expect(
        (result as Err<SwapKey, SecretFailure>).failure,
        isA<MnemonicRequiredFailure>(),
      );
    });
  });

  group('list', () {
    test('describes what is stored and skips what it cannot read', () async {
      final secrets = secretsWith(
        FakeSecureStoragePlatform(
          entries: {
            'seed_73c5da0a': mnemonicEntry,
            'seed_aabbccdd': bytesEntry,
            'seed_broken': 'not json',
          },
        ),
      );

      final result =
          (await secrets.list() as Ok<List<Secret>, SecretFailure>).value;

      expect(result, hasLength(2));
      expect(result.map((s) => s.info.kind), containsAll(SecretKind.values));
    });
  });

  group('an invalid word count is classified at its origin', () {
    // Before: a count BIP39 does not define reached the boundary as the storage model's `FormatException`, and read as "the keystore refused" whether the words came from the user or from a vault. Two origins, two remedies, one wrong answer. Each origin now decides for itself.
    test('from an import, it is an invalid mnemonic', () async {
      FakeSecureStoragePlatform().install();
      final result = await Secrets(
        scratchDirectory: () async => '/tmp',
      ).import(words: List.filled(11, 'abandon'));
      expect(
        (result as Err<Secret, SecretFailure>).failure,
        isA<InvalidMnemonicFailure>(),
      );
    });

    test(
      'from a vault, it is an invalid vault — and nothing is stored',
      () async {
        final storage = FakeSecureStoragePlatform()..install();
        final file = RecoverBull.createBackup(
          secret: utf8.encode(
            jsonEncode({'mnemonic': List.filled(11, 'abandon')}),
          ),
          backupKey: List.filled(32, 1),
        ).toJson();
        final result = await Secrets(
          scratchDirectory: () async => '/tmp',
        ).restoreVault(file: file, key: '01' * 32);
        expect(err(result), isA<InvalidVaultFailure>());
        expect(storage.entries, isEmpty);
      },
    );
  });
}
