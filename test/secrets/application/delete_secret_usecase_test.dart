import 'package:bb_mobile/features/secrets/application/ports/secret_store_port.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_usage_repository_port.dart';
import 'package:bb_mobile/features/secrets/application/usecases/delete_secret_usecase.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/fingerprint.dart';
import 'package:bb_mobile/features/secrets/public/secrets_facade_error.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'delete_secret_usecase_test.mocks.dart';

@GenerateMocks([SecretStorePort, SecretUsageRepositoryPort])
void main() {
  late DeleteSecretUseCase useCase;
  late MockSecretStorePort mockSecretStore;
  late MockSecretUsageRepositoryPort mockSecretUsageRepository;

  // Test data
  const testFingerprint = Fingerprint('test1234');

  setUp(() {
    mockSecretStore = MockSecretStorePort();
    mockSecretUsageRepository = MockSecretUsageRepositoryPort();

    useCase = DeleteSecretUseCase(
      secretStore: mockSecretStore,
      secretUsageRepository: mockSecretUsageRepository,
    );
  });

  group('DeleteSecretUseCase - Happy Path', () {
    test('should successfully delete seed when not in use', () async {
      // Arrange
      final command = DeleteSecretCommand(fingerprint: testFingerprint.value);

      when(
        mockSecretUsageRepository.isUsed(any),
      ).thenAnswer((_) async => false);
      when(mockSecretStore.delete(any)).thenAnswer((_) async {});

      // Act
      await useCase.execute(command);

      // Assert - verify port interactions
      verify(mockSecretUsageRepository.isUsed(testFingerprint)).called(1);
      verify(mockSecretStore.delete(testFingerprint)).called(1);
    });
  });

  group('DeleteSecretUseCase - Error Scenarios', () {
    test('should throw SecretInUseError when seed is in use', () async {
      // Arrange
      final command = DeleteSecretCommand(fingerprint: testFingerprint.value);

      when(mockSecretUsageRepository.isUsed(any)).thenAnswer((_) async => true);

      // Act & Assert
      await expectLater(
        () => useCase.execute(command),
        throwsA(isA<SecretInUseError>()),
      );

      // Verify delete was never called
      verify(mockSecretUsageRepository.isUsed(testFingerprint)).called(1);
      verifyNever(mockSecretStore.delete(any));
    });

    test(
      'should throw BusinessRuleFailed when isUsed throws domain error',
      () async {
        // Arrange
        final command = DeleteSecretCommand(fingerprint: testFingerprint);

        final domainError = TestSecretsDomainError(
          'Invalid fingerprint format',
        );
        when(mockSecretUsageRepository.isUsed(any)).thenThrow(domainError);

        // Act & Assert
        await expectLater(
          () => useCase.execute(command),
          throwsA(
            isA<BusinessRuleFailed>()
                .having((e) => e.domainError, 'domainError', domainError)
                .having((e) => e.cause, 'cause', domainError),
          ),
        );

        // Verify delete was never called
        verifyNever(mockSecretStore.delete(any));
      },
    );

    test(
      'should throw BusinessRuleFailed when delete throws domain error',
      () async {
        // Arrange
        final command = DeleteSecretCommand(fingerprint: testFingerprint);

        final domainError = TestSecretsDomainError(
          'Storage constraint violated',
        );
        when(
          mockSecretUsageRepository.isUsed(any),
        ).thenAnswer((_) async => false);
        when(mockSecretStore.delete(any)).thenThrow(domainError);

        // Act & Assert
        await expectLater(
          () => useCase.execute(command),
          throwsA(
            isA<BusinessRuleFailed>()
                .having((e) => e.domainError, 'domainError', domainError)
                .having((e) => e.cause, 'cause', domainError),
          ),
        );

        // Verify both methods were called
        verify(mockSecretUsageRepository.isUsed(testFingerprint)).called(1);
        verify(mockSecretStore.delete(testFingerprint)).called(1);
      },
    );

    test('should throw FailedToDeleteSecretError when isUsed fails', () async {
      // Arrange
      final command = DeleteSecretCommand(fingerprint: testFingerprint);

      final repositoryError = Exception('Database connection lost');
      when(mockSecretUsageRepository.isUsed(any)).thenThrow(repositoryError);

      // Act & Assert
      await expectLater(
        () => useCase.execute(command),
        throwsA(
          isA<FailedToDeleteSecretError>()
              .having((e) => e.fingerprint, 'fingerprint', testFingerprint)
              .having((e) => e.cause, 'cause', repositoryError),
        ),
      );

      // Verify delete was never called
      verifyNever(mockSecretStore.delete(any));
    });

    test('should throw FailedToDeleteSecretError when delete fails', () async {
      // Arrange
      final command = DeleteSecretCommand(fingerprint: testFingerprint);

      final storageError = Exception('Secure storage unavailable');
      when(
        mockSecretUsageRepository.isUsed(any),
      ).thenAnswer((_) async => false);
      when(mockSecretStore.delete(any)).thenThrow(storageError);

      // Act & Assert
      await expectLater(
        () => useCase.execute(command),
        throwsA(
          isA<FailedToDeleteSecretError>()
              .having((e) => e.fingerprint, 'fingerprint', testFingerprint)
              .having((e) => e.cause, 'cause', storageError),
        ),
      );

      // Verify both methods were called
      verify(mockSecretUsageRepository.isUsed(testFingerprint)).called(1);
      verify(mockSecretStore.delete(testFingerprint)).called(1);
    });

    test('should rethrow application errors without wrapping', () async {
      // Arrange
      final command = DeleteSecretCommand(fingerprint: testFingerprint);

      final appError = SecretInUseError(testFingerprint);
      when(mockSecretUsageRepository.isUsed(any)).thenThrow(appError);

      // Act & Assert
      await expectLater(
        () => useCase.execute(command),
        throwsA(
          isA<SecretInUseError>().having(
            (e) => e.fingerprint,
            'fingerprint',
            testFingerprint,
          ),
        ),
      );
    });
  });

  group('DeleteSecretUseCase - Verification Tests', () {
    test('should call ports in correct sequence', () async {
      // Arrange
      final command = DeleteSecretCommand(fingerprint: testFingerprint);

      final callOrder = <String>[];

      when(mockSecretUsageRepository.isUsed(any)).thenAnswer((_) async {
        callOrder.add('isUsed');
        return false;
      });
      when(mockSecretStore.delete(any)).thenAnswer((_) async {
        callOrder.add('delete');
      });

      // Act
      await useCase.execute(command);

      // Assert - verify exact order
      expect(callOrder, ['isUsed', 'delete']);
    });

    test('should pass correct fingerprint to both ports', () async {
      // Arrange
      const customFingerprint = 'custom-fp-xyz789';
      final command = DeleteSecretCommand(fingerprint: customFingerprint);

      when(
        mockSecretUsageRepository.isUsed(any),
      ).thenAnswer((_) async => false);
      when(mockSecretStore.delete(any)).thenAnswer((_) async {});

      // Act
      await useCase.execute(command);

      // Assert
      verify(mockSecretUsageRepository.isUsed(customFingerprint)).called(1);
      verify(mockSecretStore.delete(customFingerprint)).called(1);
    });

    test('should call each port exactly once in happy path', () async {
      // Arrange
      final command = DeleteSecretCommand(fingerprint: testFingerprint);

      when(
        mockSecretUsageRepository.isUsed(any),
      ).thenAnswer((_) async => false);
      when(mockSecretStore.delete(any)).thenAnswer((_) async {});

      // Act
      await useCase.execute(command);

      // Assert - verify exactly one call each
      verify(mockSecretUsageRepository.isUsed(any)).called(1);
      verify(mockSecretStore.delete(any)).called(1);

      // Verify no other interactions
      verifyNoMoreInteractions(mockSecretUsageRepository);
      verifyNoMoreInteractions(mockSecretStore);
    });

    test('should check if seed is used before attempting delete', () async {
      // Arrange
      final command = DeleteSecretCommand(fingerprint: testFingerprint);

      bool deleteWasCalled = false;
      bool isUsedCalledBeforeDelete = false;

      when(mockSecretUsageRepository.isUsed(any)).thenAnswer((_) async {
        if (!deleteWasCalled) {
          isUsedCalledBeforeDelete = true;
        }
        return false;
      });
      when(mockSecretStore.delete(any)).thenAnswer((_) async {
        deleteWasCalled = true;
      });

      // Act
      await useCase.execute(command);

      // Assert
      expect(isUsedCalledBeforeDelete, isTrue);
      expect(deleteWasCalled, isTrue);
    });
  });
}
