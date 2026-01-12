import 'package:bb_mobile/features/secrets/application/ports/secret_usage_repository_port.dart';
import 'package:bb_mobile/features/secrets/application/secrets_application_errors.dart';
import 'package:bb_mobile/features/secrets/application/usecases/deregister_secret_usage_usecase.dart';
import 'package:bb_mobile/features/secrets/domain/secrets_domain_errors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'deregister_secret_usage_usecase_test.mocks.dart';

@GenerateMocks([SecretUsageRepositoryPort])
void main() {
  late DeregisterSecretUsageUseCase useCase;
  late MockSecretUsageRepositoryPort mockSecretUsageRepository;

  // Test data
  const testSecretUsageId = 42;

  setUp(() {
    mockSecretUsageRepository = MockSecretUsageRepositoryPort();

    useCase = DeregisterSecretUsageUseCase(
      secretUsageRepository: mockSecretUsageRepository,
    );
  });

  group('DeregisterSecretUsageUseCase - Happy Path', () {
    test('should successfully deregister seed usage', () async {
      // Arrange
      final command = DeregisterSecretUsageCommand(
        secretUsageId: testSecretUsageId,
      );

      when(mockSecretUsageRepository.deleteById(any)).thenAnswer((_) async {
        return null;
      });

      // Act
      await useCase.execute(command);

      // Assert - verify port interactions
      verify(mockSecretUsageRepository.deleteById(testSecretUsageId)).called(1);
    });

    test(
      'should successfully deregister seed usage with different ID',
      () async {
        // Arrange
        const differentId = 123;
        final command = DeregisterSecretUsageCommand(
          secretUsageId: differentId,
        );

        when(mockSecretUsageRepository.deleteById(any)).thenAnswer((_) async {
          return null;
        });

        // Act
        await useCase.execute(command);

        // Assert - verify port interactions
        verify(mockSecretUsageRepository.deleteById(differentId)).called(1);
      },
    );
  });

  group('DeregisterSecretUsageUseCase - Error Scenarios', () {
    test(
      'should throw BusinessRuleFailed when deleteById throws domain error',
      () async {
        // Arrange
        final command = DeregisterSecretUsageCommand(
          secretUsageId: testSecretUsageId,
        );

        final domainError = TestSecretsDomainError('Invalid usage ID');
        when(mockSecretUsageRepository.deleteById(any)).thenThrow(domainError);

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
        verify(
          mockSecretUsageRepository.deleteById(testSecretUsageId),
        ).called(1);
      },
    );

    test(
      'should throw FailedToDeregisterSecretUsageError when deleteById fails',
      () async {
        // Arrange
        final command = DeregisterSecretUsageCommand(
          secretUsageId: testSecretUsageId,
        );

        final repositoryError = Exception('Database deletion failed');
        when(
          mockSecretUsageRepository.deleteById(any),
        ).thenThrow(repositoryError);

        // Act & Assert
        await expectLater(
          () => useCase.execute(command),
          throwsA(
            isA<FailedToDeregisterSecretUsageError>()
                .having(
                  (e) => e.secretUsageId,
                  'secretUsageId',
                  testSecretUsageId,
                )
                .having((e) => e.cause, 'cause', repositoryError),
          ),
        );

        // Verify deleteById was called
        verify(
          mockSecretUsageRepository.deleteById(testSecretUsageId),
        ).called(1);
      },
    );

    test('should rethrow application errors without wrapping', () async {
      // Arrange
      final command = DeregisterSecretUsageCommand(
        secretUsageId: testSecretUsageId,
      );

      final appError = SecretInUseError('test-fingerprint');
      when(mockSecretUsageRepository.deleteById(any)).thenThrow(appError);

      // Act & Assert
      await expectLater(
        () => useCase.execute(command),
        throwsA(
          isA<SecretInUseError>().having(
            (e) => e.fingerprint,
            'fingerprint',
            'test-fingerprint',
          ),
        ),
      );
    });

    test('should handle not found scenario gracefully', () async {
      // Arrange
      final command = DeregisterSecretUsageCommand(
        secretUsageId: testSecretUsageId,
      );

      final notFoundError = Exception('Secret usage not found');
      when(mockSecretUsageRepository.deleteById(any)).thenThrow(notFoundError);

      // Act & Assert
      await expectLater(
        () => useCase.execute(command),
        throwsA(
          isA<FailedToDeregisterSecretUsageError>()
              .having(
                (e) => e.secretUsageId,
                'secretUsageId',
                testSecretUsageId,
              )
              .having((e) => e.cause, 'cause', notFoundError),
        ),
      );
    });
  });

  group('DeregisterSecretUsageUseCase - Verification Tests', () {
    test('should pass correct seed usage ID to repository', () async {
      // Arrange
      const customId = 999;
      final command = DeregisterSecretUsageCommand(secretUsageId: customId);

      when(mockSecretUsageRepository.deleteById(any)).thenAnswer((_) async {
        return null;
      });

      // Act
      await useCase.execute(command);

      // Assert
      verify(mockSecretUsageRepository.deleteById(customId)).called(1);
    });

    test('should call deleteById exactly once in happy path', () async {
      // Arrange
      final command = DeregisterSecretUsageCommand(
        secretUsageId: testSecretUsageId,
      );

      when(mockSecretUsageRepository.deleteById(any)).thenAnswer((_) async {
        return null;
      });

      // Act
      await useCase.execute(command);

      // Assert - verify exactly one call
      verify(mockSecretUsageRepository.deleteById(any)).called(1);

      // Verify no other interactions
      verifyNoMoreInteractions(mockSecretUsageRepository);
    });

    test('should capture seed usage ID in repository call', () async {
      // Arrange
      const captureId = 777;
      final command = DeregisterSecretUsageCommand(secretUsageId: captureId);

      int? capturedId;
      when(mockSecretUsageRepository.deleteById(any)).thenAnswer((
        invocation,
      ) async {
        capturedId = invocation.positionalArguments[0] as int;
        return null;
      });

      // Act
      await useCase.execute(command);

      // Assert
      expect(capturedId, captureId);
    });

    test('should handle zero ID correctly', () async {
      // Arrange
      const zeroId = 0;
      final command = DeregisterSecretUsageCommand(secretUsageId: zeroId);

      when(mockSecretUsageRepository.deleteById(any)).thenAnswer((_) async {
        return null;
      });

      // Act
      await useCase.execute(command);

      // Assert
      verify(mockSecretUsageRepository.deleteById(zeroId)).called(1);
    });

    test('should handle large ID correctly', () async {
      // Arrange
      const largeId = 2147483647; // max int32
      final command = DeregisterSecretUsageCommand(secretUsageId: largeId);

      when(mockSecretUsageRepository.deleteById(any)).thenAnswer((_) async {
        return null;
      });

      // Act
      await useCase.execute(command);

      // Assert
      verify(mockSecretUsageRepository.deleteById(largeId)).called(1);
    });
  });
}
