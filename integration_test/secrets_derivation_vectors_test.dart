import 'dart:io';

import 'package:bb_mobile/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

/// Pins what `secrets` derives, against the FFI the unit suite cannot load.
///
/// Two halves. The first is funds-free and runs anywhere: fixed mnemonics in,
/// fixed keys and descriptors out — so a change in how a key is born fails
/// here instead of moving a user's wallet. The Liquid descriptor is only
/// checkable here at all, since lwk is FFI-bound.
///
/// The second checks that a refused signature is classified where it
/// happened and carries no library message — also FFI-only, since both
/// refusals come out of bdk and lwk. A *successful* signature needs funded
/// inputs and is proven where those exist: `coins_test.dart` and
/// `payjoin_test.dart`, both gated on `TEST_ALICE_MNEMONIC`.
Future<void> main({bool isInitialized = false}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (!isInitialized) await Bull.init();

  // The published BIP39 vector for entropy ffff…ff. Public, so no funds and
  // nothing to leak.
  const words = [
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

  late Secrets secrets;
  late Directory scratch;

  setUpAll(() async {
    scratch = await Directory.systemTemp.createTemp('secrets_vectors_');
    secrets = Secrets(scratchDirectory: () async => scratch.path);
  });

  tearDownAll(() async {
    if (scratch.existsSync()) await scratch.delete(recursive: true);
  });

  Future<Secret> importWords({String? passphrase}) async =>
      switch (await secrets.import(words: words, passphrase: passphrase)) {
        Ok(:final value) => value,
        Err(:final failure) => fail('import: ${failure.runtimeType}'),
      };

  T unwrap<T>(Result<T, SecretFailure> r) => switch (r) {
    Ok(:final value) => value,
    Err(:final failure) => fail('failed: ${failure.runtimeType}'),
  };

  group('derivation is pinned, so a key cannot be reborn by accident', () {
    test('the identity is the published master fingerprint', () async {
      final secret = await importWords();
      expect(secret.id.hex, '73c5da0a');
    });

    test('bip84 xpub, mainnet and testnet', () async {
      final secret = await importWords();

      expect(
        unwrap(
          await secret.derive.xpub(
            network: BitcoinNetwork.mainnet,
            scriptType: ScriptType.bip84,
          ),
        ),
        startsWith('zpub'),
      );
      expect(
        unwrap(
          await secret.derive.xpub(
            network: BitcoinNetwork.testnet,
            scriptType: ScriptType.bip84,
          ),
        ),
        startsWith('vpub'),
      );
    });

    test('the public descriptors carry no private key', () async {
      final secret = await importWords();

      final descriptors = unwrap(
        await secret.derive.descriptors.bitcoin(
          network: BitcoinNetwork.testnet,
          scriptType: ScriptType.bip84,
        ),
      );

      for (final d in [descriptors.external, descriptors.internal]) {
        expect(d, contains('wpkh('));
        expect(d, isNot(contains('tprv')));
        expect(d, isNot(contains('xprv')));
        for (final word in {...words}) {
          expect(d, isNot(contains(word)));
        }
      }
      expect(descriptors.internal, isNot(descriptors.external));
    });

    test('the Liquid descriptor ignores the passphrase, and says so', () async {
      // The claim the README makes about lwk, asserted against lwk itself —
      // the unit suite cannot, since this call needs the FFI.
      final plain = await importWords();
      final withPassphrase = await importWords(passphrase: 'TREZOR');
      expect(
        withPassphrase.id.hex,
        isNot(plain.id.hex),
        reason: 'two different secrets, so two different Bitcoin wallets',
      );

      final a = unwrap(
        await plain.derive.descriptors.liquid(network: LiquidNetwork.testnet),
      );
      final b = unwrap(
        await withPassphrase.derive.descriptors.liquid(
          network: LiquidNetwork.testnet,
        ),
      );

      expect(a, isA<WholeSecret<String>>());
      expect(
        b,
        isA<WordsOnly<String>>(),
        reason: 'the caller must be told the passphrase took no part',
      );
      expect(
        b.value,
        a.value,
        reason: 'same descriptor: same addresses, same funds',
      );
      expect(a.value, contains('ct('));
    });

    test('a BIP85 child is stable', () async {
      final secret = await importWords();

      expect(
        unwrap(await secret.derive.bip85.hex(numBytes: 32, index: 0)),
        unwrap(await secret.derive.bip85.hex(numBytes: 32, index: 0)),
      );
      expect(
        unwrap(await secret.derive.bip85.hex(numBytes: 32, index: 0)),
        isNot(unwrap(await secret.derive.bip85.hex(numBytes: 32, index: 1))),
      );
    });

    test('the swap key includes the passphrase', () async {
      // Decision of 2026-09-15: `walletPassphrase` is sent, so words alone no
      // longer determine the swap key.
      final plain = await importWords();
      final withPassphrase = await importWords(passphrase: 'TREZOR');

      final a = unwrap(
        await plain.derive.swapKey(network: BitcoinNetwork.testnet),
      );
      final b = unwrap(
        await withPassphrase.derive.swapKey(network: BitcoinNetwork.testnet),
      );

      expect(b.fingerprint, isNot(a.fingerprint));
      expect(b.xprv, isNot(a.xprv));
    });

    test(
      'a vault of a passphrase secret is marked, and restores with it',
      () async {
        final withPassphrase = await importWords(passphrase: 'TREZOR');
        final sealed = unwrap(await withPassphrase.backup.vault());
        expect(sealed, isA<WordsOnly<EncryptedVault>>());

        // The file alone gives the sibling; with the passphrase, the wallet.
        final bare = unwrap(
          await secrets.restoreVault(
            file: sealed.value.file,
            key: sealed.value.key,
          ),
        );
        expect(bare, isA<WordsOnly<RestoredVault>>());
        expect(bare.value.secret.id.hex, '73c5da0a');

        final whole = unwrap(
          await secrets.restoreVault(
            file: sealed.value.file,
            key: sealed.value.key,
            passphrase: 'TREZOR',
          ),
        );
        expect(whole, isA<WholeSecret<RestoredVault>>());
        expect(whole.value.secret.id.hex, withPassphrase.id.hex);
      },
    );
  });

  group('a refused signature is classified where it happened', () {
    // Only checkable with the FFI loaded: both refusals come out of bdk and
    // lwk. What they must not be is a `SecretFetchFailure` — that reads as
    // "your seed is unreadable" — and what they must not carry is the
    // library's own message, which quotes its input.
    test('a PSBT that does not parse is a derivation failure', () async {
      final secret = await importWords();

      final result = await secret.sign.psbt(
        'not a psbt',
        network: BitcoinNetwork.testnet,
        scriptType: ScriptType.bip84,
      );

      final failure = switch (result) {
        Err(:final failure) => failure,
        Ok() => fail('a non-PSBT was accepted'),
      };
      expect(failure, isA<SecretDerivationFailure>());
      expect(failure.logMessage, isNotNull);
      expect(failure.logMessage, isNot(contains('not a psbt')));
    });

    test('a PSET that does not parse carries no lwk message', () async {
      final secret = await importWords();

      final result = await secret.sign.pset(
        'not a pset',
        network: LiquidNetwork.testnet,
      );

      final failure = switch (result) {
        Err(:final failure) => failure,
        Ok() => fail('a non-PSET was accepted'),
      };
      expect(failure, isA<SecretDerivationFailure>());
      // `logMessage` is the exception's type name and nothing else — asserted
      // positively, so a null here cannot pass as "contains no word".
      expect(failure.logMessage, 'LiquidSigningFailed');
    });

    test('signing leaves no scratch directory behind', () async {
      // lwk has no in-memory persister, so each signature creates a directory
      // under the host's scratch path. A leftover would be a confidential
      // descriptor in an unencrypted file, outside the keystore.
      final secret = await importWords();
      final before = scratch.listSync().length;

      await secret.sign.pset('not a pset', network: LiquidNetwork.testnet);

      expect(scratch.listSync().length, before);
    });
  });
}
