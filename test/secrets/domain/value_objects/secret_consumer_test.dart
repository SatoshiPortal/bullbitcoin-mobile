import 'package:bb_mobile/features/secrets/domain/value_objects/secret_consumer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WalletConsumer - Creation', () {
    test('should create WalletConsumer with wallet ID', () {
      // Arrange
      const walletId = 'wallet-123';

      // Act
      final consumer = WalletConsumer(walletId);

      // Assert
      expect(consumer.walletId, walletId);
    });

    test('should create WalletConsumer with empty wallet ID', () {
      // Arrange
      const walletId = '';

      // Act
      final consumer = WalletConsumer(walletId);

      // Assert
      expect(consumer.walletId, walletId);
    });

    test('should create WalletConsumer with long wallet ID', () {
      // Arrange
      final walletId = 'a' * 1000;

      // Act
      final consumer = WalletConsumer(walletId);

      // Assert
      expect(consumer.walletId, walletId);
      expect(consumer.walletId.length, 1000);
    });

    test('should create WalletConsumer with special characters', () {
      // Arrange
      const walletId = 'wallet-123-!@#\$%^&*()';

      // Act
      final consumer = WalletConsumer(walletId);

      // Assert
      expect(consumer.walletId, walletId);
    });

    test('should create WalletConsumer with UUID-like ID', () {
      // Arrange
      const walletId = '550e8400-e29b-41d4-a716-446655440000';

      // Act
      final consumer = WalletConsumer(walletId);

      // Assert
      expect(consumer.walletId, walletId);
    });
  });

  group('WalletConsumer - Equality', () {
    test('should be equal when wallet IDs are the same', () {
      // Arrange
      const walletId = 'wallet-123';
      final consumer1 = WalletConsumer(walletId);
      final consumer2 = WalletConsumer(walletId);

      // Act & Assert
      expect(consumer1, equals(consumer2));
      expect(consumer1.hashCode, equals(consumer2.hashCode));
    });

    test('should not be equal when wallet IDs differ', () {
      // Arrange
      final consumer1 = WalletConsumer('wallet-123');
      final consumer2 = WalletConsumer('wallet-456');

      // Act & Assert
      expect(consumer1, isNot(equals(consumer2)));
    });

    test('should be case sensitive', () {
      // Arrange
      final consumer1 = WalletConsumer('Wallet-123');
      final consumer2 = WalletConsumer('wallet-123');

      // Act & Assert
      expect(consumer1, isNot(equals(consumer2)));
    });

    test('should be equal to itself', () {
      // Arrange
      final consumer = WalletConsumer('wallet-123');

      // Act & Assert
      expect(consumer, equals(consumer));
    });

    test('should not be equal to null', () {
      // Arrange
      final consumer = WalletConsumer('wallet-123');

      // Act & Assert
      expect(consumer, isNot(equals(null)));
    });

    test('should not be equal to different type', () {
      // Arrange
      final walletConsumer = WalletConsumer('wallet-123');
      final bip85Consumer = Bip85Consumer('m/83696968\'/0\'/0\'');

      // Act & Assert
      expect(walletConsumer, isNot(equals(bip85Consumer)));
    });
  });

  group('WalletConsumer - toString', () {
    test('should return formatted string representation', () {
      // Arrange
      const walletId = 'wallet-123';
      final consumer = WalletConsumer(walletId);

      // Act
      final result = consumer.toString();

      // Assert
      expect(result, 'WalletConsumer(wallet-123)');
    });

    test('should include wallet ID in string representation', () {
      // Arrange
      const walletId = 'my-test-wallet';
      final consumer = WalletConsumer(walletId);

      // Act
      final result = consumer.toString();

      // Assert
      expect(result, contains('my-test-wallet'));
      expect(result, 'WalletConsumer(my-test-wallet)');
    });

    test('should handle empty wallet ID in toString', () {
      // Arrange
      final consumer = WalletConsumer('');

      // Act
      final result = consumer.toString();

      // Assert
      expect(result, 'WalletConsumer()');
    });
  });

  group('WalletConsumer - Type Hierarchy', () {
    test('should be a subtype of SecretConsumer', () {
      // Arrange
      final consumer = WalletConsumer('wallet-123');

      // Act & Assert
      expect(consumer, isA<SecretConsumer>());
    });

    test('should be a WalletConsumer type', () {
      // Arrange
      final consumer = WalletConsumer('wallet-123');

      // Act & Assert
      expect(consumer, isA<WalletConsumer>());
    });
  });

  group('Bip85Consumer - Creation', () {
    test('should create Bip85Consumer with BIP85 path', () {
      // Arrange
      const bip85Path = 'm/83696968\'/0\'/0\'';

      // Act
      final consumer = Bip85Consumer(bip85Path);

      // Assert
      expect(consumer.bip85Path, bip85Path);
    });

    test('should create Bip85Consumer with empty path', () {
      // Arrange
      const bip85Path = '';

      // Act
      final consumer = Bip85Consumer(bip85Path);

      // Assert
      expect(consumer.bip85Path, bip85Path);
    });

    test('should create Bip85Consumer with various BIP85 paths', () {
      // Arrange
      final paths = [
        'm/83696968\'/0\'/0\'',
        'm/83696968\'/0\'/1\'',
        'm/83696968\'/39\'/0\'/12\'/0\'',
        'm/83696968\'/32\'/0\'',
      ];

      // Act & Assert
      for (final path in paths) {
        final consumer = Bip85Consumer(path);
        expect(consumer.bip85Path, path);
      }
    });

    test('should create Bip85Consumer with custom path string', () {
      // Arrange
      const customPath = 'custom-derivation-path';

      // Act
      final consumer = Bip85Consumer(customPath);

      // Assert
      expect(consumer.bip85Path, customPath);
    });
  });

  group('Bip85Consumer - Equality', () {
    test('should be equal when BIP85 paths are the same', () {
      // Arrange
      const path = 'm/83696968\'/0\'/0\'';
      final consumer1 = Bip85Consumer(path);
      final consumer2 = Bip85Consumer(path);

      // Act & Assert
      expect(consumer1, equals(consumer2));
      expect(consumer1.hashCode, equals(consumer2.hashCode));
    });

    test('should not be equal when BIP85 paths differ', () {
      // Arrange
      final consumer1 = Bip85Consumer('m/83696968\'/0\'/0\'');
      final consumer2 = Bip85Consumer('m/83696968\'/0\'/1\'');

      // Act & Assert
      expect(consumer1, isNot(equals(consumer2)));
    });

    test('should be case sensitive', () {
      // Arrange
      final consumer1 = Bip85Consumer('m/83696968\'/0\'/0\'');
      final consumer2 = Bip85Consumer('M/83696968\'/0\'/0\'');

      // Act & Assert
      expect(consumer1, isNot(equals(consumer2)));
    });

    test('should be equal to itself', () {
      // Arrange
      final consumer = Bip85Consumer('m/83696968\'/0\'/0\'');

      // Act & Assert
      expect(consumer, equals(consumer));
    });

    test('should not be equal to null', () {
      // Arrange
      final consumer = Bip85Consumer('m/83696968\'/0\'/0\'');

      // Act & Assert
      expect(consumer, isNot(equals(null)));
    });

    test('should not be equal to different type', () {
      // Arrange
      final bip85Consumer = Bip85Consumer('m/83696968\'/0\'/0\'');
      final walletConsumer = WalletConsumer('wallet-123');

      // Act & Assert
      expect(bip85Consumer, isNot(equals(walletConsumer)));
    });
  });

  group('Bip85Consumer - toString', () {
    test('should return formatted string representation', () {
      // Arrange
      const path = 'm/83696968\'/0\'/0\'';
      final consumer = Bip85Consumer(path);

      // Act
      final result = consumer.toString();

      // Assert
      expect(result, 'Bip85Consumer(m/83696968\'/0\'/0\')');
    });

    test('should include path in string representation', () {
      // Arrange
      const path = 'm/83696968\'/39\'/0\'/12\'/0\'';
      final consumer = Bip85Consumer(path);

      // Act
      final result = consumer.toString();

      // Assert
      expect(result, contains(path));
      expect(result, 'Bip85Consumer(m/83696968\'/39\'/0\'/12\'/0\')');
    });

    test('should handle empty path in toString', () {
      // Arrange
      final consumer = Bip85Consumer('');

      // Act
      final result = consumer.toString();

      // Assert
      expect(result, 'Bip85Consumer()');
    });
  });

  group('Bip85Consumer - Type Hierarchy', () {
    test('should be a subtype of SecretConsumer', () {
      // Arrange
      final consumer = Bip85Consumer('m/83696968\'/0\'/0\'');

      // Act & Assert
      expect(consumer, isA<SecretConsumer>());
    });

    test('should be a Bip85Consumer type', () {
      // Arrange
      final consumer = Bip85Consumer('m/83696968\'/0\'/0\'');

      // Act & Assert
      expect(consumer, isA<Bip85Consumer>());
    });
  });

  group('SecretConsumer - Sealed Class', () {
    test('should not be able to create SecretConsumer directly', () {
      // The sealed class cannot be instantiated directly
      // This test verifies the type system works correctly

      // Arrange
      final SecretConsumer walletConsumer = WalletConsumer('wallet-123');
      final SecretConsumer bip85Consumer = Bip85Consumer('m/83696968\'/0\'/0\'');

      // Act & Assert
      expect(walletConsumer, isA<SecretConsumer>());
      expect(bip85Consumer, isA<SecretConsumer>());
    });

    test('should support polymorphism', () {
      // Arrange
      final List<SecretConsumer> consumers = [
        WalletConsumer('wallet-1'),
        WalletConsumer('wallet-2'),
        Bip85Consumer('m/83696968\'/0\'/0\''),
        Bip85Consumer('m/83696968\'/0\'/1\''),
      ];

      // Act & Assert
      expect(consumers.length, 4);
      expect(consumers[0], isA<WalletConsumer>());
      expect(consumers[1], isA<WalletConsumer>());
      expect(consumers[2], isA<Bip85Consumer>());
      expect(consumers[3], isA<Bip85Consumer>());

      for (final consumer in consumers) {
        expect(consumer, isA<SecretConsumer>());
      }
    });

    test('should support pattern matching on consumer type', () {
      // Arrange
      final SecretConsumer walletConsumer = WalletConsumer('wallet-123');
      final SecretConsumer bip85Consumer = Bip85Consumer('m/83696968\'/0\'/0\'');

      // Act & Assert
      expect(
        switch (walletConsumer) {
          WalletConsumer() => 'wallet',
          Bip85Consumer() => 'bip85',
        },
        'wallet',
      );

      expect(
        switch (bip85Consumer) {
          WalletConsumer() => 'wallet',
          Bip85Consumer() => 'bip85',
        },
        'bip85',
      );
    });
  });

  group('SecretConsumer - Cross-Type Comparisons', () {
    test('WalletConsumer and Bip85Consumer should never be equal', () {
      // Arrange
      final walletConsumer = WalletConsumer('same-id');
      final bip85Consumer = Bip85Consumer('same-id');

      // Act & Assert
      expect(walletConsumer, isNot(equals(bip85Consumer)));
    });

    test('should distinguish between different consumer types', () {
      // Arrange
      final consumers = <SecretConsumer>[
        WalletConsumer('id-1'),
        Bip85Consumer('id-1'),
        WalletConsumer('id-2'),
        Bip85Consumer('id-2'),
      ];

      // Act & Assert
      expect(consumers[0], isNot(equals(consumers[1])));
      expect(consumers[0], isNot(equals(consumers[2])));
      expect(consumers[0], isNot(equals(consumers[3])));
      expect(consumers[1], isNot(equals(consumers[2])));
      expect(consumers[1], isNot(equals(consumers[3])));
      expect(consumers[2], isNot(equals(consumers[3])));
    });
  });

  group('SecretConsumer - Const Constructor', () {
    test('should create const WalletConsumer instances', () {
      // Arrange & Act
      const consumer1 = WalletConsumer('wallet-123');
      const consumer2 = WalletConsumer('wallet-123');

      // Assert
      expect(consumer1, equals(consumer2));
      expect(identical(consumer1, consumer2), isTrue);
    });

    test('should create const Bip85Consumer instances', () {
      // Arrange & Act
      const consumer1 = Bip85Consumer('m/83696968\'/0\'/0\'');
      const consumer2 = Bip85Consumer('m/83696968\'/0\'/0\'');

      // Assert
      expect(consumer1, equals(consumer2));
      expect(identical(consumer1, consumer2), isTrue);
    });

    test('should allow const lists of consumers', () {
      // Arrange & Act
      const consumers = [
        WalletConsumer('wallet-1'),
        Bip85Consumer('m/83696968\'/0\'/0\''),
      ];

      // Assert
      expect(consumers.length, 2);
      expect(consumers[0], isA<WalletConsumer>());
      expect(consumers[1], isA<Bip85Consumer>());
    });
  });
}
