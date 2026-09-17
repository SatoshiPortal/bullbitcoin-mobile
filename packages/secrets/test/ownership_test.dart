import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/src/data/models/secret_model.dart';
import 'package:secrets/src/data/secret_repository.dart';

import 'fake_secure_storage_platform.dart';
import 'result_helpers.dart';

/// The package owns what it is given, and what it reads matches the key
/// it read from.
///
/// These two properties are one subject, because they used to fail
/// together and in a way that compounded. The package kept the caller's
/// word list and derived identity across an `await`, so a caller that
/// touched its own list afterwards had the *other* words written under
/// the *first* identity. Reading then trusted the storage key for
/// identity without checking the material under it — so the substituted
/// entry came back announcing the identity it did not have, and every
/// derivation served the wrong wallet's keys under the right wallet's
/// name. `import()` returned `Ok`. Nothing warned.
///
/// Each test below was written first as a demonstration of that defect
/// and then inverted. No application path was ever found that mutated a
/// list after handing it over — the window was reachable through the
/// public API, never through a screen — so these are the closing of a
/// boundary rather than the fix of an observed incident.
void main() {
  // The published BIP39 test vector, and a second, different, *valid*
  // one. Two valid mnemonics is the whole point: a mutation to invalid
  // words is caught by bip39 downstream, a mutation to valid words was
  // not caught by anything.
  const a = [
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
  const b = [
    'legal',
    'winner',
    'thank',
    'year',
    'wave',
    'sausage',
    'worth',
    'useful',
    'legal',
    'winner',
    'thank',
    'yellow',
  ];
  const aFingerprint = '73c5da0a';

  group('the package owns what it is handed', () {
    test('a list mutated after store() does not reach the keystore', () async {
      final storage = FakeSecureStoragePlatform()..install();
      final input = [...a];

      final pending = SecretRepository().store(words: input);
      input.setAll(0, b); // the caller reuses its buffer
      final info = ok(await pending);

      final written =
          jsonDecode(storage.entries['seed_${info.id.hex}']!)
              as Map<String, dynamic>;

      expect(info.id, Fingerprint(aFingerprint));
      expect(
        written['mnemonicWords'],
        a,
        reason: 'the entry must hold the words its identity was derived from',
      );
    });

    test('the same, through the public API', () async {
      FakeSecureStoragePlatform().install();
      final secrets = Secrets(scratchDirectory: () async => '/tmp');
      final input = [...a];

      final pending = secrets.import(words: input);
      input.setAll(0, b);
      final imported = pending;

      final secret = switch (await imported) {
        Ok(:final value) => value,
        Err(:final failure) => fail('import failed: ${failure.runtimeType}'),
      };
      final mine = switch (await secret.derive.xpub(
        network: BitcoinNetwork.mainnet,
        scriptType: ScriptType.bip84,
      )) {
        Ok(:final value) => value,
        Err(:final failure) => fail('xpub failed: ${failure.runtimeType}'),
      };

      // What B's xpub would be, imported on its own.
      FakeSecureStoragePlatform().install();
      final other = Secrets(scratchDirectory: () async => '/tmp');
      final secretB = switch (await other.import(words: [...b])) {
        Ok(:final value) => value,
        Err(:final failure) => fail('import failed: ${failure.runtimeType}'),
      };
      final theirs = switch (await secretB.derive.xpub(
        network: BitcoinNetwork.mainnet,
        scriptType: ScriptType.bip84,
      )) {
        Ok(:final value) => value,
        Err(:final failure) => fail('xpub failed: ${failure.runtimeType}'),
      };

      expect(secret.id, Fingerprint(aFingerprint));
      expect(
        mine,
        isNot(theirs),
        reason: 'the handle must not serve the other wallet\'s public keys',
      );
    });

    test('a model does not follow the list it was built from', () {
      final input = [...a];
      final model = MnemonicSecretModel(mnemonicWords: input);
      input.setAll(0, b);
      expect(model.mnemonicWords, a);
    });

    test('a DatabaseKey does not follow its buffer, nor its getter', () {
      final bytes = Uint8List(DatabaseKey.lengthInBytes)..fillRange(0, 32, 1);
      final key = DatabaseKey(bytes);
      final before = key.hex;

      bytes[0] = 0xff;
      expect(key.hex, before, reason: 'the key copied its input');
      expect(
        () => key.bytes[0] = 0xff,
        throwsUnsupportedError,
        reason: 'the getter hands out a read-only view',
      );
    });

    test('a byte outside 0..255 is refused however the model is built', () {
      // `fromJson` always checked this; the factory did not, so a value
      // built in memory could be written to the keystore as an
      // out-of-range JSON number.
      expect(
        () => BytesSecretModel(bytes: List<int>.filled(32, 999)),
        throwsFormatException,
      );
    });
  });

  group('material must match the key it is filed under', () {
    test(
      'an entry under a foreign key is a read failure, not a wallet',
      () async {
        FakeSecureStoragePlatform(
          entries: {
            'seed_00000000': jsonEncode({
              'mnemonicWords': a,
              'passphrase': null,
              'runtimeType': 'mnemonic',
            }),
          },
        ).install();

        final secrets = Secrets(scratchDirectory: () async => '/tmp');
        final secret = switch (await secrets.fetch(Fingerprint('00000000'))) {
          Ok(:final value) => value,
          Err(:final failure) => fail('fetch failed: ${failure.runtimeType}'),
        };

        // Describing is cheap and still trusts the key — the check costs a
        // seed, which describing deliberately does not derive. The refusal
        // lands on the first operation that materialises.
        final result = await secret.derive.xpub(
          network: BitcoinNetwork.mainnet,
          scriptType: ScriptType.bip84,
        );

        expect(result, isA<Err<String, SecretFailure>>());
        expect(
          (result as Err<String, SecretFailure>).failure,
          isA<SecretIdentityMismatchFailure>(),
          reason:
              'its own failure, never a not-found: callers read that as "the seed is gone"',
        );
      },
    );
  });

  group('a mismatched entry is repaired where it lies', () {
    // Decision of 2026-09-15: the entry is not deleted and the words are not
    // handed out — it is re-filed under the identity it really has, inside the
    // package, and the app creates the wallet it actually owns.
    String entry(List<String> words) => jsonEncode({
      'mnemonicWords': words,
      'passphrase': null,
      'runtimeType': 'mnemonic',
    });

    test(
      'the entry moves to its true identity, and the old key goes',
      () async {
        final storage = FakeSecureStoragePlatform(
          entries: {'seed_00000000': entry(a)},
        )..install();
        final secrets = Secrets(scratchDirectory: () async => '/tmp');

        final repaired = switch (await secrets.repairIdentity(
          Fingerprint('00000000'),
        )) {
          Ok(:final value) => value,
          Err(:final failure) => fail('repair: ${failure.runtimeType}'),
        };

        expect(repaired.id.hex, aFingerprint);
        expect(storage.entries.keys, ['seed_$aFingerprint']);
        // And it works now, which is the point.
        final result = await repaired.derive.xpub(
          network: BitcoinNetwork.mainnet,
          scriptType: ScriptType.bip84,
        );
        expect(result, isA<Ok<String, SecretFailure>>());
      },
    );

    test('an entry already under its own identity is untouched', () async {
      final storage = FakeSecureStoragePlatform(
        entries: {'seed_$aFingerprint': entry(a)},
      )..install();
      final secrets = Secrets(scratchDirectory: () async => '/tmp');

      final repaired = switch (await secrets.repairIdentity(
        Fingerprint(aFingerprint),
      )) {
        Ok(:final value) => value,
        Err(:final failure) => fail('repair: ${failure.runtimeType}'),
      };

      expect(repaired.id.hex, aFingerprint);
      expect(storage.entries.keys, ['seed_$aFingerprint']);
    });

    test('a true identity already taken is refused, losing nothing', () async {
      // Some *other* secret sits where this one belongs. Moving would destroy
      // it, so the repair refuses and both entries stay exactly as they were.
      final other = entry(b);
      final storage = FakeSecureStoragePlatform(
        entries: {'seed_00000000': entry(a), 'seed_$aFingerprint': other},
      )..install();
      final secrets = Secrets(scratchDirectory: () async => '/tmp');

      final result = await secrets.repairIdentity(Fingerprint('00000000'));

      expect(result, isA<Err<Secret, SecretFailure>>());
      expect(storage.entries['seed_00000000'], entry(a));
      expect(storage.entries['seed_$aFingerprint'], other);
    });

    test('a true identity that reads back empty is refused too', () async {
      // Same refusal when the destination holds "" rather than another
      // secret: the plugin has returned "" for entries that exist, and the
      // read path calls that present-and-unreadable. Moving over it would
      // destroy what may still be recoverable, so both entries stay put.
      final storage = FakeSecureStoragePlatform(
        entries: {'seed_00000000': entry(a), 'seed_$aFingerprint': ''},
      )..install();
      final secrets = Secrets(scratchDirectory: () async => '/tmp');

      final result = await secrets.repairIdentity(Fingerprint('00000000'));

      expect(result, isA<Err<Secret, SecretFailure>>());
      expect(storage.entries['seed_00000000'], entry(a));
      expect(storage.entries['seed_$aFingerprint'], isEmpty);
    });
  });
}
