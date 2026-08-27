import 'package:bb_mobile/core/utils/bip39.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
