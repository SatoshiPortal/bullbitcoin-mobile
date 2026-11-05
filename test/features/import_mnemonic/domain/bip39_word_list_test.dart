import 'package:bb_mobile/features/import_mnemonic/domain/bip39_word_list.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';
import 'package:unorm_dart/unorm_dart.dart';

void main() {
  group('Unicode prefixes', () {
    for (final (language, composed) in [
      (bip39.Language.spanish, 'ábaco'),
      (bip39.Language.japanese, 'あおぞら'),
      (bip39.Language.korean, '가격'),
    ]) {
      test('${language.name} accepts equivalent composed prefixes', () {
        final word = nfkd(composed);
        final prefix = word.substring(0, word.length - 1);
        final expected = Bip39WordList.allowedNextLetters(
          prefix: prefix,
          language: language,
        );
        expect(expected, isNotEmpty);
        expect(
          Bip39WordList.allowedNextLetters(
            prefix: nfc(prefix),
            language: language,
          ),
          expected,
        );
      });
    }
  });

  group('Bip39WordList.allowedNextLetters', () {
    final list = bip39.Language.english.list;

    test(
      'an empty prefix offers exactly the letters some word begins with',
      () {
        final firstLetters = {for (final word in list) word[0]};

        expect(
          Bip39WordList.allowedNextLetters(prefix: ''),
          equals(firstLetters),
        );
        // 'x' begins no english wordlist word, so it is never offered up front.
        expect(firstLetters, isNot(contains('x')));
      },
    );

    test("'a' cannot be followed by 'a' \u2014 no word starts with 'aa'", () {
      expect(
        Bip39WordList.allowedNextLetters(prefix: 'a'),
        isNot(contains('a')),
      );
      // But 'b' is fine: 'abandon', 'ability', ...
      expect(Bip39WordList.allowedNextLetters(prefix: 'a'), contains('b'));
    });

    test('every offered letter actually extends the prefix to a real word', () {
      const prefix = 'ab';
      final allowed = Bip39WordList.allowedNextLetters(prefix: prefix);
      for (final letter in allowed) {
        expect(
          list.any((word) => word.startsWith('$prefix$letter')),
          isTrue,
          reason: "'$prefix$letter' should be the start of some word",
        );
      }
    });

    test('a uniquely-determined word offers nothing more (backspace only)', () {
      // 'abandon' is the only word starting with 'aba', and no longer word
      // extends it: once complete, no letter can be added.
      expect(list.where((w) => w.startsWith('aba')), equals(['abandon']));
      expect(Bip39WordList.allowedNextLetters(prefix: 'abandon'), isEmpty);
    });

    test('a word that is a prefix of a longer word still offers letters', () {
      // 'act' is a word, but 'action'/'actor'/'actress'/'actual' extend it.
      expect(Bip39WordList.allowedNextLetters(prefix: 'act'), isNotEmpty);
    });

    test('an impossible prefix offers no letters', () {
      expect(Bip39WordList.allowedNextLetters(prefix: 'zzz'), isEmpty);
    });
  });

  group('Bip39WordList.orderedNextLetters', () {
    for (final language in [
      bip39.Language.simplifiedChinese,
      bip39.Language.traditionalChinese,
    ]) {
      test('${language.name} keeps the frequency order of its wordlist', () {
        expect(
          Bip39WordList.orderedNextLetters(prefix: '', language: language),
          language.list.map(nfkd).toList(),
        );
      });
    }

    test('alphabetic wordlists stay sorted by code point', () {
      final spanish = Bip39WordList.orderedNextLetters(
        prefix: '',
        language: bip39.Language.spanish,
      );
      expect(spanish, [...spanish]..sort());
    });
  });
}
