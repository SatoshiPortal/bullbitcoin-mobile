import 'dart:convert';
import 'dart:typed_data';

import 'package:bip32_keys/bip32_keys.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;

import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

import 'result_helpers.dart';

void main() {
  final words = [...List.filled(11, 'abandon'), 'about'];
  late FakeSecureStoragePlatform storage;
  late Secrets secrets;

  setUp(() {
    storage = FakeSecureStoragePlatform()..install();
    secrets = Secrets(scratchDirectory: () async => '/tmp');
  });

  test('explicit BIP48 origins match independent BDK derivation', () async {
    final secret = ok(await secrets.import(words: words));
    for (final network in [BitcoinNetwork.mainnet, BitcoinNetwork.testnet]) {
      for (final accountIndex in [0, 7]) {
        final path = "m/48'/${network.coinType}'/$accountIndex'/2'";
        final account = ok(
          await secret.derive.account(
            derivationPath: path.replaceAll("'", 'h'),
            network: network,
          ),
        );
        final mnemonic = bdk.Mnemonic.fromString(mnemonic: words.join(' '));
        final root = bdk.DescriptorSecretKey(
          networkKind: network.isMainnet
              ? bdk.NetworkKind.main
              : bdk.NetworkKind.test,
          mnemonic: mnemonic,
          password: null,
        );
        final nativePath = bdk.DerivationPath(path: path);
        final derived = root.derive(path: nativePath);
        final public = derived.asPublic();
        try {
          expect(account.fingerprint, secret.id);
          expect(account.derivationPath, path);
          expect(account.xpub, public.toString().split(']').last);
        } finally {
          public.dispose();
          derived.dispose();
          nativePath.dispose();
          root.dispose();
          mnemonic.dispose();
        }
      }
    }
  });

  for (final language in [Language.english, Language.japanese]) {
    final sourceWords = bip39.Mnemonic(List.filled(16, 0), language).words;
    test(
      '${language.name} stored and operation passphrases keep distinct public identities',
      () async {
        final secret = ok(
          await secrets.import(
            words: sourceWords,
            language: language,
            passphrase: 'stored',
          ),
        );
        final entries = Map<String, String>.of(storage.entries);
        const path = "m/48'/0'/0'/2'";
        for (final override in <String?>[null, '', 'operation']) {
          final account = ok(
            await secret.derive.account(
              derivationPath: path,
              network: BitcoinNetwork.mainnet,
              passphrase: override,
            ),
          );
          final preview = ok(
            await secrets.preview.account(
              words: sourceWords,
              language: language,
              derivationPath: path,
              network: BitcoinNetwork.mainnet,
              passphrase: override ?? 'stored',
            ),
          );
          final reference = bip39.Mnemonic.fromWords(
            words: sourceWords,
            language: language,
            passphrase: override ?? 'stored',
          );
          expect(
            account.xpub,
            Bip32Keys.fromSeed(
              Uint8List.fromList(reference.seed),
            ).derivePath(path).neutered.toBase58(),
          );
          expect(account.xpub, preview.xpub);
          expect(account.fingerprint, preview.fingerprint);
          expect(account.fingerprint == secret.id, override == null);
        }
        expect(storage.entries, entries);
      },
    );

    test(
      '${language.name} canonical retention preserves both stored entries',
      () async {
        final original = ok(
          await secrets.import(
            words: sourceWords,
            language: language,
            passphrase: 'stored',
          ),
        );
        final encodedOriginal = storage.entries['seed_${original.id.hex}'];
        final canonical = ok(await secrets.retainCanonical(original.id));
        final entries = Map<String, String>.of(storage.entries);
        final reference = ok(
          await secrets.preview.account(
            words: sourceWords,
            language: language,
            derivationPath: "m/48'/0'/0'/2'",
            network: BitcoinNetwork.mainnet,
          ),
        );
        expect(canonical.id, reference.fingerprint);
        expect(canonical.info.language, language);
        expect(canonical.info.hasPassphrase, isFalse);
        expect(ok(await secrets.retainCanonical(original.id)).id, canonical.id);
        expect(storage.entries, entries);
        expect(storage.entries['seed_${original.id.hex}'], encodedOriginal);
        expect(storage.entries, hasLength(2));
      },
    );
  }

  test(
    'canonical retention validates the original before creating a sibling',
    () async {
      final original = ok(
        await secrets.import(words: words, passphrase: 'stored'),
      );
      storage.entries['seed_${original.id.hex}'] = jsonEncode({
        'mnemonicWords': words,
        'passphrase': 'changed',
        'runtimeType': 'mnemonic',
      });
      expect(
        err(await secrets.retainCanonical(original.id)),
        isA<FingerprintMismatchFailure>(),
      );
      expect(storage.entries, hasLength(1));
    },
  );

  test('preview does not import words and rejects invalid input', () async {
    final key = ok(
      await secrets.preview.account(
        words: words,
        derivationPath: "m/48'/0'/0'/2'",
        network: BitcoinNetwork.mainnet,
      ),
    );
    expect(key.fingerprint, Fingerprint('73c5da0a'));
    expect(
      err(
        await secrets.preview.account(
          words: List.filled(12, 'abandon'),
          derivationPath: "m/48'/0'/0'/2'",
          network: BitcoinNetwork.mainnet,
        ),
      ),
      isA<InvalidMnemonicFailure>(),
    );
    expect(storage.entries, isEmpty);
    expect(storage.reads, 0);
  });

  test(
    'ephemeral setup derives public keys and closes without storing a seed',
    () async {
      final ephemeral = ok(await secrets.generateEphemeral());
      final account = ok(
        await ephemeral.account(
          derivationPath: "m/48'/0'/0'/2'",
          network: BitcoinNetwork.mainnet,
        ),
      );
      expect(account.fingerprint, ephemeral.id);
      expect(ephemeral.wordCount, 24);
      ephemeral.dispose();
      expect(
        err(
          await ephemeral.account(
            derivationPath: "m/48'/0'/0'/2'",
            network: BitcoinNetwork.mainnet,
          ),
        ),
        isA<UseSecretFailure>(),
      );
      expect(storage.entries, isEmpty);
      expect(storage.reads, 0);
    },
  );
}
