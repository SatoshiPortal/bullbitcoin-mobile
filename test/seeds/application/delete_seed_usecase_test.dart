import 'package:bb_mobile/features/seeds/application/ports/seed_secret_store_port.dart';
import 'package:bb_mobile/features/seeds/application/ports/seed_usage_repository_port.dart';
import 'package:bb_mobile/features/seeds/application/seeds_application_errors.dart';
import 'package:bb_mobile/features/seeds/application/usecases/delete_seed_usecase.dart';
import 'package:bb_mobile/features/seeds/domain/seeds_domain_errors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'delete_seed_usecase_test.mocks.dart';

@GenerateMocks([
  SeedSecretStorePort,
  SeedUsageRepositoryPort,
])
void main() {
  late DeleteSeedUseCase useCase;
  late MockSeedSecretStorePort mockSeedSecretStore;
  late MockSeedUsageRepositoryPort mockSeedUsageRepository;

  // Test data
  const testFingerprint = 'test-fingerprint-12345';

  setUp(() {
    mockSeedSecretStore = MockSeedSecretStorePort();
    mockSeedUsageRepository = MockSeedUsageRepositoryPort();

    useCase = DeleteSeedUseCase(
      seedSecretStore: mockSeedSecretStore,
      seedUsageRepository: mockSeedUsageRepository,
    );
  });

  group('DeleteSeedUseCase - Happy Path', () {
    test('should successfully delete seed when not in use', () async {
      // Arrange
      final command = DeleteSeedCommand(fingerprint: testFingerprint);

      when(mockSeedUsageRepository.isUsed(any)).thenAnswer((_) async => false);
      when(mockSeedSecretStore.delete(any)).thenAnswer((_) async {});

      // Act
      await useCase.execute(command);

      // Assert - verify port interactions
      verify(mockSeedUsageRepository.isUsed(testFingerprint)).called(1);
      verify(mockSeedSecretStore.delete(testFingerprint)).called(1);
    });
  });

  group('DeleteSeedUseCase - Error Scenarios', () {
    test('should throw SeedInUseError when seed is in use', () async {
      // Arrange
      final command = DeleteSeedCommand(fingerprint: testFingerprint);

      when(mockSeedUsageRepository.isUsed(any)).thenAnswer((_) async => true);

      // Act & Assert
      await expectLater(
        () => useCase.execute(command),
        throwsA(
          isA<SeedInUseError>()
              .having((e) => e.fingerprint, 'fingerprint', testFingerprint),
        ),
      );

      // Verify delete was never called
      verify(mockSeedUsageRepository.isUsed(testFingerprint)).called(1);
      verifyNever(mockSeedSecretStore.delete(any));
    });

    test('should throw BusinessRuleFailed when isUsed throws domain error',
        () async {
      // Arrange
      final command = DeleteSeedCommand(fingerprint: testFingerprint);

      final domainError = TestSeedsDomainError('Invalid fingerprint format');
      when(mockSeedUsageRepository.isUsed(any)).thenThrow(domainError);

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
      verifyNever(mockSeedSecretStore.delete(any));
    });

    test('should throw BusinessRuleFailed when delete throws domain error',
        () async {
      // Arrange
      final command = DeleteSeedCommand(fingerprint: testFingerprint);

      final domainError = TestSeedsDomainError('Storage constraint violated');
      when(mockSeedUsageRepository.isUsed(any)).thenAnswer((_) async => false);
      when(mockSeedSecretStore.delete(any)).thenThrow(domainError);

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
      verify(mockSeedUsageRepository.isUsed(testFingerprint)).called(1);
      verify(mockSeedSecretStore.delete(testFingerprint)).called(1);
    });

    test('should throw FailedToDeleteSeedError when isUsed fails', () async {
      // Arrange
      final command = DeleteSeedCommand(fingerprint: testFingerprint);

      final repositoryError = Exception('Database connection lost');
      when(mockSeedUsageRepository.isUsed(any)).thenThrow(repositoryError);

      // Act & Assert
      await expectLater(
        () => useCase.execute(command),
        throwsA(
          isA<FailedToDeleteSeedError>()
              .having((e) => e.fingerprint, 'fingerprint', testFingerprint)
              .having((e) => e.cause, 'cause', repositoryError),
        ),
      );

      // Verify delete was never called
      verifyNever(mockSeedSecretStore.delete(any));
    });

    test('should throw FailedToDeleteSeedError when delete fails', () async {
      // Arrange
      final command = DeleteSeedCommand(fingerprint: testFingerprint);

      final storageError = Exception('Secure storage unavailable');
      when(mockSeedUsageRepository.isUsed(any)).thenAnswer((_) async => false);
      when(mockSeedSecretStore.delete(any)).thenThrow(storageError);

      // Act & Assert
      await expectLater(
        () => useCase.execute(command),
        throwsA(
          isA<FailedToDeleteSeedError>()
              .having((e) => e.fingerprint, 'fingerprint', testFingerprint)
              .having((e) => e.cause, 'cause', storageError),
        ),
      );

      // Verify both methods were called
      verify(mockSeedUsageRepository.isUsed(testFingerprint)).called(1);
      verify(mockSeedSecretStore.delete(testFingerprint)).called(1);
    });

    test('should rethrow application errors without wrapping', () async {
      // Arrange
      final command = DeleteSeedCommand(fingerprint: testFingerprint);

      final appError = FailedToRegisterSeedUsageError(testFingerprint, null);
      when(mockSeedUsageRepository.isUsed(any)).thenThrow(appError);

      // Act & Assert
      await expectLater(
        () => useCase.execute(command),
        throwsA(
          isA<FailedToRegisterSeedUsageError>()
              .having((e) => e.fingerprint, 'fingerprint', testFingerprint),
        ),
      );
    });
  });

  group('DeleteSeedUseCase - Verification Tests', () {
    test('should call ports in correct sequence', () async {
      // Arrange
      final command = DeleteSeedCommand(fingerprint: testFingerprint);

      final callOrder = <String>[];

      when(mockSeedUsageRepository.isUsed(any)).thenAnswer((_) async {
        callOrder.add('isUsed');
        return false;
      });
      when(mockSeedSecretStore.delete(any)).thenAnswer((_) async {
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
      final command = DeleteSeedCommand(fingerprint: customFingerprint);

      when(mockSeedUsageRepository.isUsed(any)).thenAnswer((_) async => false);
      when(mockSeedSecretStore.delete(any)).thenAnswer((_) async {});

      // Act
      await useCase.execute(command);

      // Assert
      verify(mockSeedUsageRepository.isUsed(customFingerprint)).called(1);
      verify(mockSeedSecretStore.delete(customFingerprint)).called(1);
    });

    test('should call each port exactly once in happy path', () async {
      // Arrange
      final command = DeleteSeedCommand(fingerprint: testFingerprint);

      when(mockSeedUsageRepository.isUsed(any)).thenAnswer((_) async => false);
      when(mockSeedSecretStore.delete(any)).thenAnswer((_) async {});

      // Act
      await useCase.execute(command);

      // Assert - verify exactly one call each
      verify(mockSeedUsageRepository.isUsed(any)).called(1);
      verify(mockSeedSecretStore.delete(any)).called(1);

      // Verify no other interactions
      verifyNoMoreInteractions(mockSeedUsageRepository);
      verifyNoMoreInteractions(mockSeedSecretStore);
    });

    test('should check if seed is used before attempting delete', () async {
      // Arrange
      final command = DeleteSeedCommand(fingerprint: testFingerprint);

      bool deleteWasCalled = false;
      bool isUsedCalledBeforeDelete = false;

      when(mockSeedUsageRepository.isUsed(any)).thenAnswer((_) async {
        if (!deleteWasCalled) {
          isUsedCalledBeforeDelete = true;
        }
        return false;
      });
      when(mockSeedSecretStore.delete(any)).thenAnswer((_) async {
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
