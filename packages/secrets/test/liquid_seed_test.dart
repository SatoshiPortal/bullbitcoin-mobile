import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:convert/convert.dart' as convert;
import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/src/crypto/derivers/liquid_deriver.dart'
    show liquidSeed;
import 'package:secrets/src/data/secret_repository.dart' show SecretRepository;
import 'package:secrets/src/domain/domain.dart' show Mnemonic;

import 'fake_secure_storage_platform.dart';
import 'result_helpers.dart';

/// The seed lwk receives for Liquid: the secret's full BIP39 seed, the words in their own language with the passphrase.
///
/// lwk itself needs the FFI; integration_test/secrets_derivation_vectors_test.dart checks what it builds from this seed. Here the seed alone is pinned against the published BIP39 vectors (entropy 00…00) and a stdlib PBKDF2 for French.
void main() {
  const englishSeed =
      '5eb00bbddcf069084889a8ab9155568165f5c453ccb85e70811aaed6f6da5fc1'
      '9a5ac40b389cd370d086206dec8aa6c43daea6690f20ad3d8d48b2d2ce9e38e4';
  const frenchSeed =
      '01051dcfa9e1695ca99d1bd2a3304d073c00d275ad5a389d0579a13f4f8e90e5'
      '12f0c5839764179926bf51961d84c3bf3e20404298065998c60e43e4ec7985b6';

  late SecretRepository repo;

  setUp(() {
    FakeSecureStoragePlatform().install();
    repo = SecretRepository();
  });

  Future<Mnemonic> stored(bip39.Language language, {String? passphrase}) async {
    final words = bip39.Mnemonic(List.filled(16, 0), language).words;
    final info = ok(
      await repo.store(
        words: words,
        language: language,
        passphrase: passphrase,
      ),
    );
    return ok(await repo.use(info, (m) => m)) as Mnemonic;
  }

  test('an English mnemonic gives its BIP39 seed', () async {
    expect(
      convert.hex.encode(liquidSeed(await stored(bip39.Language.english))),
      englishSeed,
    );
  });

  test('the same entropy in French gives the French seed', () async {
    expect(
      convert.hex.encode(liquidSeed(await stored(bip39.Language.french))),
      frenchSeed,
    );
  });

  test(
    'without a passphrase it is the seed lwk derived from the words',
    () async {
      // lwk's word-based signer used to_seed(""): every existing Liquid
      // wallet is a passphrase-less default, so its keys do not move.
      expect(
        convert.hex.encode(liquidSeed(await stored(bip39.Language.english))),
        englishSeed,
      );
    },
  );

  test('a passphrase takes part', () async {
    final protected = await stored(
      bip39.Language.english,
      passphrase: 'TREZOR',
    );
    // The published BIP39 vector for entropy 00…00 with "TREZOR".
    expect(
      convert.hex.encode(liquidSeed(protected)),
      'c55257c360c07c72029aebc1b53c05ed0362ada38ead3e3e9efa3708e5349553'
      '1f09a6987599d18264c1e1c92f2cf141630c7a3c4ab7c81b2f001698e7463b04',
    );
  });

  test('wiping the returned seed leaves the secret intact', () async {
    final secret = await stored(bip39.Language.english);
    liquidSeed(secret).fillRange(0, 64, 0);
    expect(convert.hex.encode(secret.seedBytes), englishSeed);
  });

  test('each call returns a buffer of its own', () async {
    final secret = await stored(bip39.Language.english);
    final first = liquidSeed(secret)..fillRange(0, 64, 0);
    expect(convert.hex.encode(liquidSeed(secret)), englishSeed);
    expect(first, everyElement(0));
  });
}
