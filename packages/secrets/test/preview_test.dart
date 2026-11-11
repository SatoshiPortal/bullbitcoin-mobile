import 'dart:convert';
import 'dart:typed_data';

import 'package:bip32_keys/bip32_keys.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:convert/convert.dart' as convert;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

import 'result_helpers.dart';

/// `secrets.preview` derives public descriptors from words that are not stored, for the scan that runs before an import.
void main() {
  const words = [
    'abandon', 'abandon', 'abandon', 'abandon', 'abandon', 'abandon', //
    'abandon', 'abandon', 'abandon', 'abandon', 'abandon', 'about',
  ];

  late FakeSecureStoragePlatform storage;
  late Secrets secrets;

  setUp(() {
    storage = FakeSecureStoragePlatform()..install();
    secrets = Secrets(scratchDirectory: () async => '/tmp');
  });

  Future<Descriptors> preview(
    List<String> words, {
    bip39.Language language = bip39.Language.english,
    String? passphrase,
    BitcoinNetwork network = BitcoinNetwork.mainnet,
    ScriptType scriptType = ScriptType.bip84,
  }) async =>
      ok(
        await secrets.preview.bitcoinDescriptors(
          words: words,
          language: language,
          passphrase: passphrase,
          network: network,
          scriptTypes: {scriptType},
        ),
      )[scriptType] ??
      fail('no descriptors for $scriptType');

  group('equals the descriptors of the same words once stored', () {
    for (final passphrase in [null, 'TREZOR']) {
      for (final network in [BitcoinNetwork.mainnet, BitcoinNetwork.testnet]) {
        for (final scriptType in ScriptType.values) {
          test(
            '$network / $scriptType / passphrase: ${passphrase != null}',
            () async {
              final previewed = await preview(
                words,
                passphrase: passphrase,
                network: network,
                scriptType: scriptType,
              );
              final secret = ok(
                await secrets.import(words: words, passphrase: passphrase),
              );
              final stored = ok(
                await secret.derive.descriptors.bitcoin(
                  network: network,
                  scriptType: scriptType,
                ),
              );
              expect(previewed, stored);
            },
          );
        }
      }
    }
  });

  // The scan used to build its descriptors in the wallet package from the entropy and passphrase with bdk's templates. English mnemonics must scan exactly the same descriptors as before.
  group('equals the former template derivation for English words', () {
    String template(
      ScriptType scriptType,
      BitcoinNetwork network,
      String passphrase,
      bdk.KeychainKind keychain,
    ) {
      final networkKind = network.isMainnet
          ? bdk.NetworkKind.main
          : bdk.NetworkKind.test;
      final mnemonic = bdk.Mnemonic.fromEntropy(
        entropy: Uint8List.fromList(
          bip39.Mnemonic.fromWords(words: words).entropy,
        ),
      );
      final key = bdk.DescriptorSecretKey(
        networkKind: networkKind,
        mnemonic: mnemonic,
        password: passphrase,
      );
      final descriptor = switch (scriptType) {
        ScriptType.bip84 => bdk.Descriptor.newBip84(
          secretKey: key,
          keychainKind: keychain,
          networkKind: networkKind,
        ),
        ScriptType.bip49 => bdk.Descriptor.newBip49(
          secretKey: key,
          keychainKind: keychain,
          networkKind: networkKind,
        ),
        ScriptType.bip44 => bdk.Descriptor.newBip44(
          secretKey: key,
          keychainKind: keychain,
          networkKind: networkKind,
        ),
      };
      try {
        return descriptor.toString();
      } finally {
        descriptor.dispose();
        key.dispose();
        mnemonic.dispose();
      }
    }

    for (final passphrase in ['', 'TREZOR']) {
      for (final network in [BitcoinNetwork.mainnet, BitcoinNetwork.testnet]) {
        for (final scriptType in ScriptType.values) {
          test(
            '$network / $scriptType / passphrase: ${passphrase.isNotEmpty}',
            () async {
              final previewed = await preview(
                words,
                passphrase: passphrase,
                network: network,
                scriptType: scriptType,
              );
              expect(previewed, (
                external: template(
                  scriptType,
                  network,
                  passphrase,
                  bdk.KeychainKind.external_,
                ),
                internal: template(
                  scriptType,
                  network,
                  passphrase,
                  bdk.KeychainKind.internal,
                ),
              ));
            },
          );
        }
      }
    }
  });

  group('several script types in one call', () {
    for (final passphrase in [null, 'TREZOR']) {
      for (final network in [BitcoinNetwork.mainnet, BitcoinNetwork.testnet]) {
        test('$network / passphrase: ${passphrase != null}', () async {
          final previewed = ok(
            await secrets.preview.bitcoinDescriptors(
              words: words,
              passphrase: passphrase,
              network: network,
              scriptTypes: ScriptType.values.toSet(),
            ),
          );
          expect(previewed.keys, ScriptType.values);
          // Each pair equals the one previewed alone and the one the stored words derive.
          final secret = ok(
            await secrets.import(words: words, passphrase: passphrase),
          );
          for (final scriptType in ScriptType.values) {
            final alone = await preview(
              words,
              passphrase: passphrase,
              network: network,
              scriptType: scriptType,
            );
            final stored = ok(
              await secret.derive.descriptors.bitcoin(
                network: network,
                scriptType: scriptType,
              ),
            );
            expect(previewed[scriptType], alone);
            expect(previewed[scriptType], stored);
          }
        });
      }
    }

    test('invalid words fail the whole call', () async {
      expect(
        err(
          await secrets.preview.bitcoinDescriptors(
            words: [...words.take(11), 'abandon'],
            network: BitcoinNetwork.mainnet,
            scriptTypes: ScriptType.values.toSet(),
          ),
        ),
        isA<InvalidMnemonicFailure>(),
      );
    });
  });

  group('a Japanese mnemonic', () {
    // The first Japanese vector of the reference test suite (bip32JP), also shipped in bip39_mnemonic 4.1.0's `test/vectors.dart`: entropy 0x00…00.
    const japanese =
        'あいこくしん　あいこくしん　あいこくしん　あいこくしん　あいこくしん　あいこくしん　'
        'あいこくしん　あいこくしん　あいこくしん　あいこくしん　あいこくしん　あおぞら';
    const passphrase = 'メートルガバヴァぱばぐゞちぢ十人十色';
    const seedHex =
        'a262d6fb6122ecf45be09c50492b31f92e9beb7d9a845987a02cefda57a15f9c'
        '467a17872029a9e92299b5cbdf306e3a0ee620245cbd508959b6cb7ca637bd55';
    final japaneseWords = japanese.split('　');

    /// `[fingerprint/84'/0'/0']xpub` of the reference seed, derived without the package.
    String accountKey(Uint8List seed) {
      final root = Bip32Keys.fromSeed(seed);
      final account = root.derivePath("m/84'/0'/0'").neutered.toBase58();
      final fingerprint = convert.hex.encode(root.fingerprint);
      return "[$fingerprint/84'/0'/0']$account";
    }

    test('previews the descriptors of its own seed', () async {
      final previewed = await preview(
        japaneseWords,
        language: bip39.Language.japanese,
        passphrase: passphrase,
      );
      final expected = accountKey(
        Uint8List.fromList(convert.hex.decode(seedHex)),
      );
      expect(previewed.external, startsWith('wpkh($expected/0/*)#'));
      expect(previewed.internal, startsWith('wpkh($expected/1/*)#'));
    });

    test('is not scanned as the English re-encoding of its entropy', () async {
      final entropy = bip39.Mnemonic.fromWords(
        words: japaneseWords,
        language: bip39.Language.japanese,
      ).entropy;
      final englishTwin = bip39.Mnemonic(entropy, bip39.Language.english).words;
      expect(englishTwin.first, 'abandon');

      final previewed = await preview(
        japaneseWords,
        language: bip39.Language.japanese,
        passphrase: passphrase,
      );
      final twin = await preview(englishTwin, passphrase: passphrase);
      expect(previewed.external, isNot(twin.external));
      expect(previewed.internal, isNot(twin.internal));
    });

    test('is refused when read as English', () async {
      expect(
        err(
          await secrets.preview.bitcoinDescriptors(
            words: japaneseWords,
            passphrase: passphrase,
            network: BitcoinNetwork.mainnet,
            scriptTypes: {ScriptType.bip84},
          ),
        ),
        isA<InvalidMnemonicFailure>(),
      );
    });
  });

  test('invalid words return InvalidMnemonicFailure', () async {
    final failure = err(
      await secrets.preview.bitcoinDescriptors(
        words: [...words.take(11), 'abandon'],
        network: BitcoinNetwork.mainnet,
        scriptTypes: {ScriptType.bip84},
      ),
    );
    expect(failure, isA<InvalidMnemonicFailure>());
    // No candidate word travels in the failure.
    expect(failure.toString(), isNot(contains('abandon')));
  });

  test('neither reads nor writes the keystore', () async {
    // A keystore that refuses every access: the preview must not need it.
    final locked = FakeSecureStoragePlatform(locked: true, writesFail: true)
      ..install();

    await preview(words, passphrase: 'TREZOR');

    expect(locked.reads, 0);
    expect(locked.entries, isEmpty);
    expect(storage.entries, isEmpty);
  });

  test('the descriptors carry no private key', () async {
    final previewed = await preview(words, passphrase: 'TREZOR');
    for (final descriptor in [previewed.external, previewed.internal]) {
      expect(descriptor, isNot(matches(RegExp('[xt]prv'))));
    }
    // Neither the words nor the passphrase appear in the result.
    final encoded = jsonEncode([previewed.external, previewed.internal]);
    expect(encoded, isNot(contains('abandon')));
    expect(encoded, isNot(contains('TREZOR')));
  });
}
