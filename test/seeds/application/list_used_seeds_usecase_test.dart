import 'package:bb_mobile/core/primitives/seeds/seed_usage_purpose.dart';
import 'package:bb_mobile/features/seeds/application/ports/seed_usage_repository_port.dart';
import 'package:bb_mobile/features/seeds/application/seeds_application_errors.dart';
import 'package:bb_mobile/features/seeds/application/usecases/list_used_seeds_usecase.dart';
import 'package:bb_mobile/features/seeds/domain/entities/seed_usage_entity.dart';
import 'package:bb_mobile/features/seeds/domain/seeds_domain_errors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'list_used_seeds_usecase_test.mocks.dart';

@GenerateMocks([
  SeedUsageRepositoryPort,
])
void main() {
  late ListUsedSeedsUseCase useCase;
  late MockSeedUsageRepositoryPort mockSeedUsageRepository;

  // Test data
  const testFingerprint1 = 'fingerprint-1';
  const testFingerprint2 = 'fingerprint-2';
  const testFingerprint3 = 'fingerprint-3';

  setUp(() {
    mockSeedUsageRepository = MockSeedUsageRepositoryPort();

    useCase = ListUsedSeedsUseCase(
      seedUsageRepository: mockSeedUsageRepository,
    );
  });

  group('ListUsedSeedsUseCase - Happy Path', () {
    test('should successfully list all used seed fingerprints', () async {
      // Arrange
      final query = ListUsedSeedsQuery();

      final seedUsages = [
        _createTestSeedUsage(id: 1, fingerprint: testFingerprint1),
        _createTestSeedUsage(id: 2, fingerprint: testFingerprint2),
        _createTestSeedUsage(id: 3, fingerprint: testFingerprint3),
      ];

      when(mockSeedUsageRepository.getAll()).thenAnswer((_) async => seedUsages);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.fingerprints, [
        testFingerprint1,
        testFingerprint2,
        testFingerprint3,
      ]);

      // Verify port interactions
      verify(mockSeedUsageRepository.getAll()).called(1);
    });

    test('should return empty list when no seeds are used', () async {
      // Arrange
      final query = ListUsedSeedsQuery();

      when(mockSeedUsageRepository.getAll()).thenAnswer((_) async => []);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.fingerprints, isEmpty);

      // Verify port interactions
      verify(mockSeedUsageRepository.getAll()).called(1);
    });

    test('should handle single seed usage', () async {
      // Arrange
      final query = ListUsedSeedsQuery();

      final seedUsages = [
        _createTestSeedUsage(fingerprint: testFingerprint1),
      ];

      when(mockSeedUsageRepository.getAll()).thenAnswer((_) async => seedUsages);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.fingerprints, [testFingerprint1]);

      // Verify port interactions
      verify(mockSeedUsageRepository.getAll()).called(1);
    });

    test('should list fingerprints from multiple purposes', () async {
      // Arrange
      final query = ListUsedSeedsQuery();

      final seedUsages = [
        _createTestSeedUsage(
          id: 1,
          fingerprint: testFingerprint1,
          purpose: SeedUsagePurpose.wallet,
        ),
        _createTestSeedUsage(
          id: 2,
          fingerprint: testFingerprint2,
          purpose: SeedUsagePurpose.bip85,
        ),
        _createTestSeedUsage(
          id: 3,
          fingerprint: testFingerprint3,
          purpose: SeedUsagePurpose.wallet,
        ),
      ];

      when(mockSeedUsageRepository.getAll()).thenAnswer((_) async => seedUsages);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.fingerprints.length, 3);
      expect(result.fingerprints, contains(testFingerprint1));
      expect(result.fingerprints, contains(testFingerprint2));
      expect(result.fingerprints, contains(testFingerprint3));

      // Verify port interactions
      verify(mockSeedUsageRepository.getAll()).called(1);
    });

    test('should preserve duplicates if same seed used multiple times', () async {
      // Arrange
      final query = ListUsedSeedsQuery();

      final seedUsages = [
        _createTestSeedUsage(
          id: 1,
          fingerprint: testFingerprint1,
          purpose: SeedUsagePurpose.wallet,
        ),
        _createTestSeedUsage(
          id: 2,
          fingerprint: testFingerprint1,
          purpose: SeedUsagePurpose.bip85,
        ),
      ];

      when(mockSeedUsageRepository.getAll()).thenAnswer((_) async => seedUsages);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.fingerprints, [testFingerprint1, testFingerprint1]);

      // Verify port interactions
      verify(mockSeedUsageRepository.getAll()).called(1);
    });
  });

  group('ListUsedSeedsUseCase - Error Scenarios', () {
    test('should throw BusinessRuleFailed when getAll throws domain error',
        () async {
      // Arrange
      final query = ListUsedSeedsQuery();

      final domainError = TestSeedsDomainError('Repository constraint violated');
      when(mockSeedUsageRepository.getAll()).thenThrow(domainError);

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
      verify(mockSeedUsageRepository.getAll()).called(1);
    });

    test('should throw FailedToListUsedSeedsError when getAll fails', () async {
      // Arrange
      final query = ListUsedSeedsQuery();

      final repositoryError = Exception('Database connection failed');
      when(mockSeedUsageRepository.getAll()).thenThrow(repositoryError);

      // Act & Assert
      await expectLater(
        () => useCase.execute(query),
        throwsA(
          isA<FailedToListUsedSeedsError>()
              .having((e) => e.cause, 'cause', repositoryError),
        ),
      );

      // Verify getAll was called
      verify(mockSeedUsageRepository.getAll()).called(1);
    });

    test('should rethrow application errors without wrapping', () async {
      // Arrange
      final query = ListUsedSeedsQuery();

      final appError = SeedInUseError('test-fingerprint');
      when(mockSeedUsageRepository.getAll()).thenThrow(appError);

      // Act & Assert
      await expectLater(
        () => useCase.execute(query),
        throwsA(
          isA<SeedInUseError>()
              .having((e) => e.fingerprint, 'fingerprint', 'test-fingerprint'),
        ),
      );
    });
  });

  group('ListUsedSeedsUseCase - Verification Tests', () {
    test('should call getAll exactly once in happy path', () async {
      // Arrange
      final query = ListUsedSeedsQuery();

      final seedUsages = [
        _createTestSeedUsage(fingerprint: testFingerprint1),
      ];

      when(mockSeedUsageRepository.getAll()).thenAnswer((_) async => seedUsages);

      // Act
      await useCase.execute(query);

      // Assert - verify exactly one call
      verify(mockSeedUsageRepository.getAll()).called(1);

      // Verify no other interactions
      verifyNoMoreInteractions(mockSeedUsageRepository);
    });

    test('should map all seed usages to fingerprints correctly', () async {
      // Arrange
      final query = ListUsedSeedsQuery();

      final seedUsages = [
        _createTestSeedUsage(id: 1, fingerprint: 'fp-a'),
        _createTestSeedUsage(id: 2, fingerprint: 'fp-b'),
        _createTestSeedUsage(id: 3, fingerprint: 'fp-c'),
        _createTestSeedUsage(id: 4, fingerprint: 'fp-d'),
        _createTestSeedUsage(id: 5, fingerprint: 'fp-e'),
      ];

      when(mockSeedUsageRepository.getAll()).thenAnswer((_) async => seedUsages);

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
      final query = ListUsedSeedsQuery();

      final seedUsages = [
        _createTestSeedUsage(id: 10, fingerprint: 'unique-fp-1'),
        _createTestSeedUsage(id: 20, fingerprint: 'unique-fp-2'),
      ];

      when(mockSeedUsageRepository.getAll()).thenAnswer((_) async => seedUsages);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.fingerprints, ['unique-fp-1', 'unique-fp-2']);
    });

    test('should maintain order of fingerprints from repository', () async {
      // Arrange
      final query = ListUsedSeedsQuery();

      final seedUsages = [
        _createTestSeedUsage(id: 3, fingerprint: 'third'),
        _createTestSeedUsage(id: 1, fingerprint: 'first'),
        _createTestSeedUsage(id: 2, fingerprint: 'second'),
      ];

      when(mockSeedUsageRepository.getAll()).thenAnswer((_) async => seedUsages);

      // Act
      final result = await useCase.execute(query);

      // Assert - order should be maintained as returned from repository
      expect(result.fingerprints, ['third', 'first', 'second']);
    });

    test('should work with large number of seed usages', () async {
      // Arrange
      final query = ListUsedSeedsQuery();

      final seedUsages = List.generate(
        100,
        (i) => _createTestSeedUsage(
          id: i,
          fingerprint: 'fingerprint-$i',
        ),
      );

      when(mockSeedUsageRepository.getAll()).thenAnswer((_) async => seedUsages);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.fingerprints.length, 100);
      for (int i = 0; i < 100; i++) {
        expect(result.fingerprints[i], 'fingerprint-$i');
      }

      // Verify getAll was called
      verify(mockSeedUsageRepository.getAll()).called(1);
    });
  });
}

// Test helper function to create a test SeedUsage entity
SeedUsage _createTestSeedUsage({
  int? id,
  String? fingerprint,
  SeedUsagePurpose? purpose,
  String? consumerRef,
}) {
  return SeedUsage(
    id: id ?? 1,
    fingerprint: fingerprint ?? 'test-fingerprint',
    purpose: purpose ?? SeedUsagePurpose.wallet,
    consumerRef: consumerRef ?? 'test-consumer',
    createdAt: DateTime.now(),
  );
}
