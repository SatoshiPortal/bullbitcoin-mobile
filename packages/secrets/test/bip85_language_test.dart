import 'dart:typed_data';

import 'package:bip32_keys/bip32_keys.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bip85_entropy/bip85_entropy.dart';
import 'package:convert/convert.dart' as convert;
import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

import 'result_helpers.dart';

void main() {
  test('the child wordlist is independent of the Japanese parent', () async {
    FakeSecureStoragePlatform().install();
    final secrets = Secrets(scratchDirectory: () async => '/tmp');
    final parent = ok(
      await secrets.import(
        words: [...List.filled(11, 'あいこくしん'), 'あおぞら'],
        language: bip39.Language.japanese,
        passphrase: 'メートルガバヴァぱばぐゞちぢ十人十色',
      ),
    );
    // Published bip32JP BIP39 seed, independent of the package's PBKDF2.
    final reference = Bip32Keys.fromSeed(
      Uint8List.fromList(
        convert.hex.decode(
          'a262d6fb6122ecf45be09c50492b31f92e9beb7d9a845987a02cefda57a15f9c'
          '467a17872029a9e92299b5cbdf306e3a0ee620245cbd508959b6cb7ca637bd55',
        ),
      ),
    ).toBase58();
    for (final language in bip39.Language.values) {
      final words = ok(
        await parent.derive.bip85.mnemonic(
          wordCount: MnemonicLength.words12,
          index: 11811,
          language: language,
        ),
      );
      final expected = Bip85Entropy.deriveMnemonic(
        xprvBase58: reference,
        language: language,
        length: bip39.MnemonicLength.words12,
        index: 11811,
      ).words;
      expect(words, expected);
      expect(
        bip39.Mnemonic.fromWords(words: words, language: language).words,
        words,
      );
    }
    final ark = ok(
      await parent.derive.bip85.mnemonic(
        wordCount: MnemonicLength.words12,
        index: 11811,
        language: bip39.Language.english,
      ),
    );
    final defaultChild = ok(
      await parent.derive.bip85.mnemonic(
        wordCount: MnemonicLength.words12,
        index: 11811,
      ),
    );
    expect(defaultChild, ark);
    expect(parent.info.language, bip39.Language.japanese);
  });
}
