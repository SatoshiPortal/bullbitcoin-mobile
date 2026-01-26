import 'package:bb_mobile/features/secrets/domain/secrets_domain_error.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/mnemonic_words.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MnemonicWords - Valid Cases', () {
    test('should create MnemonicWords with 12 words', () {
      // Arrange
      final words = List.generate(12, (i) => 'word$i');

      // Act
      final mnemonicWords = MnemonicWords(words);

      // Assert
      expect(mnemonicWords.value, words);
      expect(mnemonicWords.value.length, 12);
    });

    test('should create MnemonicWords with 15 words', () {
      // Arrange
      final words = List.generate(15, (i) => 'word$i');

      // Act
      final mnemonicWords = MnemonicWords(words);

      // Assert
      expect(mnemonicWords.value, words);
      expect(mnemonicWords.value.length, 15);
    });

    test('should create MnemonicWords with 18 words', () {
      // Arrange
      final words = List.generate(18, (i) => 'word$i');

      // Act
      final mnemonicWords = MnemonicWords(words);

      // Assert
      expect(mnemonicWords.value, words);
      expect(mnemonicWords.value.length, 18);
    });

    test('should create MnemonicWords with 21 words', () {
      // Arrange
      final words = List.generate(21, (i) => 'word$i');

      // Act
      final mnemonicWords = MnemonicWords(words);

      // Assert
      expect(mnemonicWords.value, words);
      expect(mnemonicWords.value.length, 21);
    });

    test('should create MnemonicWords with 24 words', () {
      // Arrange
      final words = List.generate(24, (i) => 'word$i');

      // Act
      final mnemonicWords = MnemonicWords(words);

      // Assert
      expect(mnemonicWords.value, words);
      expect(mnemonicWords.value.length, 24);
    });

    test('should create MnemonicWords with actual BIP39 words', () {
      // Arrange
      final words = [
        'abandon',
        'ability',
        'able',
        'about',
        'above',
        'absent',
        'absorb',
        'abstract',
        'absurd',
        'abuse',
        'access',
        'accident',
      ];

      // Act
      final mnemonicWords = MnemonicWords(words);

      // Assert
      expect(mnemonicWords.value, words);
      expect(mnemonicWords.value.length, 12);
    });

    test('should create immutable list of words', () {
      // Arrange
      final words = List.generate(12, (i) => 'word$i');
      final mnemonicWords = MnemonicWords(words);

      // Act & Assert
      expect(
        () => mnemonicWords.value.add('extraWord'),
        throwsUnsupportedError,
        reason: 'Should not be able to modify the word list',
      );
    });

    test('should not be affected by changes to original list', () {
      // Arrange
      final words = List.generate(12, (i) => 'word$i');
      final mnemonicWords = MnemonicWords(words);

      // Act
      words.add('extraWord');

      // Assert
      expect(mnemonicWords.value.length, 12);
      expect(mnemonicWords.value, isNot(contains('extraWord')));
    });
  });

  group('MnemonicWords - Invalid Word Count', () {
    test('should throw InvalidMnemonicWordCountError for empty list', () {
      // Arrange
      final emptyWords = <String>[];

      // Act & Assert
      expect(
        () => MnemonicWords(emptyWords),
        throwsA(
          isA<InvalidMnemonicWordCountError>()
              .having(
                (e) => e.message,
                'message',
                contains('cannot be empty'),
              )
              .having(
                (e) => e.actualCount,
                'actualCount',
                0,
              ),
        ),
      );
    });

    test('should throw InvalidMnemonicWordCountError for 11 words', () {
      // Arrange
      final words = List.generate(11, (i) => 'word$i');

      // Act & Assert
      expect(
        () => MnemonicWords(words),
        throwsA(
          isA<InvalidMnemonicWordCountError>()
              .having(
                (e) => e.message,
                'message',
                contains('must have 12, 15, 18, 21, or 24 words'),
              )
              .having(
                (e) => e.actualCount,
                'actualCount',
                11,
              ),
        ),
      );
    });

    test('should throw InvalidMnemonicWordCountError for 13 words', () {
      // Arrange
      final words = List.generate(13, (i) => 'word$i');

      // Act & Assert
      expect(
        () => MnemonicWords(words),
        throwsA(
          isA<InvalidMnemonicWordCountError>()
              .having(
                (e) => e.message,
                'message',
                contains('Got 13 words'),
              )
              .having(
                (e) => e.actualCount,
                'actualCount',
                13,
              ),
        ),
      );
    });

    test('should throw InvalidMnemonicWordCountError for 14 words', () {
      // Arrange
      final words = List.generate(14, (i) => 'word$i');

      // Act & Assert
      expect(
        () => MnemonicWords(words),
        throwsA(
          isA<InvalidMnemonicWordCountError>().having(
            (e) => e.actualCount,
            'actualCount',
            14,
          ),
        ),
      );
    });

    test('should throw InvalidMnemonicWordCountError for 16 words', () {
      // Arrange
      final words = List.generate(16, (i) => 'word$i');

      // Act & Assert
      expect(
        () => MnemonicWords(words),
        throwsA(
          isA<InvalidMnemonicWordCountError>().having(
            (e) => e.actualCount,
            'actualCount',
            16,
          ),
        ),
      );
    });

    test('should throw InvalidMnemonicWordCountError for 17 words', () {
      // Arrange
      final words = List.generate(17, (i) => 'word$i');

      // Act & Assert
      expect(
        () => MnemonicWords(words),
        throwsA(
          isA<InvalidMnemonicWordCountError>().having(
            (e) => e.actualCount,
            'actualCount',
            17,
          ),
        ),
      );
    });

    test('should throw InvalidMnemonicWordCountError for 19 words', () {
      // Arrange
      final words = List.generate(19, (i) => 'word$i');

      // Act & Assert
      expect(
        () => MnemonicWords(words),
        throwsA(
          isA<InvalidMnemonicWordCountError>().having(
            (e) => e.actualCount,
            'actualCount',
            19,
          ),
        ),
      );
    });

    test('should throw InvalidMnemonicWordCountError for 20 words', () {
      // Arrange
      final words = List.generate(20, (i) => 'word$i');

      // Act & Assert
      expect(
        () => MnemonicWords(words),
        throwsA(
          isA<InvalidMnemonicWordCountError>().having(
            (e) => e.actualCount,
            'actualCount',
            20,
          ),
        ),
      );
    });

    test('should throw InvalidMnemonicWordCountError for 22 words', () {
      // Arrange
      final words = List.generate(22, (i) => 'word$i');

      // Act & Assert
      expect(
        () => MnemonicWords(words),
        throwsA(
          isA<InvalidMnemonicWordCountError>().having(
            (e) => e.actualCount,
            'actualCount',
            22,
          ),
        ),
      );
    });

    test('should throw InvalidMnemonicWordCountError for 23 words', () {
      // Arrange
      final words = List.generate(23, (i) => 'word$i');

      // Act & Assert
      expect(
        () => MnemonicWords(words),
        throwsA(
          isA<InvalidMnemonicWordCountError>().having(
            (e) => e.actualCount,
            'actualCount',
            23,
          ),
        ),
      );
    });

    test('should throw InvalidMnemonicWordCountError for 25 words', () {
      // Arrange
      final words = List.generate(25, (i) => 'word$i');

      // Act & Assert
      expect(
        () => MnemonicWords(words),
        throwsA(
          isA<InvalidMnemonicWordCountError>().having(
            (e) => e.actualCount,
            'actualCount',
            25,
          ),
        ),
      );
    });

    test('should throw InvalidMnemonicWordCountError for 100 words', () {
      // Arrange
      final words = List.generate(100, (i) => 'word$i');

      // Act & Assert
      expect(
        () => MnemonicWords(words),
        throwsA(
          isA<InvalidMnemonicWordCountError>().having(
            (e) => e.actualCount,
            'actualCount',
            100,
          ),
        ),
      );
    });

    test('should throw InvalidMnemonicWordCountError for single word', () {
      // Arrange
      final words = ['word'];

      // Act & Assert
      expect(
        () => MnemonicWords(words),
        throwsA(
          isA<InvalidMnemonicWordCountError>().having(
            (e) => e.actualCount,
            'actualCount',
            1,
          ),
        ),
      );
    });
  });

  group('MnemonicWords - Equality', () {
    test('should be equal when word lists are identical', () {
      // Arrange
      final words1 = List.generate(12, (i) => 'word$i');
      final words2 = List.generate(12, (i) => 'word$i');
      final mnemonicWords1 = MnemonicWords(words1);
      final mnemonicWords2 = MnemonicWords(words2);

      // Act & Assert
      expect(mnemonicWords1, equals(mnemonicWords2));
      expect(mnemonicWords1.hashCode, equals(mnemonicWords2.hashCode));
    });

    test('should not be equal when word lists differ', () {
      // Arrange
      final words1 = List.generate(12, (i) => 'word$i');
      final words2 = List.generate(12, (i) => 'different$i');
      final mnemonicWords1 = MnemonicWords(words1);
      final mnemonicWords2 = MnemonicWords(words2);

      // Act & Assert
      expect(mnemonicWords1, isNot(equals(mnemonicWords2)));
    });

    test('should not be equal when word counts differ', () {
      // Arrange
      final words12 = List.generate(12, (i) => 'word$i');
      final words24 = List.generate(24, (i) => 'word$i');
      final mnemonicWords12 = MnemonicWords(words12);
      final mnemonicWords24 = MnemonicWords(words24);

      // Act & Assert
      expect(mnemonicWords12, isNot(equals(mnemonicWords24)));
    });

    test('should not be equal when word order differs', () {
      // Arrange
      final words1 = ['word1', 'word2', 'word3', 'word4', 'word5', 'word6', 'word7', 'word8', 'word9', 'word10', 'word11', 'word12'];
      final words2 = ['word2', 'word1', 'word3', 'word4', 'word5', 'word6', 'word7', 'word8', 'word9', 'word10', 'word11', 'word12'];
      final mnemonicWords1 = MnemonicWords(words1);
      final mnemonicWords2 = MnemonicWords(words2);

      // Act & Assert
      expect(mnemonicWords1, isNot(equals(mnemonicWords2)));
    });

    test('should be equal to itself', () {
      // Arrange
      final words = List.generate(12, (i) => 'word$i');
      final mnemonicWords = MnemonicWords(words);

      // Act & Assert
      expect(mnemonicWords, equals(mnemonicWords));
    });

    test('should be case sensitive in equality', () {
      // Arrange
      final words1 = ['Word1', 'Word2', 'Word3', 'Word4', 'Word5', 'Word6', 'Word7', 'Word8', 'Word9', 'Word10', 'Word11', 'Word12'];
      final words2 = ['word1', 'word2', 'word3', 'word4', 'word5', 'word6', 'word7', 'word8', 'word9', 'word10', 'word11', 'word12'];
      final mnemonicWords1 = MnemonicWords(words1);
      final mnemonicWords2 = MnemonicWords(words2);

      // Act & Assert
      expect(mnemonicWords1, isNot(equals(mnemonicWords2)));
    });
  });

  group('MnemonicWords - Edge Cases', () {
    test('should handle words with special characters', () {
      // Arrange
      final words = List.generate(12, (i) => 'word-$i');

      // Act
      final mnemonicWords = MnemonicWords(words);

      // Assert
      expect(mnemonicWords.value, words);
    });

    test('should handle empty strings as words', () {
      // Arrange
      final words = List.generate(12, (i) => '');

      // Act
      final mnemonicWords = MnemonicWords(words);

      // Assert
      expect(mnemonicWords.value, words);
      expect(mnemonicWords.value.length, 12);
    });

    test('should handle very long word strings', () {
      // Arrange
      final words = List.generate(12, (i) => 'a' * 1000);

      // Act
      final mnemonicWords = MnemonicWords(words);

      // Assert
      expect(mnemonicWords.value, words);
      expect(mnemonicWords.value.length, 12);
    });

    test('should handle words with unicode characters', () {
      // Arrange
      final words = ['résumé', 'café', 'naïve', 'word4', 'word5', 'word6', 'word7', 'word8', 'word9', 'word10', 'word11', 'word12'];

      // Act
      final mnemonicWords = MnemonicWords(words);

      // Assert
      expect(mnemonicWords.value, words);
    });

    test('should handle duplicate words in the list', () {
      // Arrange
      final words = List.generate(12, (i) => 'same');

      // Act
      final mnemonicWords = MnemonicWords(words);

      // Assert
      expect(mnemonicWords.value, words);
      expect(mnemonicWords.value.length, 12);
    });
  });
}
