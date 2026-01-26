import 'package:bb_mobile/features/secrets/domain/value_objects/secret_usage_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SecretUsageId - Creation', () {
    test('should create SecretUsageId with positive integer', () {
      // Arrange
      const id = 123;

      // Act
      final secretUsageId = SecretUsageId(id);

      // Assert
      expect(secretUsageId.value, id);
    });

    test('should create SecretUsageId with zero', () {
      // Arrange
      const id = 0;

      // Act
      final secretUsageId = SecretUsageId(id);

      // Assert
      expect(secretUsageId.value, id);
    });

    test('should create SecretUsageId with negative integer', () {
      // Arrange
      const id = -1;

      // Act
      final secretUsageId = SecretUsageId(id);

      // Assert
      expect(secretUsageId.value, id);
    });

    test('should create SecretUsageId with large positive integer', () {
      // Arrange
      const id = 999999999;

      // Act
      final secretUsageId = SecretUsageId(id);

      // Assert
      expect(secretUsageId.value, id);
    });

    test('should create SecretUsageId with large negative integer', () {
      // Arrange
      const id = -999999999;

      // Act
      final secretUsageId = SecretUsageId(id);

      // Assert
      expect(secretUsageId.value, id);
    });

    test('should create SecretUsageId with typical database ID values', () {
      // Arrange
      final ids = [1, 2, 3, 100, 1000, 10000];

      // Act & Assert
      for (final id in ids) {
        final secretUsageId = SecretUsageId(id);
        expect(secretUsageId.value, id);
      }
    });
  });

  group('SecretUsageId - Equality', () {
    test('should be equal when values are the same', () {
      // Arrange
      const id = 123;
      final secretUsageId1 = SecretUsageId(id);
      final secretUsageId2 = SecretUsageId(id);

      // Act & Assert
      expect(secretUsageId1, equals(secretUsageId2));
      expect(secretUsageId1.hashCode, equals(secretUsageId2.hashCode));
    });

    test('should not be equal when values differ', () {
      // Arrange
      final secretUsageId1 = SecretUsageId(123);
      final secretUsageId2 = SecretUsageId(456);

      // Act & Assert
      expect(secretUsageId1, isNot(equals(secretUsageId2)));
    });

    test('should be equal when both have zero value', () {
      // Arrange
      final secretUsageId1 = SecretUsageId(0);
      final secretUsageId2 = SecretUsageId(0);

      // Act & Assert
      expect(secretUsageId1, equals(secretUsageId2));
      expect(secretUsageId1.hashCode, equals(secretUsageId2.hashCode));
    });

    test('should be equal when both have negative value', () {
      // Arrange
      final secretUsageId1 = SecretUsageId(-5);
      final secretUsageId2 = SecretUsageId(-5);

      // Act & Assert
      expect(secretUsageId1, equals(secretUsageId2));
      expect(secretUsageId1.hashCode, equals(secretUsageId2.hashCode));
    });

    test('should not be equal when signs differ', () {
      // Arrange
      final secretUsageId1 = SecretUsageId(5);
      final secretUsageId2 = SecretUsageId(-5);

      // Act & Assert
      expect(secretUsageId1, isNot(equals(secretUsageId2)));
    });

    test('should be equal to itself', () {
      // Arrange
      final secretUsageId = SecretUsageId(123);

      // Act & Assert
      expect(secretUsageId, equals(secretUsageId));
    });

    test('should not be equal to null', () {
      // Arrange
      final secretUsageId = SecretUsageId(123);

      // Act & Assert
      expect(secretUsageId, isNot(equals(null)));
    });

    test('should have consistent hashCode for equal values', () {
      // Arrange
      final ids = [0, 1, 100, 1000, -1, -100];

      // Act & Assert
      for (final id in ids) {
        final secretUsageId1 = SecretUsageId(id);
        final secretUsageId2 = SecretUsageId(id);
        expect(secretUsageId1.hashCode, equals(secretUsageId2.hashCode));
      }
    });
  });

  group('SecretUsageId - toString', () {
    test('should return formatted string representation', () {
      // Arrange
      const id = 123;
      final secretUsageId = SecretUsageId(id);

      // Act
      final result = secretUsageId.toString();

      // Assert
      expect(result, 'SecretUsageId(123)');
    });

    test('should include ID value in string representation', () {
      // Arrange
      const id = 456;
      final secretUsageId = SecretUsageId(id);

      // Act
      final result = secretUsageId.toString();

      // Assert
      expect(result, contains('456'));
      expect(result, 'SecretUsageId(456)');
    });

    test('should handle zero in toString', () {
      // Arrange
      final secretUsageId = SecretUsageId(0);

      // Act
      final result = secretUsageId.toString();

      // Assert
      expect(result, 'SecretUsageId(0)');
    });

    test('should handle negative values in toString', () {
      // Arrange
      final secretUsageId = SecretUsageId(-123);

      // Act
      final result = secretUsageId.toString();

      // Assert
      expect(result, 'SecretUsageId(-123)');
    });

    test('should handle large numbers in toString', () {
      // Arrange
      final secretUsageId = SecretUsageId(999999999);

      // Act
      final result = secretUsageId.toString();

      // Assert
      expect(result, 'SecretUsageId(999999999)');
    });
  });

  group('SecretUsageId - Edge Cases', () {
    test('should handle maximum positive integer value', () {
      // Arrange
      // Dart ints are 64-bit signed integers
      // Max value is 2^63 - 1 = 9223372036854775807
      const maxInt = 9223372036854775807;

      // Act
      final secretUsageId = SecretUsageId(maxInt);

      // Assert
      expect(secretUsageId.value, maxInt);
    });

    test('should handle minimum negative integer value', () {
      // Arrange
      // Min value is -2^63 = -9223372036854775808
      const minInt = -9223372036854775808;

      // Act
      final secretUsageId = SecretUsageId(minInt);

      // Assert
      expect(secretUsageId.value, minInt);
    });

    test('should handle sequential IDs', () {
      // Arrange
      final ids = List.generate(100, (i) => i);

      // Act & Assert
      for (final id in ids) {
        final secretUsageId = SecretUsageId(id);
        expect(secretUsageId.value, id);
      }
    });

    test('should handle non-sequential IDs', () {
      // Arrange
      final ids = [1, 5, 17, 42, 99, 1000, 5000];

      // Act & Assert
      for (final id in ids) {
        final secretUsageId = SecretUsageId(id);
        expect(secretUsageId.value, id);
      }
    });
  });

  group('SecretUsageId - Const Constructor', () {
    test('should create const SecretUsageId instances', () {
      // Arrange & Act
      const secretUsageId1 = SecretUsageId(123);
      const secretUsageId2 = SecretUsageId(123);

      // Assert
      expect(secretUsageId1, equals(secretUsageId2));
      expect(identical(secretUsageId1, secretUsageId2), isTrue);
    });

    test('should allow const lists of SecretUsageIds', () {
      // Arrange & Act
      const ids = [
        SecretUsageId(1),
        SecretUsageId(2),
        SecretUsageId(3),
      ];

      // Assert
      expect(ids.length, 3);
      expect(ids[0].value, 1);
      expect(ids[1].value, 2);
      expect(ids[2].value, 3);
    });

    test('should create unique instances with different values', () {
      // Arrange & Act
      const secretUsageId1 = SecretUsageId(1);
      const secretUsageId2 = SecretUsageId(2);

      // Assert
      expect(secretUsageId1, isNot(equals(secretUsageId2)));
      expect(identical(secretUsageId1, secretUsageId2), isFalse);
    });
  });

  group('SecretUsageId - Collections', () {
    test('should work correctly in a Set', () {
      // Arrange
      final set = <SecretUsageId>{};
      final id1 = SecretUsageId(1);
      final id2 = SecretUsageId(2);
      final id3 = SecretUsageId(1); // duplicate value

      // Act
      set.add(id1);
      set.add(id2);
      set.add(id3);

      // Assert
      expect(set.length, 2); // Only 2 unique values
      expect(set.contains(id1), isTrue);
      expect(set.contains(id2), isTrue);
      expect(set.contains(id3), isTrue); // Equal to id1
    });

    test('should work correctly in a Map as key', () {
      // Arrange
      final map = <SecretUsageId, String>{};
      final id1 = SecretUsageId(1);
      final id2 = SecretUsageId(2);
      final id3 = SecretUsageId(1); // duplicate value

      // Act
      map[id1] = 'first';
      map[id2] = 'second';
      map[id3] = 'third'; // Should override 'first'

      // Assert
      expect(map.length, 2);
      expect(map[id1], 'third');
      expect(map[id2], 'second');
      expect(map[id3], 'third');
    });

    test('should be sortable in a List', () {
      // Arrange
      final ids = [
        SecretUsageId(5),
        SecretUsageId(1),
        SecretUsageId(3),
        SecretUsageId(2),
        SecretUsageId(4),
      ];

      // Act
      ids.sort((a, b) => a.value.compareTo(b.value));

      // Assert
      expect(ids[0].value, 1);
      expect(ids[1].value, 2);
      expect(ids[2].value, 3);
      expect(ids[3].value, 4);
      expect(ids[4].value, 5);
    });

    test('should work with List operations', () {
      // Arrange
      final ids = [
        SecretUsageId(1),
        SecretUsageId(2),
        SecretUsageId(3),
      ];

      // Act & Assert
      expect(ids.length, 3);
      expect(ids.first.value, 1);
      expect(ids.last.value, 3);
      expect(ids.contains(SecretUsageId(2)), isTrue);
      expect(ids.contains(SecretUsageId(4)), isFalse);
    });
  });

  group('SecretUsageId - Immutability', () {
    test('should maintain immutability of value', () {
      // Arrange
      const originalValue = 123;
      final secretUsageId = SecretUsageId(originalValue);

      // Act - attempt to get value
      final retrievedValue = secretUsageId.value;

      // Assert
      expect(retrievedValue, originalValue);
      expect(secretUsageId.value, originalValue);
    });

    test('should create multiple independent instances', () {
      // Arrange
      final id1 = SecretUsageId(1);
      final id2 = SecretUsageId(2);
      final id3 = SecretUsageId(1);

      // Act & Assert
      expect(id1, equals(id3));
      expect(id1, isNot(equals(id2)));
      expect(id2, isNot(equals(id3)));
    });
  });

  group('SecretUsageId - Type Safety', () {
    test('should be type-safe value object', () {
      // Arrange
      final secretUsageId = SecretUsageId(123);

      // Act & Assert
      expect(secretUsageId, isA<SecretUsageId>());
      expect(secretUsageId.value, isA<int>());
    });

    test('should not be equal to raw int', () {
      // Arrange
      final secretUsageId = SecretUsageId(123);
      const rawInt = 123;

      // Act & Assert
      expect(secretUsageId, isNot(equals(rawInt)));
    });

    test('should provide type safety in function parameters', () {
      // Arrange
      void processId(SecretUsageId id) {
        expect(id, isA<SecretUsageId>());
      }

      final secretUsageId = SecretUsageId(123);

      // Act & Assert
      expect(() => processId(secretUsageId), returnsNormally);
    });
  });
}
