import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:convert/convert.dart' as convert;
import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/src/crypto/crypto.dart';
import 'package:unorm_dart/unorm_dart.dart';

/// The package derives seeds through bip39 only; these tests pin the published vector, the NFKD wordlists `painted_text.dart` relies on, and the equality with bip39 for every language and Unicode passphrases.
void main() {
  final abandon = List.filled(11, 'abandon') + ['about'];
  final zoo = List.filled(11, 'zoo') + ['wrong'];

  test('matches the published BIP39 vector', () {
    expect(
      convert.hex.encode(
        Deriver.fingerprint.seed(
          abandon,
          passphrase: 'TREZOR',
          language: bip39.Language.english,
        ),
      ),
      'c55257c360c07c72029aebc1b53c05ed0362ada38ead3e3e9efa3708e5349553'
      '1f09a6987599d18264c1e1c92f2cf141630c7a3c4ab7c81b2f001698e7463b04',
    );
  });

  for (final passphrase in ['', 'TREZOR', 'é', 'é', 'Ａｂｃ ½', '🔑']) {
    for (final words in [abandon, zoo]) {
      test('matches bip39 for ${words.last} with "$passphrase"', () {
        expect(
          Deriver.fingerprint.seed(
            words,
            passphrase: passphrase,
            language: bip39.Language.english,
          ),
          bip39.Mnemonic.fromWords(words: words, passphrase: passphrase).seed,
        );
      });
    }
  }

  // `painted_text.dart` paints the wordlists as they are, so every list must
  // already be NFKD.
  for (final language in bip39.Language.values) {
    test('${language.name}: wordlist is NFKD and the seed matches bip39', () {
      expect(language.list.where((word) => nfkd(word) != word), isEmpty);
      final words = bip39.Mnemonic(List.filled(16, 0x5a), language).words;
      for (final passphrase in ['', 'Ａｂｃ ½']) {
        expect(
          Deriver.fingerprint.seed(
            words,
            passphrase: passphrase,
            language: language,
          ),
          bip39.Mnemonic.fromWords(
            words: words,
            passphrase: passphrase,
            language: language,
          ).seed,
        );
      }
    });
  }
}
