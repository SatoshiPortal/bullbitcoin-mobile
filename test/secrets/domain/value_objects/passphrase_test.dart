import 'package:bb_mobile/features/secrets/domain/secrets_domain_error.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/passphrase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Passphrase - Valid Cases', () {
    test('should create Passphrase with empty string', () {
      // Arrange
      const emptyPassphrase = '';

      // Act
      final passphrase = Passphrase(emptyPassphrase);

      // Assert
      expect(passphrase.value, emptyPassphrase);
    });

    test('should create empty Passphrase using factory', () {
      // Act
      final passphrase = Passphrase.empty();

      // Assert
      expect(passphrase.value, '');
    });

    test('should create Passphrase with single character', () {
      // Arrange
      const singleChar = 'a';

      // Act
      final passphrase = Passphrase(singleChar);

      // Assert
      expect(passphrase.value, singleChar);
    });

    test('should create Passphrase with short string', () {
      // Arrange
      const shortPassphrase = 'password123';

      // Act
      final passphrase = Passphrase(shortPassphrase);

      // Assert
      expect(passphrase.value, shortPassphrase);
    });

    test('should create Passphrase with medium length string', () {
      // Arrange
      const mediumPassphrase = 'This is a longer passphrase with spaces and numbers 123!';

      // Act
      final passphrase = Passphrase(mediumPassphrase);

      // Assert
      expect(passphrase.value, mediumPassphrase);
    });

    test('should create Passphrase with exactly 256 characters', () {
      // Arrange
      final maxLengthPassphrase = 'a' * 256;

      // Act
      final passphrase = Passphrase(maxLengthPassphrase);

      // Assert
      expect(passphrase.value, maxLengthPassphrase);
      expect(passphrase.value.length, 256);
    });

    test('should create Passphrase with 255 characters', () {
      // Arrange
      final nearMaxPassphrase = 'a' * 255;

      // Act
      final passphrase = Passphrase(nearMaxPassphrase);

      // Assert
      expect(passphrase.value, nearMaxPassphrase);
      expect(passphrase.value.length, 255);
    });

    test('should create Passphrase with special characters', () {
      // Arrange
      const specialChars = '!@#\$%^&*()_+-=[]{}|;:\'",.<>?/~`';

      // Act
      final passphrase = Passphrase(specialChars);

      // Assert
      expect(passphrase.value, specialChars);
    });

    test('should create Passphrase with unicode characters', () {
      // Arrange
      const unicodePassphrase = 'résumé café naïve 日本語 中文';

      // Act
      final passphrase = Passphrase(unicodePassphrase);

      // Assert
      expect(passphrase.value, unicodePassphrase);
    });

    test('should create Passphrase with newlines and tabs', () {
      // Arrange
      const passphraseWithWhitespace = 'line1\nline2\ttab';

      // Act
      final passphrase = Passphrase(passphraseWithWhitespace);

      // Assert
      expect(passphrase.value, passphraseWithWhitespace);
    });

    test('should create Passphrase with emojis', () {
      // Arrange
      const emojiPassphrase = 'password🔐🔑🗝️';

      // Act
      final passphrase = Passphrase(emojiPassphrase);

      // Assert
      expect(passphrase.value, emojiPassphrase);
    });
  });

  group('Passphrase - Invalid Cases', () {
    test('should throw InvalidPassphraseLengthError when exceeding 256 characters', () {
      // Arrange
      final tooLongPassphrase = 'a' * 257;

      // Act & Assert
      expect(
        () => Passphrase(tooLongPassphrase),
        throwsA(
          isA<InvalidPassphraseLengthError>()
              .having(
                (e) => e.message,
                'message',
                contains('cannot exceed 256 characters'),
              )
              .having(
                (e) => e.actualLength,
                'actualLength',
                257,
              ),
        ),
      );
    });

    test('should throw InvalidPassphraseLengthError for 300 characters', () {
      // Arrange
      final tooLongPassphrase = 'a' * 300;

      // Act & Assert
      expect(
        () => Passphrase(tooLongPassphrase),
        throwsA(
          isA<InvalidPassphraseLengthError>()
              .having(
                (e) => e.message,
                'message',
                contains('Got 300 characters'),
              )
              .having(
                (e) => e.actualLength,
                'actualLength',
                300,
              ),
        ),
      );
    });

    test('should throw InvalidPassphraseLengthError for 500 characters', () {
      // Arrange
      final tooLongPassphrase = 'a' * 500;

      // Act & Assert
      expect(
        () => Passphrase(tooLongPassphrase),
        throwsA(
          isA<InvalidPassphraseLengthError>().having(
            (e) => e.actualLength,
            'actualLength',
            500,
          ),
        ),
      );
    });

    test('should throw InvalidPassphraseLengthError for 1000 characters', () {
      // Arrange
      final tooLongPassphrase = 'a' * 1000;

      // Act & Assert
      expect(
        () => Passphrase(tooLongPassphrase),
        throwsA(
          isA<InvalidPassphraseLengthError>().having(
            (e) => e.actualLength,
            'actualLength',
            1000,
          ),
        ),
      );
    });

    test('should include actual length in error message', () {
      // Arrange
      final tooLongPassphrase = 'a' * 1000;

      // Act & Assert
      expect(
        () => Passphrase(tooLongPassphrase),
        throwsA(
          isA<InvalidPassphraseLengthError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('1000'),
              contains('256'),
            ),
          ),
        ),
      );
    });
  });

  group('Passphrase - Equality', () {
    test('should be equal when values are the same', () {
      // Arrange
      const value = 'same-passphrase';
      final passphrase1 = Passphrase(value);
      final passphrase2 = Passphrase(value);

      // Act & Assert
      expect(passphrase1, equals(passphrase2));
      expect(passphrase1.hashCode, equals(passphrase2.hashCode));
    });

    test('should be equal when both are empty', () {
      // Arrange
      final passphrase1 = Passphrase.empty();
      final passphrase2 = Passphrase('');

      // Act & Assert
      expect(passphrase1, equals(passphrase2));
      expect(passphrase1.hashCode, equals(passphrase2.hashCode));
    });

    test('should not be equal when values differ', () {
      // Arrange
      final passphrase1 = Passphrase('passphrase1');
      final passphrase2 = Passphrase('passphrase2');

      // Act & Assert
      expect(passphrase1, isNot(equals(passphrase2)));
    });

    test('should be case sensitive', () {
      // Arrange
      final passphrase1 = Passphrase('Password');
      final passphrase2 = Passphrase('password');

      // Act & Assert
      expect(passphrase1, isNot(equals(passphrase2)));
    });

    test('should be sensitive to whitespace', () {
      // Arrange
      final passphrase1 = Passphrase('password');
      final passphrase2 = Passphrase('password ');

      // Act & Assert
      expect(passphrase1, isNot(equals(passphrase2)));
    });

    test('should be equal to itself', () {
      // Arrange
      final passphrase = Passphrase('test-passphrase');

      // Act & Assert
      expect(passphrase, equals(passphrase));
    });

    test('should not be equal to empty when it has value', () {
      // Arrange
      final passphrase = Passphrase('not-empty');
      final emptyPassphrase = Passphrase.empty();

      // Act & Assert
      expect(passphrase, isNot(equals(emptyPassphrase)));
    });
  });

  group('Passphrase - Factory Methods', () {
    test('should create const empty Passphrase', () {
      // Act
      final passphrase1 = Passphrase.empty();
      final passphrase2 = Passphrase.empty();

      // Assert
      expect(passphrase1, equals(passphrase2));
      expect(passphrase1.value, '');
    });

    test('should create Passphrase from regular constructor', () {
      // Arrange
      const value = 'regular-passphrase';

      // Act
      final passphrase = Passphrase(value);

      // Assert
      expect(passphrase.value, value);
    });
  });

  group('Passphrase - Boundary Tests', () {
    test('should accept passphrase at max length boundary', () {
      // Arrange
      final maxPassphrase = 'a' * 256;

      // Act
      final passphrase = Passphrase(maxPassphrase);

      // Assert
      expect(passphrase.value.length, 256);
    });

    test('should reject passphrase just over max length boundary', () {
      // Arrange
      final tooLongPassphrase = 'a' * 257;

      // Act & Assert
      expect(
        () => Passphrase(tooLongPassphrase),
        throwsA(isA<InvalidPassphraseLengthError>()),
      );
    });

    test('should accept passphrase just under max length boundary', () {
      // Arrange
      final justUnderMax = 'a' * 255;

      // Act
      final passphrase = Passphrase(justUnderMax);

      // Assert
      expect(passphrase.value.length, 255);
    });
  });

  group('Passphrase - Edge Cases', () {
    test('should handle passphrase with only spaces', () {
      // Arrange
      const spacesOnly = '     ';

      // Act
      final passphrase = Passphrase(spacesOnly);

      // Assert
      expect(passphrase.value, spacesOnly);
    });

    test('should handle passphrase with mixed whitespace', () {
      // Arrange
      const mixedWhitespace = ' \t\n\r ';

      // Act
      final passphrase = Passphrase(mixedWhitespace);

      // Assert
      expect(passphrase.value, mixedWhitespace);
    });

    test('should handle passphrase with null character', () {
      // Arrange
      const passphraseWithNull = 'pass\x00word';

      // Act
      final passphrase = Passphrase(passphraseWithNull);

      // Assert
      expect(passphrase.value, passphraseWithNull);
    });

    test('should handle passphrase with repeated characters', () {
      // Arrange
      final repeatedChars = 'a' * 100;

      // Act
      final passphrase = Passphrase(repeatedChars);

      // Assert
      expect(passphrase.value, repeatedChars);
      expect(passphrase.value.length, 100);
    });
  });

  group('Passphrase - Immutability', () {
    test('should maintain immutability of value', () {
      // Arrange
      const originalValue = 'immutable';
      final passphrase = Passphrase(originalValue);

      // Act - attempt to get value
      final retrievedValue = passphrase.value;

      // Assert
      expect(retrievedValue, originalValue);
      expect(passphrase.value, originalValue);
    });

    test('should create multiple independent instances', () {
      // Arrange
      final passphrase1 = Passphrase('first');
      final passphrase2 = Passphrase('second');
      final passphrase3 = Passphrase('first');

      // Act & Assert
      expect(passphrase1, equals(passphrase3));
      expect(passphrase1, isNot(equals(passphrase2)));
      expect(passphrase2, isNot(equals(passphrase3)));
    });
  });
}
