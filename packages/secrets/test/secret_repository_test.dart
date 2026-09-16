import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/data/database_key_repository.dart';
import 'package:secrets/src/data/secret_repository.dart';
import 'package:secrets/src/domain/database_key.dart';
import 'package:secrets/src/domain/failures.dart';
import 'package:secrets/src/domain/secret_material.dart';

import 'fake_secure_storage_platform.dart';
import 'result_helpers.dart';

void main() {
  // The published BIP39 test mnemonic and its well-known master
  // fingerprint. Pinning it means a change in how we derive identity
  // fails here rather than silently filing wallets under new keys.
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
  const trezorFingerprint = 'b4e3f5ed';

  // 12x "abandon" fails the BIP39 checksum, so deriving a seed from it
  // throws. Anything that still succeeds on this entry provably derived
  // nothing — which is how the listing path is checked below, without
  // timing anything.
  const underivable = [
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
  ];

  String entry(List<String> w, {String? passphrase}) => jsonEncode({
    'mnemonicWords': w,
    'passphrase': passphrase,
    'runtimeType': 'mnemonic',
  });

  SecretRepository repoWith(FakeSecureStoragePlatform storage) {
    storage.install();
    return SecretRepository();
  }

  DatabaseKeyRepository keysWith(FakeSecureStoragePlatform storage) {
    storage.install();
    return DatabaseKeyRepository();
  }

  group('identity', () {
    test('matches the published BIP39 vector', () async {
      expect(
        ok(await repoWith(FakeSecureStoragePlatform()).idOf(words: words)).hex,
        plainFingerprint,
      );
    });

    test('a passphrase produces a different identity', () async {
      expect(
        ok(
          await repoWith(
            FakeSecureStoragePlatform(),
          ).idOf(words: words, passphrase: 'TREZOR'),
        ).hex,
        trezorFingerprint,
      );
    });

    test('store files the entry under the derived fingerprint', () async {
      final storage = FakeSecureStoragePlatform();

      final info = ok(await repoWith(storage).store(words: words));

      expect(storage.entries.keys, ['seed_$plainFingerprint']);
      expect(info.id, Fingerprint(plainFingerprint));
      expect(info.wordCount, 12);
    });
  });

  group('fetchAll — listing never materialises key material', () {
    test('describes every stored secret', () async {
      final storage = FakeSecureStoragePlatform(
        entries: {
          'seed_$plainFingerprint': entry(words),
          'seed_$trezorFingerprint': entry(words, passphrase: 'TREZOR'),
        },
      );

      final all = ok(await repoWith(storage).describeAll());

      expect(all.map((i) => i.id.hex), <String>{
        plainFingerprint,
        trezorFingerprint,
      });
    });

    test('lists entries whose seed could never be derived', () async {
      // The property that matters: listing a user's secrets must not put
      // every seed they own into memory at once. An entry that cannot be
      // derived at all still lists, which no materialising code could do.
      final storage = FakeSecureStoragePlatform(
        entries: {'seed_deadbeef': entry(underivable)},
      );
      final repo = repoWith(storage);

      final all = ok(await repo.describeAll());
      expect(all.single.wordCount, 12);
      expect(all.single.id, Fingerprint('deadbeef'));

      // ...while asking for the material itself does derive, and fails — as a read failure, never an absence.
      expect(
        err(await repo.use(all.single, (m) => m)),
        isA<SecretFetchFailure>(),
      );
    });

    test('without a passphrase the plain identity is the identity', () async {
      final storage = FakeSecureStoragePlatform(
        entries: {'seed_$plainFingerprint': entry(words)},
      );

      final info = (ok(await repoWith(storage).describeAll())).single;

      // Free: no second PBKDF2 pass is owed when nothing splits them.
      expect(info.mnemonicFingerprint, info.id);
      expect(info.hasPassphrase, isFalse);
    });

    test(
      'with a passphrase the plain identity is derived and differs',
      () async {
        final storage = FakeSecureStoragePlatform(
          entries: {
            'seed_$trezorFingerprint': entry(words, passphrase: 'TREZOR'),
          },
        );

        final info = (ok(await repoWith(storage).describeAll())).single;

        expect(info.id, Fingerprint(trezorFingerprint));
        expect(info.hasPassphrase, isTrue);
        // Same words, no passphrase — this is what lets callers group
        // secrets by mnemonic without ever reading the words.
        expect(info.mnemonicFingerprint, Fingerprint(plainFingerprint));
      },
    );

    test('a corrupt entry does not hide the others', () async {
      // One unreadable value must never cost the user sight of the
      // wallets that are still intact.
      final storage = FakeSecureStoragePlatform(
        entries: {
          'seed_$plainFingerprint': entry(words),
          'seed_corrupted': 'not json at all',
        },
      );

      final all = ok(await repoWith(storage).describeAll());

      expect(all.single.id, Fingerprint(plainFingerprint));
    });

    test('ignores entries outside the namespace', () async {
      final storage = FakeSecureStoragePlatform(
        entries: {'seed_$plainFingerprint': entry(words), 'pin_code': 'nope'},
      );

      expect(ok(await repoWith(storage).describeAll()), hasLength(1));
    });
  });

  group('use — materialises one secret for the length of a closure', () {
    test('hands the closure words and a derived seed', () async {
      final storage = FakeSecureStoragePlatform(
        entries: {'seed_$plainFingerprint': entry(words)},
      );
      final repo = repoWith(storage);
      final info = ok(await repo.describe(Fingerprint(plainFingerprint)));

      final secret = ok(await repo.use(info, (m) => m));

      expect(secret, isA<MnemonicMaterial>());
      expect((secret as MnemonicMaterial).words, words);
      expect(secret.passphrase, isEmpty);
      expect(secret.seedBytes, hasLength(64));
      expect(secret.id, Fingerprint(plainFingerprint));
    });

    test(
      'a closure that throws is a derivation failure, not a read failure',
      () async {
        // A PSBT that does not parse must never read as "your seed is unreadable".
        final repo = repoWith(
          FakeSecureStoragePlatform(
            entries: {'seed_$plainFingerprint': entry(words)},
          ),
        );
        final info = ok(await repo.describe(Fingerprint(plainFingerprint)));

        final failure = err(
          await repo.use(info, (_) => throw const FormatException('bad psbt')),
        );

        expect(failure, isA<SecretDerivationFailure>());
        expect(failure.logMessage, isNot(contains('bad psbt')));
      },
    );

    test('a seed-only secret is refused before any derivation', () async {
      final repo = repoWith(
        FakeSecureStoragePlatform(
          entries: {
            'seed_deadbeef': jsonEncode({
              'bytes': List.filled(64, 1),
              'runtimeType': 'bytes',
            }),
          },
        ),
      );
      final info = ok(await repo.describe(Fingerprint('deadbeef')));

      expect(
        err(await repo.useMnemonic(info, (m) => m.words)),
        isA<MnemonicRequiredFailure>(),
      );
    });

    test(
      'an entry filed under a foreign key is refused, not trusted',
      () async {
        // The entry holds the standard words but is filed under another
        // key. Trusting the key — which this package did until the
        // identity check landed — serves these words' keys under the other
        // wallet's identity: the app joins on this fingerprint, so it
        // would display one wallet and derive another, with no error.
        //
        // The inverse of the mutation `store` used to allow: whichever way
        // the two came apart, they must not be used together.
        final storage = FakeSecureStoragePlatform(
          entries: {'seed_00000000': entry(words)},
        );

        final repo = repoWith(storage);
        final info = ok(await repo.describe(Fingerprint('00000000')));

        expect(
          err(await repo.use(info, (m) => m)),
          isA<SecretIdentityMismatchFailure>(),
          reason: 'a mismatch is its own failure, never an absence',
        );
      },
    );

    test(
      'an absent secret is not-found, after the full retry budget',
      () async {
        // ~4.5s of backoff before concluding absence, deliberately: the
        // signal that says "absent" is the one that cannot be trusted.
        final storage = FakeSecureStoragePlatform();

        expect(
          err(await repoWith(storage).describe(Fingerprint('00000000'))),
          isA<SecretNotFoundFailure>(),
        );
        expect(storage.reads, 5);
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );
  });

  group('a different secret is never written over another', () {
    // A BIP32 fingerprint is 32 bits: two secrets can claim the same key. Writing blind would destroy the first silently. No collision is generated here — the store is seeded with the shape one would produce.
    test('a foreign entry under the same key is refused', () async {
      final storage = FakeSecureStoragePlatform(
        entries: {'seed_$plainFingerprint': entry(underivable)},
      );

      expect(
        err(await repoWith(storage).store(words: words)),
        isA<SecretStoreFailure>(),
      );
      expect(
        storage.entries['seed_$plainFingerprint'],
        entry(underivable),
        reason: 'the first secret stays exactly as it was',
      );
    });

    test('storing the same secret again is allowed', () async {
      final storage = FakeSecureStoragePlatform();
      final repo = repoWith(storage);

      await repo.store(words: words);
      await repo.store(words: words);

      expect(storage.entries['seed_$plainFingerprint'], entry(words));
    });
  });

  group('identity is validated, not merely typed', () {
    test('a malformed fingerprint is refused at construction', () {
      // What the previous extension type could not do: any string was a
      // valid id, so a wallet id or an xpub passed silently.
      expect(() => Fingerprint('not-hex!'), throwsArgumentError);
      expect(() => Fingerprint('73C5DA0A'), throwsArgumentError);
      expect(() => Fingerprint('73c5da0'), throwsArgumentError);
      expect(Fingerprint.tryParse('nope'), isNull);
    });

    test('an entry filed under a non-fingerprint key is skipped', () async {
      // `seed_corrupted` cannot name a secret, so listing steps over it
      // rather than surfacing an entry nothing can act on.
      final storage = FakeSecureStoragePlatform(
        entries: {
          'seed_$plainFingerprint': entry(words),
          'seed_corrupted': entry(words),
        },
      );

      final all = ok(await repoWith(storage).describeAll());

      expect(all.single.id.hex, plainFingerprint);
    });
  });

  group('database keys', () {
    test('generates 32 random bytes on first ask and keeps them', () async {
      final storage = FakeSecureStoragePlatform();
      final keys = keysWith(storage);

      final first = ok(await keys.forModule(package: 'swaps', name: 'main'));
      final again = ok(await keys.forModule(package: 'swaps', name: 'main'));

      expect(first.bytes, hasLength(32));
      expect(again.hex, first.hex);
      expect(storage.entries.keys, ['com.bullbitcoin.secrets/dek/swaps/main']);
    });

    test('two first asks for one key agree', () async {
      // Unserialised, both would read a miss, generate, and write; the
      // second write would win and the first caller would hold a key
      // that no longer exists — a database nobody can ever open again.
      final storage = FakeSecureStoragePlatform();
      final keys = keysWith(storage);

      final (a, b) = await (
        keys.forModule(package: 'swaps', name: 'main'),
        keys.forModule(package: 'swaps', name: 'main'),
      ).wait;

      expect(ok(a).hex, ok(b).hex);
      expect(storage.entries, hasLength(1));
    });

    test('a key of any length but 32 bytes is refused in every build', () {
      // An assert would let a truncated key through in release, and
      // SQLCipher would accept it.
      expect(() => DatabaseKey(Uint8List(16)), throwsArgumentError);
      expect(() => DatabaseKey.fromHex('ab' * 31), throwsArgumentError);
    });

    test('every key is distinct', () async {
      final keys = keysWith(FakeSecureStoragePlatform());

      final swaps = ok(await keys.forModule(package: 'swaps', name: 'main'));
      final other = ok(await keys.forModule(package: 'swaps', name: 'archive'));
      final payjoin = ok(
        await keys.forModule(package: 'bull_payjoin', name: 'main'),
      );

      expect({swaps.hex, other.hex, payjoin.hex}, hasLength(3));
    });

    test('the stored envelope is versioned and self-describing', () async {
      final storage = FakeSecureStoragePlatform();
      await keysWith(storage).forModule(package: 'swaps', name: 'main');

      final envelope =
          jsonDecode(storage.entries['com.bullbitcoin.secrets/dek/swaps/main']!)
              as Map<String, dynamic>;

      expect(envelope['v'], 1);
      expect(envelope['kind'], 'dek');
      expect(envelope['name'], 'com.bullbitcoin.secrets/dek/swaps/main');
      expect(envelope['bytes'], hasLength(64));
      expect(DateTime.parse(envelope['createdAt'] as String), isNotNull);
    });

    test('a key filed under the wrong name is refused, not used', () async {
      // On desktop the session keystore has no per-application access
      // control, so an entry can be moved by another process. The name
      // inside the envelope is what catches that.
      final storage = FakeSecureStoragePlatform();
      final keys = keysWith(storage);
      await keys.forModule(package: 'swaps', name: 'main');

      final moved = storage.entries.remove(
        'com.bullbitcoin.secrets/dek/swaps/main',
      )!;
      storage.entries['com.bullbitcoin.secrets/dek/exchange/main'] = moved;

      expect(
        err(await keys.forModule(package: 'exchange', name: 'main')),
        isA<DatabaseKeyCorruptFailure>(),
      );
      // Refused, and kept: replacing it would destroy the only key that
      // opens the database it was moved away from.
      expect(
        storage.entries['com.bullbitcoin.secrets/dek/exchange/main'],
        moved,
      );
    });

    test('two instances racing for one key agree', () async {
      // The atomicity guarantee used to be per datasource instance, and
      // `Secrets` builds two — one under `SecretRepository`, one under
      // `DatabaseKeyRepository`. Two first asks then each read a miss, each
      // generated, and the second write won: the first caller held a key
      // that opened nothing. The lock is `static` so that the property
      // belongs to the process, which is what owns the keystore.
      FakeSecureStoragePlatform().install();

      final keys = await Future.wait([
        DatabaseKeyRepository().forModule(package: 'swaps', name: 'main'),
        DatabaseKeyRepository().forModule(package: 'swaps', name: 'main'),
      ]);

      expect(ok(keys.first).hex, ok(keys.last).hex);
    });

    test('an empty stored key is refused, not replaced', () async {
      // The seed namespace already called an empty value corruption;
      // this one treated it as absence and generated over it. That is
      // the single irreversible act available here: the database the old
      // key opened can never be read again.
      final storage = FakeSecureStoragePlatform();
      final keys = keysWith(storage);
      await keys.forModule(package: 'swaps', name: 'main');

      const key = 'com.bullbitcoin.secrets/dek/swaps/main';
      storage.entries[key] = '';

      expect(
        err(await keys.forModule(package: 'swaps', name: 'main')),
        isA<DatabaseKeyCorruptFailure>(),
      );
      expect(
        storage.entries[key],
        isEmpty,
        reason: 'nothing was written over it',
      );
    });

    test('a key that is not our JSON is refused, not replaced', () async {
      final storage = FakeSecureStoragePlatform();
      final keys = keysWith(storage);
      await keys.forModule(package: 'swaps', name: 'main');

      const key = 'com.bullbitcoin.secrets/dek/swaps/main';
      storage.entries[key] = 'not json at all';

      expect(
        err(await keys.forModule(package: 'swaps', name: 'main')),
        isA<DatabaseKeyCorruptFailure>(),
      );
      expect(storage.entries[key], 'not json at all');
    });

    test(
      'a truncated key is refused where it is read, not two layers on',
      () async {
        // Left to `DatabaseKey`, this surfaced as an `ArgumentError` far
        // from the read that produced it.
        final storage = FakeSecureStoragePlatform();
        final keys = keysWith(storage);
        await keys.forModule(package: 'swaps', name: 'main');

        const key = 'com.bullbitcoin.secrets/dek/swaps/main';
        final envelope =
            jsonDecode(storage.entries[key]!) as Map<String, dynamic>;
        envelope['bytes'] = (envelope['bytes'] as String).substring(0, 62);
        storage.entries[key] = jsonEncode(envelope);

        expect(
          err(await keys.forModule(package: 'swaps', name: 'main')),
          isA<DatabaseKeyCorruptFailure>(),
        );
      },
    );

    test('reset removes the key, and the next ask starts over', () async {
      // The one destructive act, and it is explicit: nothing on the recovery path calls it.
      final storage = FakeSecureStoragePlatform();
      final keys = keysWith(storage);
      final before = ok(await keys.forModule(package: 'swaps', name: 'main'));

      ok(await keys.reset(package: 'swaps', name: 'main'));
      expect(storage.entries, isEmpty);

      final after = ok(await keys.forModule(package: 'swaps', name: 'main'));
      expect(after.hex, isNot(before.hex));
    });

    test('the SQLCipher literal asks for a raw key', () async {
      // Without the x'…' form SQLCipher treats the hex as a passphrase
      // and runs 256 000 PBKDF2 rounds over an already-random key.
      final key = ok(
        await keysWith(
          FakeSecureStoragePlatform(),
        ).forModule(package: 'swaps', name: 'main'),
      );

      expect(key.pragma, "x'${key.hex}'");
      expect(key.toString(), isNot(contains(key.hex)));
    });
  });
}
