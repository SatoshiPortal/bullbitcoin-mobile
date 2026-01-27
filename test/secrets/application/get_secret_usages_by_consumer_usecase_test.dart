import 'package:bb_mobile/features/secrets/application/ports/secret_usage_repository_port.dart';
import 'package:bb_mobile/features/secrets/application/secrets_application_error.dart';
import 'package:bb_mobile/features/secrets/application/usecases/get_secret_usages_by_consumer_usecase.dart';
import 'package:bb_mobile/features/secrets/domain/entities/secret_usage_entity.dart';
import 'package:bb_mobile/features/secrets/domain/secrets_domain_error.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/fingerprint.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/secret_consumer.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/secret_usage_id.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'get_secret_usages_by_consumer_usecase_test.mocks.dart';

@GenerateMocks([SecretUsageRepositoryPort])
void main() {
  late GetSecretUsagesByConsumerUseCase useCase;
  late MockSecretUsageRepositoryPort mockSecretUsageRepository;

  // Test data
  const testWalletId = 'wallet-123';
  const testBip85Path = "m/83696968'/0'/0'";
  final testFingerprint = Fingerprint.fromHex('abcd1234');
  final testUsageId = SecretUsageId(1);
  final testCreatedAt = DateTime(2024, 1, 1);

  setUp(() {
    mockSecretUsageRepository = MockSecretUsageRepositoryPort();

    useCase = GetSecretUsagesByConsumerUseCase(
      secretUsageRepository: mockSecretUsageRepository,
    );
  });

  group('GetSecretUsagesByConsumerUseCase - Happy Path', () {
    test('should successfully retrieve usages for WalletConsumer', () async {
      // Arrange
      final query = GetSecretUsagesByConsumerQuery.byWallet(
        walletId: testWalletId,
      );
      final expectedUsage = SecretUsage(
        id: testUsageId,
        fingerprint: testFingerprint,
        consumer: WalletConsumer(testWalletId),
        createdAt: testCreatedAt,
      );

      when(mockSecretUsageRepository.getByConsumer(any))
          .thenAnswer((_) async => [expectedUsage]);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.usages, hasLength(1));
      expect(result.usages.first.id, testUsageId);
      expect(result.usages.first.fingerprint, testFingerprint);
      expect(result.usages.first.consumer, isA<WalletConsumer>());
      expect(
        (result.usages.first.consumer as WalletConsumer).walletId,
        testWalletId,
      );

      // Verify port interactions
      final captured = verify(
        mockSecretUsageRepository.getByConsumer(captureAny),
      ).captured.single as SecretConsumer;
      expect(captured, isA<WalletConsumer>());
      expect((captured as WalletConsumer).walletId, testWalletId);
    });

    test('should successfully retrieve usages for Bip85Consumer', () async {
      // Arrange
      final query = GetSecretUsagesByConsumerQuery.byBip85(
        bip85Path: testBip85Path,
      );
      final expectedUsage = SecretUsage(
        id: testUsageId,
        fingerprint: testFingerprint,
        consumer: Bip85Consumer(testBip85Path),
        createdAt: testCreatedAt,
      );

      when(mockSecretUsageRepository.getByConsumer(any))
          .thenAnswer((_) async => [expectedUsage]);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.usages, hasLength(1));
      expect(result.usages.first.id, testUsageId);
      expect(result.usages.first.fingerprint, testFingerprint);
      expect(result.usages.first.consumer, isA<Bip85Consumer>());
      expect(
        (result.usages.first.consumer as Bip85Consumer).bip85Path,
        testBip85Path,
      );

      // Verify port interactions
      final captured = verify(
        mockSecretUsageRepository.getByConsumer(captureAny),
      ).captured.single as SecretConsumer;
      expect(captured, isA<Bip85Consumer>());
      expect((captured as Bip85Consumer).bip85Path, testBip85Path);
    });

    test('should return empty list when no usages found', () async {
      // Arrange
      final query = GetSecretUsagesByConsumerQuery.byWallet(
        walletId: testWalletId,
      );

      when(mockSecretUsageRepository.getByConsumer(any))
          .thenAnswer((_) async => []);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.usages, isEmpty);

      // Verify port interactions
      verify(mockSecretUsageRepository.getByConsumer(any)).called(1);
    });

    test('should return multiple usages for same consumer', () async {
      // Arrange
      final query = GetSecretUsagesByConsumerQuery.byWallet(
        walletId: testWalletId,
      );
      final fingerprint1 = Fingerprint.fromHex('aaaa1111');
      final fingerprint2 = Fingerprint.fromHex('bbbb2222');
      final fingerprint3 = Fingerprint.fromHex('cccc3333');

      final usage1 = SecretUsage(
        id: SecretUsageId(1),
        fingerprint: fingerprint1,
        consumer: WalletConsumer(testWalletId),
        createdAt: testCreatedAt,
      );
      final usage2 = SecretUsage(
        id: SecretUsageId(2),
        fingerprint: fingerprint2,
        consumer: WalletConsumer(testWalletId),
        createdAt: testCreatedAt.add(Duration(hours: 1)),
      );
      final usage3 = SecretUsage(
        id: SecretUsageId(3),
        fingerprint: fingerprint3,
        consumer: WalletConsumer(testWalletId),
        createdAt: testCreatedAt.add(Duration(hours: 2)),
      );

      when(mockSecretUsageRepository.getByConsumer(any))
          .thenAnswer((_) async => [usage1, usage2, usage3]);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.usages, hasLength(3));
      expect(result.usages[0].fingerprint, fingerprint1);
      expect(result.usages[1].fingerprint, fingerprint2);
      expect(result.usages[2].fingerprint, fingerprint3);

      // Verify all usages belong to the same consumer
      for (final usage in result.usages) {
        expect(usage.consumer, isA<WalletConsumer>());
        expect((usage.consumer as WalletConsumer).walletId, testWalletId);
      }
    });

    test('should correctly handle different wallet IDs', () async {
      // Arrange
      const wallet1 = 'wallet-first';
      const wallet2 = 'wallet-second';

      final query1 = GetSecretUsagesByConsumerQuery.byWallet(
        walletId: wallet1,
      );
      final query2 = GetSecretUsagesByConsumerQuery.byWallet(
        walletId: wallet2,
      );

      final usage1 = SecretUsage(
        id: testUsageId,
        fingerprint: testFingerprint,
        consumer: WalletConsumer(wallet1),
        createdAt: testCreatedAt,
      );

      when(mockSecretUsageRepository.getByConsumer(WalletConsumer(wallet1)))
          .thenAnswer((_) async => [usage1]);
      when(mockSecretUsageRepository.getByConsumer(WalletConsumer(wallet2)))
          .thenAnswer((_) async => []);

      // Act
      final result1 = await useCase.execute(query1);
      final result2 = await useCase.execute(query2);

      // Assert
      expect(result1.usages, hasLength(1));
      expect(result2.usages, isEmpty);
    });

    test('should correctly handle different BIP85 paths', () async {
      // Arrange
      const path1 = "m/83696968'/0'/0'";
      const path2 = "m/83696968'/0'/1'";

      final query1 = GetSecretUsagesByConsumerQuery.byBip85(
        bip85Path: path1,
      );
      final query2 = GetSecretUsagesByConsumerQuery.byBip85(
        bip85Path: path2,
      );

      final usage1 = SecretUsage(
        id: testUsageId,
        fingerprint: testFingerprint,
        consumer: Bip85Consumer(path1),
        createdAt: testCreatedAt,
      );

      when(mockSecretUsageRepository.getByConsumer(Bip85Consumer(path1)))
          .thenAnswer((_) async => [usage1]);
      when(mockSecretUsageRepository.getByConsumer(Bip85Consumer(path2)))
          .thenAnswer((_) async => []);

      // Act
      final result1 = await useCase.execute(query1);
      final result2 = await useCase.execute(query2);

      // Assert
      expect(result1.usages, hasLength(1));
      expect(result2.usages, isEmpty);
    });
  });

  group('GetSecretUsagesByConsumerUseCase - Error Scenarios', () {
    test(
      'should throw BusinessRuleFailed when getByConsumer throws domain error',
      () async {
        // Arrange
        final query = GetSecretUsagesByConsumerQuery.byWallet(
          walletId: testWalletId,
        );

        final domainError = TestSecretsDomainError('Invalid consumer format');
        when(mockSecretUsageRepository.getByConsumer(any))
            .thenThrow(domainError);

        // Act & Assert
        await expectLater(
          () => useCase.execute(query),
          throwsA(
            isA<BusinessRuleFailed>()
                .having((e) => e.domainError, 'domainError', domainError)
                .having((e) => e.cause, 'cause', domainError),
          ),
        );

        // Verify getByConsumer was called
        verify(mockSecretUsageRepository.getByConsumer(any)).called(1);
      },
    );

    test(
      'should throw FailedToGetSecretUsagesByConsumerError when getByConsumer fails',
      () async {
        // Arrange
        final query = GetSecretUsagesByConsumerQuery.byWallet(
          walletId: testWalletId,
        );

        final repositoryError = Exception('Database connection lost');
        when(mockSecretUsageRepository.getByConsumer(any))
            .thenThrow(repositoryError);

        // Act & Assert
        await expectLater(
          () => useCase.execute(query),
          throwsA(
            isA<FailedToGetSecretUsagesByConsumerError>()
                .having((e) => e.consumer, 'consumer', isA<WalletConsumer>())
                .having((e) => e.cause, 'cause', repositoryError),
          ),
        );

        // Verify getByConsumer was called
        verify(mockSecretUsageRepository.getByConsumer(any)).called(1);
      },
    );

    test(
      'should throw FailedToGetSecretUsagesByConsumerError with Bip85Consumer when query is byBip85',
      () async {
        // Arrange
        final query = GetSecretUsagesByConsumerQuery.byBip85(
          bip85Path: testBip85Path,
        );

        final repositoryError = Exception('Query execution failed');
        when(mockSecretUsageRepository.getByConsumer(any))
            .thenThrow(repositoryError);

        // Act & Assert
        await expectLater(
          () => useCase.execute(query),
          throwsA(
            isA<FailedToGetSecretUsagesByConsumerError>()
                .having((e) => e.consumer, 'consumer', isA<Bip85Consumer>())
                .having((e) => e.cause, 'cause', repositoryError),
          ),
        );
      },
    );

    test('should rethrow application errors without wrapping', () async {
      // Arrange
      final query = GetSecretUsagesByConsumerQuery.byWallet(
        walletId: testWalletId,
      );

      final appError = SecretInUseError('test-fingerprint');
      when(mockSecretUsageRepository.getByConsumer(any)).thenThrow(appError);

      // Act & Assert
      await expectLater(
        () => useCase.execute(query),
        throwsA(
          isA<SecretInUseError>().having(
            (e) => e.fingerprint,
            'fingerprint',
            'test-fingerprint',
          ),
        ),
      );
    });

    test(
      'should handle domain error thrown during consumer creation',
      () async {
        // Arrange - This tests the switch statement error handling
        final query = GetSecretUsagesByConsumerQuery.byWallet(
          walletId: testWalletId,
        );

        final domainError = TestSecretsDomainError('Invalid wallet ID format');
        when(mockSecretUsageRepository.getByConsumer(any))
            .thenThrow(domainError);

        // Act & Assert
        await expectLater(
          () => useCase.execute(query),
          throwsA(isA<BusinessRuleFailed>()),
        );
      },
    );
  });

  group('GetSecretUsagesByConsumerUseCase - Verification Tests', () {
    test('should pass correct WalletConsumer to repository', () async {
      // Arrange
      const customWalletId = 'custom-wallet-xyz';
      final query = GetSecretUsagesByConsumerQuery.byWallet(
        walletId: customWalletId,
      );

      when(mockSecretUsageRepository.getByConsumer(any))
          .thenAnswer((_) async => []);

      // Act
      await useCase.execute(query);

      // Assert
      final captured = verify(
        mockSecretUsageRepository.getByConsumer(captureAny),
      ).captured.single as SecretConsumer;
      expect(captured, isA<WalletConsumer>());
      expect((captured as WalletConsumer).walletId, customWalletId);
    });

    test('should pass correct Bip85Consumer to repository', () async {
      // Arrange
      const customPath = "m/83696968'/1'/2'";
      final query = GetSecretUsagesByConsumerQuery.byBip85(
        bip85Path: customPath,
      );

      when(mockSecretUsageRepository.getByConsumer(any))
          .thenAnswer((_) async => []);

      // Act
      await useCase.execute(query);

      // Assert
      final captured = verify(
        mockSecretUsageRepository.getByConsumer(captureAny),
      ).captured.single as SecretConsumer;
      expect(captured, isA<Bip85Consumer>());
      expect((captured as Bip85Consumer).bip85Path, customPath);
    });

    test('should call getByConsumer exactly once in happy path', () async {
      // Arrange
      final query = GetSecretUsagesByConsumerQuery.byWallet(
        walletId: testWalletId,
      );

      when(mockSecretUsageRepository.getByConsumer(any))
          .thenAnswer((_) async => []);

      // Act
      await useCase.execute(query);

      // Assert - verify exactly one call
      verify(mockSecretUsageRepository.getByConsumer(any)).called(1);

      // Verify no other interactions
      verifyNoMoreInteractions(mockSecretUsageRepository);
    });

    test('should return result with all usages from repository', () async {
      // Arrange
      final query = GetSecretUsagesByConsumerQuery.byWallet(
        walletId: testWalletId,
      );

      final usage1 = SecretUsage(
        id: SecretUsageId(1),
        fingerprint: Fingerprint.fromHex('aaaa1111'),
        consumer: WalletConsumer(testWalletId),
        createdAt: testCreatedAt,
      );
      final usage2 = SecretUsage(
        id: SecretUsageId(2),
        fingerprint: Fingerprint.fromHex('bbbb2222'),
        consumer: WalletConsumer(testWalletId),
        createdAt: testCreatedAt,
      );

      when(mockSecretUsageRepository.getByConsumer(any))
          .thenAnswer((_) async => [usage1, usage2]);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.usages, hasLength(2));
      expect(result.usages[0], same(usage1));
      expect(result.usages[1], same(usage2));
    });

    test('should preserve usage order from repository', () async {
      // Arrange
      final query = GetSecretUsagesByConsumerQuery.byWallet(
        walletId: testWalletId,
      );

      final ids = [5, 3, 8, 1, 9];
      final usages = ids
          .map(
            (id) => SecretUsage(
              id: SecretUsageId(id),
              fingerprint: testFingerprint,
              consumer: WalletConsumer(testWalletId),
              createdAt: testCreatedAt,
            ),
          )
          .toList();

      when(mockSecretUsageRepository.getByConsumer(any))
          .thenAnswer((_) async => usages);

      // Act
      final result = await useCase.execute(query);

      // Assert - verify order is preserved
      expect(result.usages, hasLength(5));
      for (int i = 0; i < ids.length; i++) {
        expect(result.usages[i].id.value, ids[i]);
      }
    });

    test('should handle consumer with special characters in wallet ID',
        () async {
      // Arrange
      const specialWalletId = 'wallet-!@#\$%^&*()_+-=[]{}|;:,.<>?';
      final query = GetSecretUsagesByConsumerQuery.byWallet(
        walletId: specialWalletId,
      );

      when(mockSecretUsageRepository.getByConsumer(any))
          .thenAnswer((_) async => []);

      // Act
      await useCase.execute(query);

      // Assert
      final captured = verify(
        mockSecretUsageRepository.getByConsumer(captureAny),
      ).captured.single as WalletConsumer;
      expect(captured.walletId, specialWalletId);
    });

    test('should handle consumer with unicode characters in BIP85 path',
        () async {
      // Arrange
      const unicodePath = "m/83696968'/0'/测试'";
      final query = GetSecretUsagesByConsumerQuery.byBip85(
        bip85Path: unicodePath,
      );

      when(mockSecretUsageRepository.getByConsumer(any))
          .thenAnswer((_) async => []);

      // Act
      await useCase.execute(query);

      // Assert
      final captured = verify(
        mockSecretUsageRepository.getByConsumer(captureAny),
      ).captured.single as Bip85Consumer;
      expect(captured.bip85Path, unicodePath);
    });
  });

  group('GetSecretUsagesByConsumerUseCase - Query Type Tests', () {
    test('should correctly distinguish between query types', () async {
      // Arrange
      final walletQuery = GetSecretUsagesByConsumerQuery.byWallet(
        walletId: testWalletId,
      );
      final bip85Query = GetSecretUsagesByConsumerQuery.byBip85(
        bip85Path: testBip85Path,
      );

      when(mockSecretUsageRepository.getByConsumer(any))
          .thenAnswer((_) async => []);

      // Act
      await useCase.execute(walletQuery);
      await useCase.execute(bip85Query);

      // Assert
      final capturedConsumers = verify(
        mockSecretUsageRepository.getByConsumer(captureAny),
      ).captured;

      expect(capturedConsumers, hasLength(2));
      expect(capturedConsumers[0], isA<WalletConsumer>());
      expect(capturedConsumers[1], isA<Bip85Consumer>());
    });

    test('should handle query switching correctly', () async {
      // Arrange
      when(mockSecretUsageRepository.getByConsumer(any))
          .thenAnswer((_) async => []);

      // Act - Execute multiple queries in sequence
      await useCase.execute(
        GetSecretUsagesByConsumerQuery.byWallet(walletId: 'wallet-1'),
      );
      await useCase.execute(
        GetSecretUsagesByConsumerQuery.byBip85(bip85Path: "m/83696968'/0'/0'"),
      );
      await useCase.execute(
        GetSecretUsagesByConsumerQuery.byWallet(walletId: 'wallet-2'),
      );

      // Assert
      final capturedConsumers = verify(
        mockSecretUsageRepository.getByConsumer(captureAny),
      ).captured;

      expect(capturedConsumers, hasLength(3));
      expect(capturedConsumers[0], isA<WalletConsumer>());
      expect((capturedConsumers[0] as WalletConsumer).walletId, 'wallet-1');
      expect(capturedConsumers[1], isA<Bip85Consumer>());
      expect(
        (capturedConsumers[1] as Bip85Consumer).bip85Path,
        "m/83696968'/0'/0'",
      );
      expect(capturedConsumers[2], isA<WalletConsumer>());
      expect((capturedConsumers[2] as WalletConsumer).walletId, 'wallet-2');
    });
  });
}
