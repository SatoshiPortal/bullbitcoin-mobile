import 'package:bb_mobile/features/seeds/application/ports/seed_usage_repository_port.dart';
import 'package:bb_mobile/features/seeds/application/seeds_application_errors.dart';
import 'package:bb_mobile/features/seeds/application/usecases/deregister_seed_usage_usecase.dart';
import 'package:bb_mobile/features/seeds/domain/seeds_domain_errors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'deregister_seed_usage_usecase_test.mocks.dart';

@GenerateMocks([
  SeedUsageRepositoryPort,
])
void main() {
  late DeregisterSeedUsageUseCase useCase;
  late MockSeedUsageRepositoryPort mockSeedUsageRepository;

  // Test data
  const testSeedUsageId = 42;

  setUp(() {
    mockSeedUsageRepository = MockSeedUsageRepositoryPort();

    useCase = DeregisterSeedUsageUseCase(
      seedUsageRepository: mockSeedUsageRepository,
    );
  });

  group('DeregisterSeedUsageUseCase - Happy Path', () {
    test('should successfully deregister seed usage', () async {
      // Arrange
      final command = DeregisterSeedUsageCommand(seedUsageId: testSeedUsageId);

      when(mockSeedUsageRepository.deleteById(any)).thenAnswer((_) async {});

      // Act
      await useCase.execute(command);

      // Assert - verify port interactions
      verify(mockSeedUsageRepository.deleteById(testSeedUsageId)).called(1);
    });

    test('should successfully deregister seed usage with different ID', () async {
      // Arrange
      const differentId = 123;
      final command = DeregisterSeedUsageCommand(seedUsageId: differentId);

      when(mockSeedUsageRepository.deleteById(any)).thenAnswer((_) async {});

      // Act
      await useCase.execute(command);

      // Assert - verify port interactions
      verify(mockSeedUsageRepository.deleteById(differentId)).called(1);
    });
  });

  group('DeregisterSeedUsageUseCase - Error Scenarios', () {
    test('should throw BusinessRuleFailed when deleteById throws domain error',
        () async {
      // Arrange
      final command = DeregisterSeedUsageCommand(seedUsageId: testSeedUsageId);

      final domainError = TestSeedsDomainError('Invalid usage ID');
      when(mockSeedUsageRepository.deleteById(any)).thenThrow(domainError);

      // Act & Assert
      await expectLater(
        () => useCase.execute(command),
        throwsA(
          isA<BusinessRuleFailed>()
              .having((e) => e.domainError, 'domainError', domainError)
              .having((e) => e.cause, 'cause', domainError),
        ),
      );

      // Verify deleteById was called
      verify(mockSeedUsageRepository.deleteById(testSeedUsageId)).called(1);
    });

    test('should throw FailedToDeregisterSeedUsageError when deleteById fails',
        () async {
      // Arrange
      final command = DeregisterSeedUsageCommand(seedUsageId: testSeedUsageId);

      final repositoryError = Exception('Database deletion failed');
      when(mockSeedUsageRepository.deleteById(any)).thenThrow(repositoryError);

      // Act & Assert
      await expectLater(
        () => useCase.execute(command),
        throwsA(
          isA<FailedToDeregisterSeedUsageError>()
              .having((e) => e.seedUsageId, 'seedUsageId', testSeedUsageId)
              .having((e) => e.cause, 'cause', repositoryError),
        ),
      );

      // Verify deleteById was called
      verify(mockSeedUsageRepository.deleteById(testSeedUsageId)).called(1);
    });

    test('should rethrow application errors without wrapping', () async {
      // Arrange
      final command = DeregisterSeedUsageCommand(seedUsageId: testSeedUsageId);

      final appError = SeedInUseError('test-fingerprint');
      when(mockSeedUsageRepository.deleteById(any)).thenThrow(appError);

      // Act & Assert
      await expectLater(
        () => useCase.execute(command),
        throwsA(
          isA<SeedInUseError>()
              .having((e) => e.fingerprint, 'fingerprint', 'test-fingerprint'),
        ),
      );
    });

    test('should handle not found scenario gracefully', () async {
      // Arrange
      final command = DeregisterSeedUsageCommand(seedUsageId: testSeedUsageId);

      final notFoundError = Exception('Seed usage not found');
      when(mockSeedUsageRepository.deleteById(any)).thenThrow(notFoundError);

      // Act & Assert
      await expectLater(
        () => useCase.execute(command),
        throwsA(
          isA<FailedToDeregisterSeedUsageError>()
              .having((e) => e.seedUsageId, 'seedUsageId', testSeedUsageId)
              .having((e) => e.cause, 'cause', notFoundError),
        ),
      );
    });
  });

  group('DeregisterSeedUsageUseCase - Verification Tests', () {
    test('should pass correct seed usage ID to repository', () async {
      // Arrange
      const customId = 999;
      final command = DeregisterSeedUsageCommand(seedUsageId: customId);

      when(mockSeedUsageRepository.deleteById(any)).thenAnswer((_) async {});

      // Act
      await useCase.execute(command);

      // Assert
      verify(mockSeedUsageRepository.deleteById(customId)).called(1);
    });

    test('should call deleteById exactly once in happy path', () async {
      // Arrange
      final command = DeregisterSeedUsageCommand(seedUsageId: testSeedUsageId);

      when(mockSeedUsageRepository.deleteById(any)).thenAnswer((_) async {});

      // Act
      await useCase.execute(command);

      // Assert - verify exactly one call
      verify(mockSeedUsageRepository.deleteById(any)).called(1);

      // Verify no other interactions
      verifyNoMoreInteractions(mockSeedUsageRepository);
    });

    test('should capture seed usage ID in repository call', () async {
      // Arrange
      const captureId = 777;
      final command = DeregisterSeedUsageCommand(seedUsageId: captureId);

      int? capturedId;
      when(mockSeedUsageRepository.deleteById(any)).thenAnswer((invocation) async {
        capturedId = invocation.positionalArguments[0] as int;
      });

      // Act
      await useCase.execute(command);

      // Assert
      expect(capturedId, captureId);
    });

    test('should handle zero ID correctly', () async {
      // Arrange
      const zeroId = 0;
      final command = DeregisterSeedUsageCommand(seedUsageId: zeroId);

      when(mockSeedUsageRepository.deleteById(any)).thenAnswer((_) async {});

      // Act
      await useCase.execute(command);

      // Assert
      verify(mockSeedUsageRepository.deleteById(zeroId)).called(1);
    });

    test('should handle large ID correctly', () async {
      // Arrange
      const largeId = 2147483647; // max int32
      final command = DeregisterSeedUsageCommand(seedUsageId: largeId);

      when(mockSeedUsageRepository.deleteById(any)).thenAnswer((_) async {});

      // Act
      await useCase.execute(command);

      // Assert
      verify(mockSeedUsageRepository.deleteById(largeId)).called(1);
    });
  });
}
