import 'package:bb_mobile/features/import_mnemonic/domain/bip39_word_list.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unorm_dart/unorm_dart.dart';

void main() {
  test('empty or unknown input suggests no language', () {
    expect(Bip39WordList.matchingLanguages(['', ' ']), isEmpty);
    expect(Bip39WordList.matchingLanguages(['not-a-word']), isEmpty);
  });

  for (final language in Language.values) {
    test('${language.name} recognizes composed and decomposed vectors', () {
      // Published BIP39 zero-entropy vector, not a generated wallet.
      final words = Mnemonic(List.filled(16, 0), language).words;
      for (final normalize in [nfc, nfkd]) {
        final input = words
            .map(
              (word) =>
                  '${language.separator}${normalize(word)}${language.separator}',
            )
            .toList();
        expect(
          Bip39WordList.matchingLanguages(input, requireChecksum: true),
          contains(language),
        );
      }
    });
  }

  test('a language match does not imply a valid checksum', () {
    final words = List.filled(12, 'abandon');
    expect(Bip39WordList.matchingLanguages(words), contains(Language.english));
    expect(
      Bip39WordList.matchingLanguages(words, requireChecksum: true),
      isNot(contains(Language.english)),
    );
  });

  test('shared English French words retain both checksum-valid readings', () {
    const words = [
      'crucial',
      'million',
      'voyage',
      'sentence',
      'mobile',
      'suspect',
      'double',
      'minute',
      'virus',
      'noble',
      'junior',
      'wagon',
    ];
    expect(
      Bip39WordList.matchingLanguages(words, requireChecksum: true),
      containsAll([Language.english, Language.french]),
    );
  });
}
