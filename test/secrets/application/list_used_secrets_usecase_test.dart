import 'package:bb_mobile/features/secrets/domain/secret_usage_purpose.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_usage_repository_port.dart';
import 'package:bb_mobile/features/secrets/application/secrets_application_errors.dart';
import 'package:bb_mobile/features/secrets/application/usecases/list_used_secrets_usecase.dart';
import 'package:bb_mobile/features/secrets/domain/entities/secret_usage_entity.dart';
import 'package:bb_mobile/features/secrets/domain/secrets_domain_errors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'list_used_secrets_usecase_test.mocks.dart';

@GenerateMocks([SecretUsageRepositoryPort])
void main() {
  late ListUsedSecretsUseCase useCase;
  late MockSecretUsageRepositoryPort mockSecretUsageRepository;

  // Test data
  const testFingerprint1 = 'fingerprint-1';
  const testFingerprint2 = 'fingerprint-2';
  const testFingerprint3 = 'fingerprint-3';

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
        _createTestSecretUsage(id: 1, fingerprint: testFingerprint1),
        _createTestSecretUsage(id: 2, fingerprint: testFingerprint2),
        _createTestSecretUsage(id: 3, fingerprint: testFingerprint3),
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
        _createTestSecretUsage(fingerprint: testFingerprint1),
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
        _createTestSecretUsage(
          id: 1,
          fingerprint: testFingerprint1,
          purpose: SecretUsagePurpose.wallet,
        ),
        _createTestSecretUsage(
          id: 2,
          fingerprint: testFingerprint2,
          purpose: SecretUsagePurpose.bip85,
        ),
        _createTestSecretUsage(
          id: 3,
          fingerprint: testFingerprint3,
          purpose: SecretUsagePurpose.wallet,
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
          _createTestSecretUsage(
            id: 1,
            fingerprint: testFingerprint1,
            purpose: SecretUsagePurpose.wallet,
          ),
          _createTestSecretUsage(
            id: 2,
            fingerprint: testFingerprint1,
            purpose: SecretUsagePurpose.bip85,
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
        _createTestSecretUsage(fingerprint: testFingerprint1),
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
        _createTestSecretUsage(id: 1, fingerprint: 'fp-a'),
        _createTestSecretUsage(id: 2, fingerprint: 'fp-b'),
        _createTestSecretUsage(id: 3, fingerprint: 'fp-c'),
        _createTestSecretUsage(id: 4, fingerprint: 'fp-d'),
        _createTestSecretUsage(id: 5, fingerprint: 'fp-e'),
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

      final seedUsages = [
        _createTestSecretUsage(id: 10, fingerprint: 'unique-fp-1'),
        _createTestSecretUsage(id: 20, fingerprint: 'unique-fp-2'),
      ];

      when(
        mockSecretUsageRepository.getAll(),
      ).thenAnswer((_) async => seedUsages);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.fingerprints, ['unique-fp-1', 'unique-fp-2']);
    });

    test('should maintain order of fingerprints from repository', () async {
      // Arrange
      final query = ListUsedSecretsQuery();

      final seedUsages = [
        _createTestSecretUsage(id: 3, fingerprint: 'third'),
        _createTestSecretUsage(id: 1, fingerprint: 'first'),
        _createTestSecretUsage(id: 2, fingerprint: 'second'),
      ];

      when(
        mockSecretUsageRepository.getAll(),
      ).thenAnswer((_) async => seedUsages);

      // Act
      final result = await useCase.execute(query);

      // Assert - order should be maintained as returned from repository
      expect(result.fingerprints, ['third', 'first', 'second']);
    });

    test('should work with large number of seed usages', () async {
      // Arrange
      final query = ListUsedSecretsQuery();

      final seedUsages = List.generate(
        100,
        (i) => _createTestSecretUsage(id: i, fingerprint: 'fingerprint-$i'),
      );

      when(
        mockSecretUsageRepository.getAll(),
      ).thenAnswer((_) async => seedUsages);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.fingerprints.length, 100);
      for (int i = 0; i < 100; i++) {
        expect(result.fingerprints[i], 'fingerprint-$i');
      }

      // Verify getAll was called
      verify(mockSecretUsageRepository.getAll()).called(1);
    });
  });
}

// Test helper function to create a test SecretUsage entity
SecretUsage _createTestSecretUsage({
  int? id,
  String? fingerprint,
  SecretUsagePurpose? purpose,
  String? consumerRef,
}) {
  return SecretUsage(
    id: id ?? 1,
    fingerprint: fingerprint ?? 'test-fingerprint',
    purpose: purpose ?? SecretUsagePurpose.wallet,
    consumerRef: consumerRef ?? 'test-consumer',
    createdAt: DateTime.now(),
  );
}
