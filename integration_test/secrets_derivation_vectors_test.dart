import 'dart:io';

import 'package:bb_mobile/main.dart';
import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

import '../packages/secrets/test/fixtures/liquid_signing_fixture.dart';

/// Pins what `secrets` derives, against the FFI the unit suite cannot load.
///
/// Two halves. The first is funds-free and runs anywhere: fixed mnemonics in,
/// fixed keys and descriptors out — so a change in how a key is born fails
/// here instead of moving a user's wallet. The Liquid descriptor is only
/// checkable here at all, since lwk is FFI-bound.
///
/// Offline signatures cover successful Liquid finalization here and successful Bitcoin finalization in the package unit suite. Refusal cases keep storage failures separate and drop library messages.
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
  final imported = <String, Secret>{};

  setUpAll(() async {
    scratch = await Directory.systemTemp.createTemp('secrets_vectors_');
    secrets = Secrets(scratchDirectory: () async => scratch.path);
  });

  tearDownAll(() async {
    if (scratch.existsSync()) await scratch.delete(recursive: true);
  });

  T unwrap<T>(Result<T, SecretFailure> r) => switch (r) {
    Ok(:final value) => value,
    Err(:final failure) => fail('failed: ${failure.runtimeType}'),
  };

  Future<Secret> importFixture(
    List<String> words, {
    String? passphrase,
  }) async =>
      switch (await secrets.import(words: words, passphrase: passphrase)) {
        Ok(:final value) => value,
        Err(failure: SecretAlreadyExistsFailure(:final id)) => unwrap(
          await secrets.fetch(id),
        ),
        Err(:final failure) => fail('import: ${failure.runtimeType}'),
      };

  Future<Secret> importWords({String? passphrase}) async {
    final key = passphrase ?? '';
    return imported[key] ??= await importFixture(words, passphrase: passphrase);
  }

  group('derivation is pinned, so a key cannot be reborn by accident', () {
    // The fingerprints and keys below are the same constants
    // `packages/secrets/test/fingerprint_vectors_test.dart` pins in pure Dart;
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

    test('the fingerprint is the master fingerprint of these words', () async {
      final secret = await importWords();
      expect(secret.id.hex, zooId);
    });

    test('account-one descriptors carry the selected testnet xpub', () async {
      final secret = await importWords();
      final xpub = unwrap(
        await secret.derive.xpub(
          network: BitcoinNetwork.testnet,
          scriptType: ScriptType.bip84,
          accountIndex: 1,
        ),
      );
      final descriptors = unwrap(
        await secret.derive.descriptors.bitcoin(
          network: BitcoinNetwork.testnet,
          scriptType: ScriptType.bip84,
          accountIndex: 1,
        ),
      );
      final canonicalKey = XpubType.tpub.reencode(xpub);
      expect(xpub, isNot(zooVpub));
      expect(
        descriptors.external,
        startsWith("wpkh([$zooId/84'/1'/1']$canonicalKey/0/*)"),
      );
      expect(
        descriptors.internal,
        startsWith("wpkh([$zooId/84'/1'/1']$canonicalKey/1/*)"),
      );
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

    test('the Liquid descriptor ignores the passphrase', () async {
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

      expect(b, a, reason: 'same descriptor: same addresses, same funds');
      expect(a, contains('ct('));
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
              wordCount: MnemonicWordCount.words12,
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
      'a vault restores its words with a separately supplied passphrase',
      () async {
        final withPassphrase = await importWords(passphrase: 'TREZOR');
        final sealed = unwrap(await withPassphrase.backup.recoverbull());

        // The file alone gives the sibling; with the passphrase, the wallet.
        final bare = unwrap(
          await secrets.recoverbull.restore(
            vault: sealed.vault,
            key: sealed.key,
          ),
        );
        expect(bare.secret.id.hex, zooId);

        final whole = unwrap(
          await secrets.recoverbull.restore(
            vault: sealed.vault,
            key: sealed.key,
            passphrase: 'TREZOR',
          ),
        );
        expect(whole.secret.id.hex, withPassphrase.id.hex);
      },
    );
  });

  test(
    'signs and finalizes the upstream Liquid fixture without chain access',
    () async {
      final secret = await importFixture([
        ...List.filled(11, 'abandon'),
        'about',
      ]);
      final unsigned = lwk.LiquidTransaction.fromPset(
        psetString: liquidSigningPset,
      );
      final before = scratch.listSync().length;
      final String expectedTxid;
      try {
        expect(unsigned.getInputs().single.witness, isEmpty);
        expectedTxid = unsigned.txid();
      } finally {
        unsigned.dispose();
      }

      final signed = unwrap(
        await secret.sign.pset(
          liquidSigningPset,
          network: LiquidNetwork.testnet,
        ),
      );
      final transaction = lwk.LiquidTransaction.fromPset(psetString: signed);
      try {
        final witness = transaction.getInputs().single.witness;
        expect(witness, hasLength(2));
        expect(witness.first, startsWith('30'), reason: 'DER-encoded ECDSA');
        expect(witness.first, endsWith('01'), reason: 'SIGHASH_ALL');
        expect(witness.last, liquidSigningPublicKey);
        expect(transaction.txid(), expectedTxid);
        expect(transaction.outputCount(), BigInt.from(3));
        expect(scratch.listSync().length, before);
      } finally {
        transaction.dispose();
      }
    },
  );

  group('a refused signature is classified where it happened', () {
    // Only checkable with the FFI loaded: both refusals come out of bdk and
    // lwk. What they must not be is a `FetchSecretFailure` — that reads as
    // "your seed is unreadable" — and what they must not carry is the
    // library's own message, which quotes its input.
    test('a PSBT that does not parse is a use failure', () async {
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
      expect(failure, isA<UseSecretFailure>());
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
      expect(failure, isA<UseSecretFailure>());
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

      expect(
        await secret.sign.pset('not a pset', network: LiquidNetwork.testnet),
        isA<Err<String, SecretFailure>>(),
      );

      expect(scratch.listSync().length, before);
    });
  });
}
