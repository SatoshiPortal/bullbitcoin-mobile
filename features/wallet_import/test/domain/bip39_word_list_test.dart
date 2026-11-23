import 'package:wallet_import/src/domain/bip39_word_list.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';
import 'package:unorm_dart/unorm_dart.dart';

void main() {
  for (final language in [
    bip39.Language.simplifiedChinese,
    bip39.Language.traditionalChinese,
  ]) {
    test('${language.name} contains 2048 single BMP scalar words', () {
      expect(language.list, hasLength(2048));
      for (final entry in language.list) {
        final normalized = nfkd(entry);
        expect(normalized.runes.length, 1);
        expect(normalized.length, 1);
      }
    });
  }

  test('all wordlist characters fit a single UTF-16 code unit', () {
    for (final language in bip39.Language.values) {
      for (final entry in language.list) {
        final normalized = nfkd(entry);
        expect(normalized.length, normalized.runes.length);
      }
    }
  });

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
          Bip39WordList.allowedNextLetters(
            prefix: '',
            language: bip39.Language.english,
          ),
          equals(firstLetters),
        );
        // 'x' begins no english wordlist word, so it is never offered up front.
        expect(firstLetters, isNot(contains('x')));
      },
    );

    test("'a' cannot be followed by 'a' \u2014 no word starts with 'aa'", () {
      expect(
        Bip39WordList.allowedNextLetters(
          prefix: 'a',
          language: bip39.Language.english,
        ),
        isNot(contains('a')),
      );
      // But 'b' is fine: 'abandon', 'ability', ...
      expect(
        Bip39WordList.allowedNextLetters(
          prefix: 'a',
          language: bip39.Language.english,
        ),
        contains('b'),
      );
    });

    test('every offered letter actually extends the prefix to a real word', () {
      const prefix = 'ab';
      final allowed = Bip39WordList.allowedNextLetters(
        prefix: prefix,
        language: bip39.Language.english,
      );
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
      expect(
        Bip39WordList.allowedNextLetters(
          prefix: 'abandon',
          language: bip39.Language.english,
        ),
        isEmpty,
      );
    });

    test('a word that is a prefix of a longer word still offers letters', () {
      // 'act' is a word, but 'action'/'actor'/'actress'/'actual' extend it.
      expect(
        Bip39WordList.allowedNextLetters(
          prefix: 'act',
          language: bip39.Language.english,
        ),
        isNotEmpty,
      );
    });

    test('an impossible prefix offers no letters', () {
      expect(
        Bip39WordList.allowedNextLetters(
          prefix: 'zzz',
          language: bip39.Language.english,
        ),
        isEmpty,
      );
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

  group('Bip39WordList.allowedNextKeys', () {
    test(
      'an alphabetic wordlist offers a letter with its accent as one key',
      () {
        final keys = Bip39WordList.allowedNextKeys(
          prefix: '',
          language: bip39.Language.french,
        );
        expect(keys, contains(nfkd('\u00e9')));
        expect(keys.every((key) => key.runes.first < 0x0300), isTrue);
      },
    );

    test(
      'a bare letter is offered only when a word continues without accent',
      () {
        // Every offered key extends the prefix to a real word, and a bare
        // letter is one that word does not follow with an accent.
        for (final language in [
          bip39.Language.french,
          bip39.Language.spanish,
        ]) {
          final words = language.list.map(nfkd).toList();
          for (final prefix in ['', 'a', nfkd('\u00e9'), 'ca']) {
            for (final key in Bip39WordList.allowedNextKeys(
              prefix: prefix,
              language: language,
            )) {
              final next = prefix + key;
              expect(
                words.any(
                  (word) =>
                      word.startsWith(next) &&
                      (word.length == next.length ||
                          word.codeUnitAt(next.length) < 0x0300 ||
                          word.codeUnitAt(next.length) > 0x036F),
                ),
                isTrue,
                reason: '${language.name} "$next"',
              );
            }
          }
        }
      },
    );

    test('other scripts keep one code unit per key', () {
      expect(
        Bip39WordList.allowedNextKeys(
          prefix: nfkd('\u3042\u304a\u305d'),
          language: bip39.Language.japanese,
        ),
        Bip39WordList.allowedNextLetters(
          prefix: nfkd('\u3042\u304a\u305d'),
          language: bip39.Language.japanese,
        ),
      );
    });
  });

  group('Bip39WordList.accentedLetters', () {
    test('French lists é then è, Spanish its accented vowels and ñ', () {
      expect(Bip39WordList.accentedLetters(bip39.Language.french), [
        nfkd('\u00e9'),
        nfkd('\u00e8'),
      ]);
      expect(
        Bip39WordList.accentedLetters(bip39.Language.spanish),
        ['\u00e1', '\u00e9', '\u00ed', '\u00f1', '\u00f3', '\u00fa'].map(nfkd),
      );
    });

    test('wordlists without accents and other scripts list none', () {
      for (final language in [
        bip39.Language.english,
        bip39.Language.italian,
        bip39.Language.portuguese,
        bip39.Language.czech,
        bip39.Language.japanese,
        bip39.Language.korean,
      ]) {
        expect(Bip39WordList.accentedLetters(language), isEmpty);
      }
    });
  });
}
