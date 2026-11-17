import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bull_ui/bull_ui.dart' show BullMnemonicKeyboard;
import 'package:flutter_test/flutter_test.dart';
import 'package:unorm_dart/unorm_dart.dart';

// The key labels are checked against every BIP39 wordlist, which only the app
// depends on; the keyboard's widget behaviour is tested in bull_ui.
void main() {
  group('BullMnemonicKeyboard.keyLabel', () {
    for (final language in bip39.Language.values) {
      test('${language.name} keys never share a label', () {
        final characters = {
          for (final word in language.list) ...nfkd(word).split(''),
        };
        final labels = {
          for (final character in characters)
            BullMnemonicKeyboard.keyLabel(character),
        };
        expect(labels, hasLength(characters.length));
      });
    }

    test('initial consonants and vowels show their compatibility jamo', () {
      for (final code in [
        for (var c = 0x1100; c <= 0x1112; c++) c,
        for (var c = 0x1161; c <= 0x1175; c++) c,
      ]) {
        final value = String.fromCharCode(code);
        final label = BullMnemonicKeyboard.keyLabel(value);
        expect(label, isNot(value));
        // Compatibility jamo decompose back to the conjoining initial/vowel.
        expect(nfkd(label), value);
      }
    });

    test('final consonants are drawn on a dotted circle', () {
      for (var code = 0x11A8; code <= 0x11C2; code++) {
        final label = BullMnemonicKeyboard.keyLabel(String.fromCharCode(code));
        expect(label.runes.first, 0x25CC);
        expect(label.runes, hasLength(2));
      }
    });

    test('plain letters and Han characters are shown unchanged', () {
      for (final value in ['a', 'z', '\u3042', '\u7684']) {
        expect(BullMnemonicKeyboard.keyLabel(value), value);
      }
    });
  });
}
