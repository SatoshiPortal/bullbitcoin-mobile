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
      'an early "" followed by clean nulls is a read failure, not an absence',
      () async {
        // "" proved the key exists; later nulls do not un-prove it. Before,
        // only the last read counted, and this came back as not-found — the
        // one failure callers take as "the seed is gone".
        final storage = FakeSecureStoragePlatform(
          scripted: ['', null, null, null, null],
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
      'the same holds for a module key: corrupt, not missing',
      () async {
        final storage = FakeSecureStoragePlatform(
          scripted: ['', null, null, null, null],
        );

        final result = await secretsWith(
          storage,
        ).existingDatabaseKey(package: 'swaps', name: 'main');

        final failure = (result as Err<DatabaseKey, SecretFailure>).failure;
        expect(failure, isA<DatabaseKeyCorruptFailure>());
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

    test('fetching such a secret is itself the read failure', () async {
      // D3 (Codex, 2026-09-16): the checksum is checked when describing,
      // whatever the passphrase field says — so the handle never comes back
      // for words that are not a mnemonic, and the failure is a read
      // failure, never "invalid mnemonic" (that one is for user input) and
      // never an absence.
      final corruptPlain = jsonEncode({
        'mnemonicWords': List.filled(12, 'abandon'),
        'passphrase': null,
        'runtimeType': 'mnemonic',
      });
      final secrets = secretsWith(
        FakeSecureStoragePlatform(entries: {'seed_73c5da0a': corruptPlain}),
      );

      final failure = err(await secrets.fetch(id));

      expect(failure, isA<SecretFetchFailure>());
      expect(failure, isNot(isA<InvalidMnemonicFailure>()));
      expect(failure, isNot(isA<SecretNotFoundFailure>()));
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

      final listing = ok(result);
      expect(listing.secrets.map((s) => s.id), [id]);
      expect(listing.unreadable, 1, reason: 'skipped, and counted');
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

    group('elements that are not single words', () {
      // bip39 joins the list and splits it straight back, so a list of
      // twelve elements whose join is a valid fifteen-word mnemonic passes
      // its count, wordlist and checksum. The join here is the published
      // zero-entropy fifteen-word vector, byte for byte.
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

      test(
        'import refuses them as an invalid mnemonic, not a store failure',
        () async {
          // The first version of this rule threw a FormatException, which the
          // boundary classifies as a store failure with a severe log — for
          // user input. A trailing-space element had been an
          // InvalidMnemonicFailure before that rule existed, so this pins the
          // classification the package promises for words that are not a
          // mnemonic.
          final storage = FakeSecureStoragePlatform();

          final failure = err(
            await secretsWith(storage).import(words: regrouped),
          );

          expect(failure, isA<InvalidMnemonicFailure>());
          expect(failure, isNot(isA<SecretStoreFailure>()));
          expect(storage.entries, isEmpty);
        },
      );

      test('a trailing space is still an invalid mnemonic', () async {
        final failure = err(
          await secretsWith(
            FakeSecureStoragePlatform(),
          ).import(words: ['${words.first} ', ...words.sublist(1)]),
        );

        expect(failure, isA<InvalidMnemonicFailure>());
      });

      test('idOf refuses the same list import refuses', () async {
        // idOf derives through seed(), not check(); the rule has to live in
        // both or the two disagree about one input.
        final failure = err(
          await secretsWith(FakeSecureStoragePlatform()).idOf(words: regrouped),
        );

        expect(failure, isA<InvalidMnemonicFailure>());
      });

      test('an entry stored that way is corrupt, and is kept', () async {
        // Planted under the fingerprint the canonical words derive to, so a
        // later canonical import collides with it. No shipped writer could
        // have produced this entry; a direct caller of the package API
        // through the old gap could. It must read as a corrupt entry — the
        // path every unparsable value takes — and it must never be written
        // over, because "does not parse" is not "is the same secret".
        final clean = secretsWith(FakeSecureStoragePlatform());
        final id = ok(await clean.idOf(words: fifteen));
        final planted = jsonEncode({
          'mnemonicWords': regrouped,
          'passphrase': null,
          'runtimeType': 'mnemonic',
        });
        final storage = FakeSecureStoragePlatform(
          entries: {'seed_${id.hex}': planted},
        );
        final secrets = secretsWith(storage);

        final listing = ok(await secrets.list());
        expect(listing.secrets, isEmpty);
        expect(listing.unreadable, 1);

        final fetched = err(await secrets.fetch(id));
        expect(fetched, isA<SecretFetchFailure>());
        expect(fetched, isNot(isA<SecretNotFoundFailure>()));
        expect(fetched, isNot(isA<InvalidMnemonicFailure>()));

        final reimport = err(await secrets.import(words: fifteen));
        expect(reimport, isA<SecretStoreFailure>());
        expect(
          storage.entries['seed_${id.hex}'],
          planted,
          reason: 'an unparsable entry is kept, never replaced',
        );
      });
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

    test('a PSET asking for SIGHASH_NONE is refused before lwk', () async {
      // lwk_signer signs with the sighash the PSET asks for; the package
      // refuses first. The PSET below is one input with sighash 0x02 —
      // reaching lwk here would crash, lwk has no host library.
      final secrets = secretsWith(
        FakeSecureStoragePlatform(entries: {'seed_73c5da0a': mnemonicEntry}),
      );
      final secret =
          (await secrets.fetch(id) as Ok<Secret, SecretFailure>).value;

      final result = await secret.sign.pset(
        'cHNldP8BAgQCAAAAAQQBAQEFAQAB+wQCAAAAAAEDBAIAAAAA',
        network: LiquidNetwork.mainnet,
      );

      expect(
        (result as Err<String, SecretFailure>).failure,
        isA<SecretDerivationFailure>(),
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

      final result = ok(await secrets.list()).secrets;

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
