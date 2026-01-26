import 'package:bb_mobile/features/secrets/domain/secrets_domain_error.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/fingerprint.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Fingerprint - Valid Cases', () {
    test('should create fingerprint with valid 8 hex character string', () {
      // Arrange
      const validHex = '12345678';

      // Act
      final fingerprint = Fingerprint.fromHex(validHex);

      // Assert
      expect(fingerprint.value, '12345678');
    });

    test('should normalize uppercase hex to lowercase', () {
      // Arrange
      const uppercaseHex = 'ABCDEF12';

      // Act
      final fingerprint = Fingerprint.fromHex(uppercaseHex);

      // Assert
      expect(fingerprint.value, 'abcdef12');
    });

    test('should normalize mixed case hex to lowercase', () {
      // Arrange
      const mixedCaseHex = 'AbCdEf12';

      // Act
      final fingerprint = Fingerprint.fromHex(mixedCaseHex);

      // Assert
      expect(fingerprint.value, 'abcdef12');
    });

    test('should accept all valid hex characters (0-9, a-f, A-F)', () {
      // Arrange
      const allValidChars = '0123456789abcdefABCDEF';
      final validHexStrings = [
        '01234567',
        '89abcdef',
        'ABCDEF01',
        'aAbBcCdD',
        'f0f1f2f3',
      ];

      // Act & Assert
      for (final hexString in validHexStrings) {
        expect(
          () => Fingerprint.fromHex(hexString),
          returnsNormally,
          reason: 'Should accept valid hex string: $hexString',
        );
      }
    });
  });

  group('Fingerprint - Invalid Length', () {
    test('should throw InvalidFingerprintFormatError when hex is too short', () {
      // Arrange
      const tooShortHex = '1234567'; // 7 characters

      // Act & Assert
      expect(
        () => Fingerprint.fromHex(tooShortHex),
        throwsA(
          isA<InvalidFingerprintFormatError>()
              .having(
                (e) => e.message,
                'message',
                contains('must be 8 hex characters'),
              )
              .having(
                (e) => e.invalidValue,
                'invalidValue',
                tooShortHex,
              ),
        ),
      );
    });

    test('should throw InvalidFingerprintFormatError when hex is too long', () {
      // Arrange
      const tooLongHex = '123456789'; // 9 characters

      // Act & Assert
      expect(
        () => Fingerprint.fromHex(tooLongHex),
        throwsA(
          isA<InvalidFingerprintFormatError>()
              .having(
                (e) => e.message,
                'message',
                contains('must be 8 hex characters'),
              )
              .having(
                (e) => e.invalidValue,
                'invalidValue',
                tooLongHex,
              ),
        ),
      );
    });

    test('should throw InvalidFingerprintFormatError when hex is empty', () {
      // Arrange
      const emptyHex = '';

      // Act & Assert
      expect(
        () => Fingerprint.fromHex(emptyHex),
        throwsA(
          isA<InvalidFingerprintFormatError>()
              .having(
                (e) => e.invalidValue,
                'invalidValue',
                emptyHex,
              ),
        ),
      );
    });

    test('should throw InvalidFingerprintFormatError for various invalid lengths', () {
      // Arrange
      final invalidLengths = [
        '1', // 1 character
        '12', // 2 characters
        '123', // 3 characters
        '1234', // 4 characters
        '12345', // 5 characters
        '123456', // 6 characters
        '1234567', // 7 characters
        '123456789', // 9 characters
        '1234567890', // 10 characters
        '12345678901234567890', // 20 characters
      ];

      // Act & Assert
      for (final invalidHex in invalidLengths) {
        expect(
          () => Fingerprint.fromHex(invalidHex),
          throwsA(isA<InvalidFingerprintFormatError>()),
          reason: 'Should reject hex with ${invalidHex.length} characters',
        );
      }
    });
  });

  group('Fingerprint - Invalid Characters', () {
    test('should throw InvalidFingerprintFormatError for non-hex characters', () {
      // Arrange
      const invalidHex = '1234567g'; // 'g' is not a hex character

      // Act & Assert
      expect(
        () => Fingerprint.fromHex(invalidHex),
        throwsA(
          isA<InvalidFingerprintFormatError>()
              .having(
                (e) => e.message,
                'message',
                contains('must be valid hex string'),
              )
              .having(
                (e) => e.invalidValue,
                'invalidValue',
                invalidHex,
              ),
        ),
      );
    });

    test('should throw InvalidFingerprintFormatError for special characters', () {
      // Arrange
      final invalidHexStrings = [
        '1234567!', // exclamation mark
        '1234567@', // at sign
        '1234567#', // hash
        '1234567\$', // dollar sign
        '1234567%', // percent
        '1234567^', // caret
        '1234567&', // ampersand
        '1234567*', // asterisk
        '1234567-', // dash
        '1234567_', // underscore
        '1234567+', // plus
        '1234567=', // equals
        '1234567 ', // space
      ];

      // Act & Assert
      for (final invalidHex in invalidHexStrings) {
        expect(
          () => Fingerprint.fromHex(invalidHex),
          throwsA(isA<InvalidFingerprintFormatError>()),
          reason: 'Should reject hex with special character: $invalidHex',
        );
      }
    });

    test('should throw InvalidFingerprintFormatError for letters beyond f', () {
      // Arrange
      final invalidHexStrings = [
        '1234567g',
        '1234567z',
        'hijklmno',
        'pqrstuvw',
        'GHIJKLMN',
      ];

      // Act & Assert
      for (final invalidHex in invalidHexStrings) {
        expect(
          () => Fingerprint.fromHex(invalidHex),
          throwsA(isA<InvalidFingerprintFormatError>()),
          reason: 'Should reject hex with non-hex letter: $invalidHex',
        );
      }
    });
  });

  group('Fingerprint - Equality', () {
    test('should be equal when values are the same', () {
      // Arrange
      final fingerprint1 = Fingerprint.fromHex('12345678');
      final fingerprint2 = Fingerprint.fromHex('12345678');

      // Act & Assert
      expect(fingerprint1, equals(fingerprint2));
      expect(fingerprint1.hashCode, equals(fingerprint2.hashCode));
    });

    test('should be equal after case normalization', () {
      // Arrange
      final fingerprint1 = Fingerprint.fromHex('abcdef12');
      final fingerprint2 = Fingerprint.fromHex('ABCDEF12');

      // Act & Assert
      expect(fingerprint1, equals(fingerprint2));
      expect(fingerprint1.hashCode, equals(fingerprint2.hashCode));
    });

    test('should not be equal when values are different', () {
      // Arrange
      final fingerprint1 = Fingerprint.fromHex('12345678');
      final fingerprint2 = Fingerprint.fromHex('87654321');

      // Act & Assert
      expect(fingerprint1, isNot(equals(fingerprint2)));
    });

    test('should be equal to itself', () {
      // Arrange
      final fingerprint = Fingerprint.fromHex('12345678');

      // Act & Assert
      expect(fingerprint, equals(fingerprint));
    });
  });

  group('Fingerprint - toString', () {
    test('should return formatted string representation', () {
      // Arrange
      final fingerprint = Fingerprint.fromHex('12345678');

      // Act
      final result = fingerprint.toString();

      // Assert
      expect(result, 'Fingerprint(12345678)');
    });

    test('should return lowercase hex in string representation', () {
      // Arrange
      final fingerprint = Fingerprint.fromHex('ABCDEF12');

      // Act
      final result = fingerprint.toString();

      // Assert
      expect(result, 'Fingerprint(abcdef12)');
    });
  });

  group('Fingerprint - Direct Constructor', () {
    test('should allow direct construction with const constructor', () {
      // Arrange & Act
      const fingerprint = Fingerprint('12345678');

      // Assert
      expect(fingerprint.value, '12345678');
    });

    test('should create equal fingerprints with direct constructor', () {
      // Arrange
      const fingerprint1 = Fingerprint('12345678');
      const fingerprint2 = Fingerprint('12345678');

      // Act & Assert
      expect(fingerprint1, equals(fingerprint2));
    });
  });
}
