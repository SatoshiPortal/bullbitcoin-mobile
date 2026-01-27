import 'package:bb_mobile/features/secrets/domain/secrets_domain_error.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/seed_bytes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SeedBytes - Valid Cases', () {
    test('should create SeedBytes with 16 bytes (128 bits)', () {
      // Arrange
      final bytes = List.generate(16, (i) => i);

      // Act
      final seedBytes = SeedBytes(bytes);

      // Assert
      expect(seedBytes.value, bytes);
      expect(seedBytes.value.length, 16);
    });

    test('should create SeedBytes with 32 bytes (256 bits)', () {
      // Arrange
      final bytes = List.generate(32, (i) => i);

      // Act
      final seedBytes = SeedBytes(bytes);

      // Assert
      expect(seedBytes.value, bytes);
      expect(seedBytes.value.length, 32);
    });

    test('should create SeedBytes with 64 bytes (512 bits)', () {
      // Arrange
      final bytes = List.generate(64, (i) => i);

      // Act
      final seedBytes = SeedBytes(bytes);

      // Assert
      expect(seedBytes.value, bytes);
      expect(seedBytes.value.length, 64);
    });

    test('should create SeedBytes with all zeros', () {
      // Arrange
      final bytes = List.generate(32, (i) => 0);

      // Act
      final seedBytes = SeedBytes(bytes);

      // Assert
      expect(seedBytes.value, bytes);
      expect(seedBytes.value.every((b) => b == 0), isTrue);
    });

    test('should create SeedBytes with all 255s', () {
      // Arrange
      final bytes = List.generate(32, (i) => 255);

      // Act
      final seedBytes = SeedBytes(bytes);

      // Assert
      expect(seedBytes.value, bytes);
      expect(seedBytes.value.every((b) => b == 255), isTrue);
    });

    test('should create SeedBytes with random valid bytes', () {
      // Arrange
      final bytes = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16];

      // Act
      final seedBytes = SeedBytes(bytes);

      // Assert
      expect(seedBytes.value, bytes);
    });

    test('should create immutable list of bytes', () {
      // Arrange
      final bytes = List.generate(16, (i) => i);
      final seedBytes = SeedBytes(bytes);

      // Act & Assert
      expect(
        () => seedBytes.value.add(99),
        throwsUnsupportedError,
        reason: 'Should not be able to modify the byte list',
      );
    });

    test('should not be affected by changes to original list', () {
      // Arrange
      final bytes = List.generate(16, (i) => i);
      final seedBytes = SeedBytes(bytes);

      // Act
      bytes[0] = 99;

      // Assert
      expect(seedBytes.value[0], 0);
      expect(seedBytes.value[0], isNot(99));
    });
  });

  group('SeedBytes - Invalid Length', () {
    test('should throw InvalidSeedBytesLengthError for empty list', () {
      // Arrange
      final emptyBytes = <int>[];

      // Act & Assert
      expect(
        () => SeedBytes(emptyBytes),
        throwsA(
          isA<InvalidSeedBytesLengthError>()
              .having(
                (e) => e.message,
                'message',
                contains('cannot be empty'),
              )
              .having(
                (e) => e.actualLength,
                'actualLength',
                0,
              ),
        ),
      );
    });

    test('should throw InvalidSeedBytesLengthError for 15 bytes', () {
      // Arrange
      final bytes = List.generate(15, (i) => i);

      // Act & Assert
      expect(
        () => SeedBytes(bytes),
        throwsA(
          isA<InvalidSeedBytesLengthError>()
              .having(
                (e) => e.message,
                'message',
                contains('must be 16, 32, or 64 bytes'),
              )
              .having(
                (e) => e.actualLength,
                'actualLength',
                15,
              ),
        ),
      );
    });

    test('should throw InvalidSeedBytesLengthError for 17 bytes', () {
      // Arrange
      final bytes = List.generate(17, (i) => i);

      // Act & Assert
      expect(
        () => SeedBytes(bytes),
        throwsA(
          isA<InvalidSeedBytesLengthError>()
              .having(
                (e) => e.message,
                'message',
                contains('Got 17 bytes'),
              )
              .having(
                (e) => e.actualLength,
                'actualLength',
                17,
              ),
        ),
      );
    });

    test('should throw InvalidSeedBytesLengthError for 31 bytes', () {
      // Arrange
      final bytes = List.generate(31, (i) => i);

      // Act & Assert
      expect(
        () => SeedBytes(bytes),
        throwsA(
          isA<InvalidSeedBytesLengthError>().having(
            (e) => e.actualLength,
            'actualLength',
            31,
          ),
        ),
      );
    });

    test('should throw InvalidSeedBytesLengthError for 33 bytes', () {
      // Arrange
      final bytes = List.generate(33, (i) => i);

      // Act & Assert
      expect(
        () => SeedBytes(bytes),
        throwsA(
          isA<InvalidSeedBytesLengthError>().having(
            (e) => e.actualLength,
            'actualLength',
            33,
          ),
        ),
      );
    });

    test('should throw InvalidSeedBytesLengthError for 63 bytes', () {
      // Arrange
      final bytes = List.generate(63, (i) => i);

      // Act & Assert
      expect(
        () => SeedBytes(bytes),
        throwsA(
          isA<InvalidSeedBytesLengthError>().having(
            (e) => e.actualLength,
            'actualLength',
            63,
          ),
        ),
      );
    });

    test('should throw InvalidSeedBytesLengthError for 65 bytes', () {
      // Arrange
      final bytes = List.generate(65, (i) => i);

      // Act & Assert
      expect(
        () => SeedBytes(bytes),
        throwsA(
          isA<InvalidSeedBytesLengthError>().having(
            (e) => e.actualLength,
            'actualLength',
            65,
          ),
        ),
      );
    });

    test('should throw InvalidSeedBytesLengthError for 1 byte', () {
      // Arrange
      final bytes = [1];

      // Act & Assert
      expect(
        () => SeedBytes(bytes),
        throwsA(
          isA<InvalidSeedBytesLengthError>().having(
            (e) => e.actualLength,
            'actualLength',
            1,
          ),
        ),
      );
    });

    test('should throw InvalidSeedBytesLengthError for 8 bytes', () {
      // Arrange
      final bytes = List.generate(8, (i) => i);

      // Act & Assert
      expect(
        () => SeedBytes(bytes),
        throwsA(
          isA<InvalidSeedBytesLengthError>().having(
            (e) => e.actualLength,
            'actualLength',
            8,
          ),
        ),
      );
    });

    test('should throw InvalidSeedBytesLengthError for 24 bytes', () {
      // Arrange
      final bytes = List.generate(24, (i) => i);

      // Act & Assert
      expect(
        () => SeedBytes(bytes),
        throwsA(
          isA<InvalidSeedBytesLengthError>().having(
            (e) => e.actualLength,
            'actualLength',
            24,
          ),
        ),
      );
    });

    test('should throw InvalidSeedBytesLengthError for 48 bytes', () {
      // Arrange
      final bytes = List.generate(48, (i) => i);

      // Act & Assert
      expect(
        () => SeedBytes(bytes),
        throwsA(
          isA<InvalidSeedBytesLengthError>().having(
            (e) => e.actualLength,
            'actualLength',
            48,
          ),
        ),
      );
    });

    test('should throw InvalidSeedBytesLengthError for 100 bytes', () {
      // Arrange
      final bytes = List.generate(100, (i) => i);

      // Act & Assert
      expect(
        () => SeedBytes(bytes),
        throwsA(
          isA<InvalidSeedBytesLengthError>().having(
            (e) => e.actualLength,
            'actualLength',
            100,
          ),
        ),
      );
    });

    test('should include valid lengths in error message', () {
      // Arrange
      final bytes = List.generate(20, (i) => i);

      // Act & Assert
      expect(
        () => SeedBytes(bytes),
        throwsA(
          isA<InvalidSeedBytesLengthError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('16'),
              contains('32'),
              contains('64'),
            ),
          ),
        ),
      );
    });
  });

  group('SeedBytes - Equality', () {
    test('should be equal when byte lists are identical', () {
      // Arrange
      final bytes1 = List.generate(16, (i) => i);
      final bytes2 = List.generate(16, (i) => i);
      final seedBytes1 = SeedBytes(bytes1);
      final seedBytes2 = SeedBytes(bytes2);

      // Act & Assert
      expect(seedBytes1, equals(seedBytes2));
      expect(seedBytes1.hashCode, equals(seedBytes2.hashCode));
    });

    test('should not be equal when byte lists differ', () {
      // Arrange
      final bytes1 = List.generate(16, (i) => i);
      final bytes2 = List.generate(16, (i) => i + 1);
      final seedBytes1 = SeedBytes(bytes1);
      final seedBytes2 = SeedBytes(bytes2);

      // Act & Assert
      expect(seedBytes1, isNot(equals(seedBytes2)));
    });

    test('should not be equal when byte lengths differ', () {
      // Arrange
      final bytes16 = List.generate(16, (i) => i);
      final bytes32 = List.generate(32, (i) => i);
      final seedBytes16 = SeedBytes(bytes16);
      final seedBytes32 = SeedBytes(bytes32);

      // Act & Assert
      expect(seedBytes16, isNot(equals(seedBytes32)));
    });

    test('should not be equal when single byte differs', () {
      // Arrange
      final bytes1 = List.generate(16, (i) => i);
      final bytes2 = List.generate(16, (i) => i);
      bytes2[5] = 99; // Change one byte
      final seedBytes1 = SeedBytes(bytes1);
      final seedBytes2 = SeedBytes(bytes2);

      // Act & Assert
      expect(seedBytes1, isNot(equals(seedBytes2)));
    });

    test('should be equal to itself', () {
      // Arrange
      final bytes = List.generate(32, (i) => i);
      final seedBytes = SeedBytes(bytes);

      // Act & Assert
      expect(seedBytes, equals(seedBytes));
    });

    test('should be equal when both have same zeros', () {
      // Arrange
      final bytes1 = List.generate(16, (i) => 0);
      final bytes2 = List.generate(16, (i) => 0);
      final seedBytes1 = SeedBytes(bytes1);
      final seedBytes2 = SeedBytes(bytes2);

      // Act & Assert
      expect(seedBytes1, equals(seedBytes2));
      expect(seedBytes1.hashCode, equals(seedBytes2.hashCode));
    });
  });

  group('SeedBytes - Edge Cases', () {
    test('should handle bytes with all minimum values (0)', () {
      // Arrange
      final bytes = List.generate(16, (i) => 0);

      // Act
      final seedBytes = SeedBytes(bytes);

      // Assert
      expect(seedBytes.value, bytes);
      expect(seedBytes.value.every((b) => b == 0), isTrue);
    });

    test('should handle bytes with all maximum values (255)', () {
      // Arrange
      final bytes = List.generate(16, (i) => 255);

      // Act
      final seedBytes = SeedBytes(bytes);

      // Assert
      expect(seedBytes.value, bytes);
      expect(seedBytes.value.every((b) => b == 255), isTrue);
    });

    test('should handle alternating byte values', () {
      // Arrange
      final bytes = List.generate(16, (i) => i % 2 == 0 ? 0 : 255);

      // Act
      final seedBytes = SeedBytes(bytes);

      // Assert
      expect(seedBytes.value, bytes);
    });

    test('should handle sequential byte values', () {
      // Arrange
      final bytes = List.generate(32, (i) => i);

      // Act
      final seedBytes = SeedBytes(bytes);

      // Assert
      expect(seedBytes.value, bytes);
      for (int i = 0; i < 32; i++) {
        expect(seedBytes.value[i], i);
      }
    });

    test('should handle random-looking byte patterns', () {
      // Arrange
      final bytes = [
        0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE, 0xBA, 0xBE,
        0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC, 0xDE, 0xF0,
      ];

      // Act
      final seedBytes = SeedBytes(bytes);

      // Assert
      expect(seedBytes.value, bytes);
    });
  });

  group('SeedBytes - Boundary Tests', () {
    test('should accept exactly 16 bytes', () {
      // Arrange
      final bytes = List.generate(16, (i) => i);

      // Act
      final seedBytes = SeedBytes(bytes);

      // Assert
      expect(seedBytes.value.length, 16);
    });

    test('should accept exactly 32 bytes', () {
      // Arrange
      final bytes = List.generate(32, (i) => i);

      // Act
      final seedBytes = SeedBytes(bytes);

      // Assert
      expect(seedBytes.value.length, 32);
    });

    test('should accept exactly 64 bytes', () {
      // Arrange
      final bytes = List.generate(64, (i) => i);

      // Act
      final seedBytes = SeedBytes(bytes);

      // Assert
      expect(seedBytes.value.length, 64);
    });

    test('should reject 16 - 1 bytes', () {
      // Arrange
      final bytes = List.generate(15, (i) => i);

      // Act & Assert
      expect(
        () => SeedBytes(bytes),
        throwsA(isA<InvalidSeedBytesLengthError>()),
      );
    });

    test('should reject 16 + 1 bytes', () {
      // Arrange
      final bytes = List.generate(17, (i) => i);

      // Act & Assert
      expect(
        () => SeedBytes(bytes),
        throwsA(isA<InvalidSeedBytesLengthError>()),
      );
    });

    test('should reject 32 - 1 bytes', () {
      // Arrange
      final bytes = List.generate(31, (i) => i);

      // Act & Assert
      expect(
        () => SeedBytes(bytes),
        throwsA(isA<InvalidSeedBytesLengthError>()),
      );
    });

    test('should reject 32 + 1 bytes', () {
      // Arrange
      final bytes = List.generate(33, (i) => i);

      // Act & Assert
      expect(
        () => SeedBytes(bytes),
        throwsA(isA<InvalidSeedBytesLengthError>()),
      );
    });

    test('should reject 64 - 1 bytes', () {
      // Arrange
      final bytes = List.generate(63, (i) => i);

      // Act & Assert
      expect(
        () => SeedBytes(bytes),
        throwsA(isA<InvalidSeedBytesLengthError>()),
      );
    });

    test('should reject 64 + 1 bytes', () {
      // Arrange
      final bytes = List.generate(65, (i) => i);

      // Act & Assert
      expect(
        () => SeedBytes(bytes),
        throwsA(isA<InvalidSeedBytesLengthError>()),
      );
    });
  });

  group('SeedBytes - Immutability', () {
    test('should prevent modification of internal list', () {
      // Arrange
      final bytes = List.generate(16, (i) => i);
      final seedBytes = SeedBytes(bytes);

      // Act & Assert
      expect(
        () => seedBytes.value[0] = 99,
        throwsUnsupportedError,
        reason: 'Should not be able to modify the internal list',
      );
    });

    test('should prevent adding to internal list', () {
      // Arrange
      final bytes = List.generate(16, (i) => i);
      final seedBytes = SeedBytes(bytes);

      // Act & Assert
      expect(
        () => seedBytes.value.add(99),
        throwsUnsupportedError,
        reason: 'Should not be able to add to the internal list',
      );
    });

    test('should prevent removing from internal list', () {
      // Arrange
      final bytes = List.generate(16, (i) => i);
      final seedBytes = SeedBytes(bytes);

      // Act & Assert
      expect(
        () => seedBytes.value.removeAt(0),
        throwsUnsupportedError,
        reason: 'Should not be able to remove from the internal list',
      );
    });

    test('should not be affected by external list modifications', () {
      // Arrange
      final bytes = List.generate(16, (i) => i);
      final seedBytes = SeedBytes(bytes);
      final originalFirstByte = seedBytes.value[0];

      // Act
      bytes[0] = 99;
      bytes.add(100);

      // Assert
      expect(seedBytes.value.length, 16);
      expect(seedBytes.value[0], originalFirstByte);
      expect(seedBytes.value[0], isNot(99));
    });
  });
}
