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
/// word list and derived fingerprint across an `await`, so a caller that
/// touched its own list afterwards had the *other* words written under
/// the *first* fingerprint. Reading then trusted the storage key for
/// fingerprint without checking the material under it — so the substituted
/// entry came back announcing the fingerprint it did not have, and every
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
        reason:
            'the entry must hold the words its fingerprint was derived from',
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
          isA<FingerprintMismatchFailure>(),
          reason:
              'its own failure, never a not-found: callers read that as "the seed is gone"',
        );
      },
    );
  });
}
