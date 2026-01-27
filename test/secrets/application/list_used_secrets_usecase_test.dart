import 'package:bb_mobile/features/secrets/application/ports/secret_usage_repository_port.dart';
import 'package:bb_mobile/features/secrets/application/secrets_application_error.dart';
import 'package:bb_mobile/features/secrets/application/usecases/list_used_secrets_usecase.dart';
import 'package:bb_mobile/features/secrets/domain/entities/secret_usage_entity.dart';
import 'package:bb_mobile/features/secrets/domain/secrets_domain_error.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/fingerprint.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/secret_consumer.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/secret_usage_id.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'list_used_secrets_usecase_test.mocks.dart';

@GenerateMocks([SecretUsageRepositoryPort])
void main() {
  late ListUsedSecretsUseCase useCase;
  late MockSecretUsageRepositoryPort mockSecretUsageRepository;

  // Test data
  final testFingerprint1 = Fingerprint.fromHex('11111111');
  final testFingerprint2 = Fingerprint.fromHex('22222222');
  final testFingerprint3 = Fingerprint.fromHex('33333333');

  setUp(() {
    mockSecretUsageRepository = MockSecretUsageRepositoryPort();

    useCase = ListUsedSecretsUseCase(
      secretUsageRepository: mockSecretUsageRepository,
    );
  });

  group('ListUsedSecretsUseCase - Happy Path', () {
    test('should successfully list all used seed fingerprints', () async {
      // Arrange
      final query = ListUsedSecretsQuery();

      final seedUsages = [
        _createTestSecretUsageForWalletConsumer(
          id: 1,
          fingerprint: testFingerprint1.value,
        ),
        _createTestSecretUsageForWalletConsumer(
          id: 2,
          fingerprint: testFingerprint2.value,
        ),
        _createTestSecretUsageForWalletConsumer(
          id: 3,
          fingerprint: testFingerprint3.value,
        ),
      ];

      when(
        mockSecretUsageRepository.getAll(),
      ).thenAnswer((_) async => seedUsages);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.fingerprints, [
        testFingerprint1,
        testFingerprint2,
        testFingerprint3,
      ]);

      // Verify port interactions
      verify(mockSecretUsageRepository.getAll()).called(1);
    });

    test('should return empty list when no seeds are used', () async {
      // Arrange
      final query = ListUsedSecretsQuery();

      when(mockSecretUsageRepository.getAll()).thenAnswer((_) async => []);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.fingerprints, isEmpty);

      // Verify port interactions
      verify(mockSecretUsageRepository.getAll()).called(1);
    });

    test('should handle single seed usage', () async {
      // Arrange
      final query = ListUsedSecretsQuery();

      final seedUsages = [
        _createTestSecretUsageForWalletConsumer(
          fingerprint: testFingerprint1.value,
        ),
      ];

      when(
        mockSecretUsageRepository.getAll(),
      ).thenAnswer((_) async => seedUsages);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.fingerprints, [testFingerprint1]);

      // Verify port interactions
      verify(mockSecretUsageRepository.getAll()).called(1);
    });

    test('should list fingerprints from multiple purposes', () async {
      // Arrange
      final query = ListUsedSecretsQuery();

      final seedUsages = [
        _createTestSecretUsageForWalletConsumer(
          id: 1,
          fingerprint: testFingerprint1.value,
        ),
        _createTestSecretUsageForBip85Consumer(
          id: 2,
          fingerprint: testFingerprint2.value,
        ),
        _createTestSecretUsageForWalletConsumer(
          id: 3,
          fingerprint: testFingerprint3.value,
        ),
      ];

      when(
        mockSecretUsageRepository.getAll(),
      ).thenAnswer((_) async => seedUsages);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.fingerprints.length, 3);
      expect(result.fingerprints, contains(testFingerprint1));
      expect(result.fingerprints, contains(testFingerprint2));
      expect(result.fingerprints, contains(testFingerprint3));

      // Verify port interactions
      verify(mockSecretUsageRepository.getAll()).called(1);
    });

    test(
      'should preserve duplicates if same seed used multiple times',
      () async {
        // Arrange
        final query = ListUsedSecretsQuery();

        final seedUsages = [
          _createTestSecretUsageForWalletConsumer(
            id: 1,
            fingerprint: testFingerprint1.value,
          ),
          _createTestSecretUsageForBip85Consumer(
            id: 2,
            fingerprint: testFingerprint1.value,
          ),
        ];

        when(
          mockSecretUsageRepository.getAll(),
        ).thenAnswer((_) async => seedUsages);

        // Act
        final result = await useCase.execute(query);

        // Assert
        expect(result.fingerprints, [testFingerprint1, testFingerprint1]);

        // Verify port interactions
        verify(mockSecretUsageRepository.getAll()).called(1);
      },
    );
  });

  group('ListUsedSecretsUseCase - Error Scenarios', () {
    test(
      'should throw BusinessRuleFailed when getAll throws domain error',
      () async {
        // Arrange
        final query = ListUsedSecretsQuery();

        final domainError = TestSecretsDomainError(
          'Repository constraint violated',
        );
        when(mockSecretUsageRepository.getAll()).thenThrow(domainError);

        // Act & Assert
        await expectLater(
          () => useCase.execute(query),
          throwsA(
            isA<BusinessRuleFailed>()
                .having((e) => e.domainError, 'domainError', domainError)
                .having((e) => e.cause, 'cause', domainError),
          ),
        );

        // Verify getAll was called
        verify(mockSecretUsageRepository.getAll()).called(1);
      },
    );

    test(
      'should throw FailedToListUsedSecretsError when getAll fails',
      () async {
        // Arrange
        final query = ListUsedSecretsQuery();

        final repositoryError = Exception('Database connection failed');
        when(mockSecretUsageRepository.getAll()).thenThrow(repositoryError);

        // Act & Assert
        await expectLater(
          () => useCase.execute(query),
          throwsA(
            isA<FailedToListUsedSecretsError>().having(
              (e) => e.cause,
              'cause',
              repositoryError,
            ),
          ),
        );

        // Verify getAll was called
        verify(mockSecretUsageRepository.getAll()).called(1);
      },
    );

    test('should rethrow application errors without wrapping', () async {
      // Arrange
      final query = ListUsedSecretsQuery();

      final appError = SecretInUseError('test-fingerprint');
      when(mockSecretUsageRepository.getAll()).thenThrow(appError);

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
  });

  group('ListUsedSecretsUseCase - Verification Tests', () {
    test('should call getAll exactly once in happy path', () async {
      // Arrange
      final query = ListUsedSecretsQuery();

      final seedUsages = [
        _createTestSecretUsageForWalletConsumer(
          fingerprint: testFingerprint1.value,
        ),
      ];

      when(
        mockSecretUsageRepository.getAll(),
      ).thenAnswer((_) async => seedUsages);

      // Act
      await useCase.execute(query);

      // Assert - verify exactly one call
      verify(mockSecretUsageRepository.getAll()).called(1);

      // Verify no other interactions
      verifyNoMoreInteractions(mockSecretUsageRepository);
    });

    test('should map all seed usages to fingerprints correctly', () async {
      // Arrange
      final query = ListUsedSecretsQuery();

      final seedUsages = [
        _createTestSecretUsageForWalletConsumer(id: 1, fingerprint: 'aaaa1111'),
        _createTestSecretUsageForWalletConsumer(id: 2, fingerprint: 'bbbb2222'),
        _createTestSecretUsageForWalletConsumer(id: 3, fingerprint: 'cccc3333'),
        _createTestSecretUsageForWalletConsumer(id: 4, fingerprint: 'dddd4444'),
        _createTestSecretUsageForWalletConsumer(id: 5, fingerprint: 'eeee5555'),
      ];

      when(
        mockSecretUsageRepository.getAll(),
      ).thenAnswer((_) async => seedUsages);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.fingerprints.length, seedUsages.length);
      for (int i = 0; i < seedUsages.length; i++) {
        expect(result.fingerprints[i], seedUsages[i].fingerprint);
      }
    });

    test('should return result with mapped fingerprints', () async {
      // Arrange
      final query = ListUsedSecretsQuery();

      final uniqueFingerprint1 = Fingerprint.fromHex('aabbcc11');
      final uniqueFingerprint2 = Fingerprint.fromHex('aabbcc22');

      final seedUsages = [
        _createTestSecretUsageForWalletConsumer(
          id: 10,
          fingerprint: uniqueFingerprint1.value,
        ),
        _createTestSecretUsageForWalletConsumer(
          id: 20,
          fingerprint: uniqueFingerprint2.value,
        ),
      ];

      when(
        mockSecretUsageRepository.getAll(),
      ).thenAnswer((_) async => seedUsages);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.fingerprints, [uniqueFingerprint1, uniqueFingerprint2]);
    });

    test('should maintain order of fingerprints from repository', () async {
      // Arrange
      final query = ListUsedSecretsQuery();

      final firstFingerprint = Fingerprint.fromHex('11223344');
      final secondFingerprint = Fingerprint.fromHex('22334455');
      final thirdFingerprint = Fingerprint.fromHex('33445566');

      final seedUsages = [
        _createTestSecretUsageForWalletConsumer(
          id: 3,
          fingerprint: thirdFingerprint.value,
        ),
        _createTestSecretUsageForWalletConsumer(
          id: 1,
          fingerprint: firstFingerprint.value,
        ),
        _createTestSecretUsageForWalletConsumer(
          id: 2,
          fingerprint: secondFingerprint.value,
        ),
      ];

      when(
        mockSecretUsageRepository.getAll(),
      ).thenAnswer((_) async => seedUsages);

      // Act
      final result = await useCase.execute(query);

      // Assert - order should be maintained as returned from repository
      expect(result.fingerprints, [
        thirdFingerprint,
        firstFingerprint,
        secondFingerprint,
      ]);
    });

    test('should work with large number of seed usages', () async {
      // Arrange
      final query = ListUsedSecretsQuery();

      final seedUsages = List.generate(
        100,
        (i) => _createTestSecretUsageForWalletConsumer(
          id: i,
          fingerprint: i.toRadixString(16).padLeft(8, '0'),
        ),
      );

      when(
        mockSecretUsageRepository.getAll(),
      ).thenAnswer((_) async => seedUsages);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.fingerprints.length, 100);
      for (int i = 0; i < 100; i++) {
        expect(result.fingerprints[i], Fingerprint.fromHex(i.toRadixString(16).padLeft(8, '0')));
      }

      // Verify getAll was called
      verify(mockSecretUsageRepository.getAll()).called(1);
    });
  });
}

// Test helper function to create a test SecretUsage entity
SecretUsage _createTestSecretUsageForWalletConsumer({
  int? id,
  String? fingerprint,
  String? walletId,
}) {
  return SecretUsage(
    id: SecretUsageId(id ?? 1),
    fingerprint: Fingerprint.fromHex(fingerprint ?? '12345678'),
    consumer: WalletConsumer(walletId ?? 'test-wallet-id'),
    createdAt: DateTime.now(),
  );
}

SecretUsage _createTestSecretUsageForBip85Consumer({
  int? id,
  String? fingerprint,
  String? bip85Path,
}) {
  return SecretUsage(
    id: SecretUsageId(id ?? 1),
    fingerprint: Fingerprint.fromHex(fingerprint ?? '12345678'),
    consumer: Bip85Consumer(bip85Path ?? 'test-bip85-path'),
    createdAt: DateTime.now(),
  );
}
