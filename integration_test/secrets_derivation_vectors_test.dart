import 'dart:io';

import 'package:bb_mobile/main.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
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
/// refusals come out of bdk and lwk. A *successful* signature is proven
/// elsewhere: a synthetic PSBT with a witness UTXO verifies an ECDSA
/// signature without funds — the auditor's probes do exactly that — and the
/// funded paths run in `coins_test.dart` and `payjoin_test.dart`.
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

  T scoped<T>(PassphraseScope<T> scope) => switch (scope) {
    WholeSecret(:final value) => value,
    WordsOnly(:final value) => value,
  };

  group('derivation is pinned, so a key cannot be reborn by accident', () {
    // The identities and keys below are the same constants
    // `packages/secrets/test/identity_vectors_test.dart` pins in pure Dart;
    // here they are asserted against bdk and lwk. `3f635a63` was computed
    // independently by a second auditor before being pinned.
    const zooId = '3f635a63';
    const zooZpub =
        'zpub6rD5AGSXPTDMSnpmczjENMT3NvVF7q5MySww6uxitUsBYgkZLeBywrcwUWhW5YkeY2aS7xc45APPgfA6s6wWfG2gnfABq6TDz9zqeMu2JCY';
    const zooVpub =
        'vpub5YePEeNjBvnC6tZF84CnP5tFTVEGSA9tdCunoueAReLc7AfmynBGnQdcwUmfoyyFyucAXxTMc4S895n71NVC3VsaTWQbahtw6MH4iUD56xJ';
    // The descriptor carries the account key in standard encoding — tpub on
    // test networks — whatever prefix the xpub is *displayed* with.
    const zooTpub =
        'tpubDCgYNDYFCZpc5H8LExm81BQd8YcpJndx14YXjFV5XZrFxexwZKMVAycjDvmdLJELb6NgeVAM4UyGbqVqqdATXQh5FnYkS4C9DkzmFc9A86Z';
    const zooBip85At0 =
        'c8e13c54dfebea496b2f3bcde9d92fc548119ec977037ba200294b7be6ac83d3';

    test('the identity is the master fingerprint of these words', () async {
      final secret = await importWords();
      expect(secret.id.hex, zooId);
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
        zooZpub,
      );
      expect(
        unwrap(
          await secret.derive.xpub(
            network: BitcoinNetwork.testnet,
            scriptType: ScriptType.bip84,
          ),
        ),
        zooVpub,
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

      // Pinned up to the checksum, which only bdk can compute: origin, path
      // and the account key are the whole of what a descriptor says.
      expect(
        descriptors.external,
        startsWith("wpkh([$zooId/84'/1'/0']$zooTpub/0/*)"),
      );
      expect(
        descriptors.internal,
        startsWith("wpkh([$zooId/84'/1'/0']$zooTpub/1/*)"),
      );
      for (final d in [descriptors.external, descriptors.internal]) {
        expect(d, isNot(contains('tprv')));
        expect(d, isNot(contains('xprv')));
        for (final word in {...words}) {
          expect(d, isNot(contains(word)));
        }
      }
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
        scoped(b),
        scoped(a),
        reason: 'same descriptor: same addresses, same funds',
      );
      expect(scoped(a), contains('ct('));
    });

    test('a BIP85 child is the pinned value', () async {
      final secret = await importWords();

      expect(
        unwrap(await secret.derive.bip85.hex(numBytes: 32, index: 0)),
        zooBip85At0,
      );
      expect(
        unwrap(await secret.derive.bip85.hex(numBytes: 32, index: 1)),
        isNot(zooBip85At0),
      );
    });

    test(
      'the swap key is a BIP85 child of the wallet, never its own key',
      () async {
        // boltz-client 0.4.1 derives the swap mnemonic as the 12-word BIP85
        // child 26589 of the wallet root; the package's own BIP85 is the
        // oracle, pinned against boltz's published vector in
        // packages/secrets/test/swap_key_vector_test.dart. So what swapKey
        // hands out is that child and its keys — not the words this secret
        // stores, and not a key under this secret's fingerprint.
        final secret = await importWords();
        for (final network in [
          BitcoinNetwork.mainnet,
          BitcoinNetwork.testnet,
        ]) {
          final key = unwrap(await secret.derive.swapKey(network: network));
          final child = unwrap(
            await secret.derive.bip85.mnemonic(
              length: bip39.MnemonicLength.words12,
              index: 26589,
            ),
          );

          expect(key.mnemonic, child.join(' '), reason: network.name);
          expect(key.mnemonic, isNot(words.join(' ')), reason: network.name);
          expect(key.fingerprint, isNot(secret.id), reason: network.name);
          expect(
            key.xpub,
            isNot(
              unwrap(
                await secret.derive.xpub(
                  network: network,
                  scriptType: ScriptType.bip84,
                ),
              ),
            ),
            reason: network.name,
          );
        }
      },
    );

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
            file: scoped(sealed).file,
            key: scoped(sealed).key,
          ),
        );
        expect(bare, isA<WordsOnly<RestoredVault>>());
        expect(scoped(bare).secret.id.hex, zooId);

        final whole = unwrap(
          await secrets.restoreVault(
            file: scoped(sealed).file,
            key: scoped(sealed).key,
            passphrase: 'TREZOR',
          ),
        );
        expect(whole, isA<WholeSecret<RestoredVault>>());
        expect(scoped(whole).secret.id.hex, withPassphrase.id.hex);
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
