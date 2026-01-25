import 'package:bb_mobile/features/secrets/domain/secret_usage_purpose.dart';
import 'package:bb_mobile/features/secrets/application/secrets_application_errors.dart';
import 'package:bb_mobile/features/secrets/application/usecases/deregister_secret_usage_usecase.dart';
import 'package:bb_mobile/features/secrets/application/usecases/deregister_secret_usage_with_fingerprint_check_usecase.dart';
import 'package:bb_mobile/features/secrets/application/usecases/get_secret_usage_by_consumer_usecase.dart';
import 'package:bb_mobile/features/secrets/domain/entities/secret_usage_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'deregister_secret_usage_with_fingerprint_check_usecase_test.mocks.dart';

@GenerateMocks([GetSecretUsageByConsumerUseCase, DeregisterSecretUsageUseCase])
void main() {
  late DeregisterSecretUsageWithFingerprintCheckUseCase useCase;
  late MockGetSecretUsageByConsumerUseCase mockGetSecretUsageByConsumer;
  late MockDeregisterSecretUsageUseCase mockDeregisterSecretUsage;

  // Test data
  const testFingerprint = 'abcd1234';
  const testPurpose = SecretUsagePurpose.wallet;
  const testConsumerRef = 'wallet-123';
  const testUsageId = 42;

  final testSecretUsage = SecretUsage(
    id: testUsageId,
    fingerprint: testFingerprint,
    purpose: testPurpose,
    consumerRef: testConsumerRef,
    createdAt: DateTime(2024, 1, 1),
  );

  setUp(() {
    mockGetSecretUsageByConsumer = MockGetSecretUsageByConsumerUseCase();
    mockDeregisterSecretUsage = MockDeregisterSecretUsageUseCase();

    useCase = DeregisterSecretUsageWithFingerprintCheckUseCase(
      getSecretUsageByConsumer: mockGetSecretUsageByConsumer,
      deregisterSecretUsage: mockDeregisterSecretUsage,
    );
  });

  group('DeregisterSecretUsageWithFingerprintCheckUseCase - Happy Path', () {
    test(
      'should successfully deregister usage when fingerprint matches',
      () async {
        // Arrange
        final command = DeregisterSecretUsageWithFingerprintCheckCommand(
          fingerprint: testFingerprint,
          purpose: testPurpose,
          consumerRef: testConsumerRef,
        );

        when(mockGetSecretUsageByConsumer.execute(any)).thenAnswer(
          (_) async => GetSecretUsageByConsumerResult(usage: testSecretUsage),
        );

        when(mockDeregisterSecretUsage.execute(any)).thenAnswer((_) async {
          return null;
        });

        // Act
        await useCase.execute(command);

        // Assert - verify both use cases were called
        verify(
          mockGetSecretUsageByConsumer.execute(
            argThat(
              isA<GetSecretUsageByConsumerQuery>()
                  .having((q) => q.purpose, 'purpose', testPurpose)
                  .having((q) => q.consumerRef, 'consumerRef', testConsumerRef),
            ),
          ),
        ).called(1);

        verify(
          mockDeregisterSecretUsage.execute(
            argThat(
              isA<DeregisterSecretUsageCommand>().having(
                (c) => c.secretUsageId,
                'secretUsageId',
                testUsageId,
              ),
            ),
          ),
        ).called(1);
      },
    );

    test('should pass correct parameters to get usage use case', () async {
      // Arrange
      const customPurpose = SecretUsagePurpose.bip85;
      const customConsumerRef = 'bip85-456';

      final customUsage = SecretUsage(
        id: 99,
        fingerprint: testFingerprint,
        purpose: customPurpose,
        consumerRef: customConsumerRef,
        createdAt: DateTime(2024, 2, 1),
      );

      final command = DeregisterSecretUsageWithFingerprintCheckCommand(
        fingerprint: testFingerprint,
        purpose: customPurpose,
        consumerRef: customConsumerRef,
      );

      when(mockGetSecretUsageByConsumer.execute(any)).thenAnswer(
        (_) async => GetSecretUsageByConsumerResult(usage: customUsage),
      );

      when(mockDeregisterSecretUsage.execute(any)).thenAnswer((_) async {
        return null;
      });

      // Act
      await useCase.execute(command);

      // Assert
      verify(
        mockGetSecretUsageByConsumer.execute(
          argThat(
            isA<GetSecretUsageByConsumerQuery>()
                .having((q) => q.purpose, 'purpose', customPurpose)
                .having((q) => q.consumerRef, 'consumerRef', customConsumerRef),
          ),
        ),
      ).called(1);
    });

    test('should call use cases in correct order', () async {
      // Arrange
      final command = DeregisterSecretUsageWithFingerprintCheckCommand(
        fingerprint: testFingerprint,
        purpose: testPurpose,
        consumerRef: testConsumerRef,
      );

      final callOrder = <String>[];

      when(mockGetSecretUsageByConsumer.execute(any)).thenAnswer((_) async {
        callOrder.add('get');
        return GetSecretUsageByConsumerResult(usage: testSecretUsage);
      });

      when(mockDeregisterSecretUsage.execute(any)).thenAnswer((_) async {
        callOrder.add('deregister');
        return null;
      });

      // Act
      await useCase.execute(command);

      // Assert
      expect(callOrder, ['get', 'deregister']);
    });
  });

  group(
    'DeregisterSecretUsageWithFingerprintCheckUseCase - Fingerprint Mismatch',
    () {
      test(
        'should throw FingerprintMismatchError when fingerprints do not match',
        () async {
          // Arrange
          const wrongFingerprint = 'wrong1234';

          final usageWithDifferentFingerprint = SecretUsage(
            id: testUsageId,
            fingerprint: wrongFingerprint,
            purpose: testPurpose,
            consumerRef: testConsumerRef,
            createdAt: DateTime(2024, 1, 1),
          );

          final command = DeregisterSecretUsageWithFingerprintCheckCommand(
            fingerprint: testFingerprint,
            purpose: testPurpose,
            consumerRef: testConsumerRef,
          );

          when(mockGetSecretUsageByConsumer.execute(any)).thenAnswer(
            (_) async => GetSecretUsageByConsumerResult(
              usage: usageWithDifferentFingerprint,
            ),
          );

          // Act & Assert
          await expectLater(
            () => useCase.execute(command),
            throwsA(
              isA<FingerprintMismatchError>()
                  .having((e) => e.secretUsageId, 'secretUsageId', testUsageId)
                  .having((e) => e.purpose, 'purpose', testPurpose)
                  .having((e) => e.consumerRef, 'consumerRef', testConsumerRef),
            ),
          );

          // Verify get was called but deregister was not
          verify(mockGetSecretUsageByConsumer.execute(any)).called(1);
          verifyNever(mockDeregisterSecretUsage.execute(any));
        },
      );

      test('should not call deregister when fingerprint check fails', () async {
        // Arrange
        final usageWithWrongFingerprint = SecretUsage(
          id: testUsageId,
          fingerprint: 'different-fingerprint',
          purpose: testPurpose,
          consumerRef: testConsumerRef,
          createdAt: DateTime(2024, 1, 1),
        );

        final command = DeregisterSecretUsageWithFingerprintCheckCommand(
          fingerprint: testFingerprint,
          purpose: testPurpose,
          consumerRef: testConsumerRef,
        );

        when(mockGetSecretUsageByConsumer.execute(any)).thenAnswer(
          (_) async =>
              GetSecretUsageByConsumerResult(usage: usageWithWrongFingerprint),
        );

        // Act
        try {
          await useCase.execute(command);
        } catch (_) {
          // Expected to throw
        }

        // Assert - deregister should never be called
        verifyNever(mockDeregisterSecretUsage.execute(any));
      });

      test(
        'should throw FingerprintMismatchError with correct details for different purpose',
        () async {
          // Arrange
          const wrongFingerprint = 'xyz9876';
          const customPurpose = SecretUsagePurpose.bip85;
          const customConsumerRef = 'custom-ref';

          final usageWithDifferentFingerprint = SecretUsage(
            id: 77,
            fingerprint: wrongFingerprint,
            purpose: customPurpose,
            consumerRef: customConsumerRef,
            createdAt: DateTime(2024, 3, 1),
          );

          final command = DeregisterSecretUsageWithFingerprintCheckCommand(
            fingerprint: 'expected-fingerprint',
            purpose: customPurpose,
            consumerRef: customConsumerRef,
          );

          when(mockGetSecretUsageByConsumer.execute(any)).thenAnswer(
            (_) async => GetSecretUsageByConsumerResult(
              usage: usageWithDifferentFingerprint,
            ),
          );

          // Act & Assert
          await expectLater(
            () => useCase.execute(command),
            throwsA(
              isA<FingerprintMismatchError>()
                  .having((e) => e.secretUsageId, 'secretUsageId', 77)
                  .having((e) => e.purpose, 'purpose', customPurpose)
                  .having(
                    (e) => e.consumerRef,
                    'consumerRef',
                    customConsumerRef,
                  ),
            ),
          );
        },
      );
    },
  );

  group(
    'DeregisterSecretUsageWithFingerprintCheckUseCase - Error Propagation',
    () {
      test(
        'should propagate SecretUsageNotFoundError from get usage use case',
        () async {
          // Arrange
          final command = DeregisterSecretUsageWithFingerprintCheckCommand(
            fingerprint: testFingerprint,
            purpose: testPurpose,
            consumerRef: testConsumerRef,
          );

          final notFoundError = SecretUsageNotFoundError(
            purpose: testPurpose,
            consumerRef: testConsumerRef,
          );

          when(
            mockGetSecretUsageByConsumer.execute(any),
          ).thenThrow(notFoundError);

          // Act & Assert
          await expectLater(
            () => useCase.execute(command),
            throwsA(
              isA<SecretUsageNotFoundError>()
                  .having((e) => e.purpose, 'purpose', testPurpose)
                  .having((e) => e.consumerRef, 'consumerRef', testConsumerRef),
            ),
          );

          // Deregister should not be called
          verifyNever(mockDeregisterSecretUsage.execute(any));
        },
      );

      test('should propagate errors from deregister use case', () async {
        // Arrange
        final command = DeregisterSecretUsageWithFingerprintCheckCommand(
          fingerprint: testFingerprint,
          purpose: testPurpose,
          consumerRef: testConsumerRef,
        );

        when(mockGetSecretUsageByConsumer.execute(any)).thenAnswer(
          (_) async => GetSecretUsageByConsumerResult(usage: testSecretUsage),
        );

        final deregisterError = FailedToDeregisterSecretUsageError(
          testUsageId,
          Exception('Database error'),
        );

        when(mockDeregisterSecretUsage.execute(any)).thenThrow(deregisterError);

        // Act & Assert
        await expectLater(
          () => useCase.execute(command),
          throwsA(
            isA<FailedToDeregisterSecretUsageError>().having(
              (e) => e.secretUsageId,
              'secretUsageId',
              testUsageId,
            ),
          ),
        );

        // Both use cases should have been called
        verify(mockGetSecretUsageByConsumer.execute(any)).called(1);
        verify(mockDeregisterSecretUsage.execute(any)).called(1);
      });

      test('should propagate generic errors from get usage use case', () async {
        // Arrange
        final command = DeregisterSecretUsageWithFingerprintCheckCommand(
          fingerprint: testFingerprint,
          purpose: testPurpose,
          consumerRef: testConsumerRef,
        );

        final getUsageError = FailedToGetSecretUsageByConsumerError(
          purpose: testPurpose,
          consumerRef: testConsumerRef,
          cause: Exception('Repository error'),
        );

        when(
          mockGetSecretUsageByConsumer.execute(any),
        ).thenThrow(getUsageError);

        // Act & Assert
        await expectLater(
          () => useCase.execute(command),
          throwsA(isA<FailedToGetSecretUsageByConsumerError>()),
        );
      });
    },
  );

  group(
    'DeregisterSecretUsageWithFingerprintCheckUseCase - Verification Tests',
    () {
      test('should only call each use case once in happy path', () async {
        // Arrange
        final command = DeregisterSecretUsageWithFingerprintCheckCommand(
          fingerprint: testFingerprint,
          purpose: testPurpose,
          consumerRef: testConsumerRef,
        );

        when(mockGetSecretUsageByConsumer.execute(any)).thenAnswer(
          (_) async => GetSecretUsageByConsumerResult(usage: testSecretUsage),
        );

        when(mockDeregisterSecretUsage.execute(any)).thenAnswer((_) async {
          return null;
        });

        // Act
        await useCase.execute(command);

        // Assert
        verify(mockGetSecretUsageByConsumer.execute(any)).called(1);
        verify(mockDeregisterSecretUsage.execute(any)).called(1);
        verifyNoMoreInteractions(mockGetSecretUsageByConsumer);
        verifyNoMoreInteractions(mockDeregisterSecretUsage);
      });

      test(
        'should pass usage ID from get result to deregister command',
        () async {
          // Arrange
          const customUsageId = 999;

          final customUsage = SecretUsage(
            id: customUsageId,
            fingerprint: testFingerprint,
            purpose: testPurpose,
            consumerRef: testConsumerRef,
            createdAt: DateTime(2024, 1, 1),
          );

          final command = DeregisterSecretUsageWithFingerprintCheckCommand(
            fingerprint: testFingerprint,
            purpose: testPurpose,
            consumerRef: testConsumerRef,
          );

          when(mockGetSecretUsageByConsumer.execute(any)).thenAnswer(
            (_) async => GetSecretUsageByConsumerResult(usage: customUsage),
          );

          when(mockDeregisterSecretUsage.execute(any)).thenAnswer((_) async {
            return null;
          });

          // Act
          await useCase.execute(command);

          // Assert
          verify(
            mockDeregisterSecretUsage.execute(
              argThat(
                isA<DeregisterSecretUsageCommand>().having(
                  (c) => c.secretUsageId,
                  'secretUsageId',
                  customUsageId,
                ),
              ),
            ),
          ).called(1);
        },
      );

      test(
        'should handle case where usage exists with matching fingerprint for bip85',
        () async {
          // Arrange
          const bip85Fingerprint = 'bip85-fp';
          const bip85ConsumerRef = 'bip85-789';

          final bip85Usage = SecretUsage(
            id: 111,
            fingerprint: bip85Fingerprint,
            purpose: SecretUsagePurpose.bip85,
            consumerRef: bip85ConsumerRef,
            createdAt: DateTime(2024, 4, 1),
          );

          final command = DeregisterSecretUsageWithFingerprintCheckCommand(
            fingerprint: bip85Fingerprint,
            purpose: SecretUsagePurpose.bip85,
            consumerRef: bip85ConsumerRef,
          );

          when(mockGetSecretUsageByConsumer.execute(any)).thenAnswer(
            (_) async => GetSecretUsageByConsumerResult(usage: bip85Usage),
          );

          when(mockDeregisterSecretUsage.execute(any)).thenAnswer((_) async {
            return null;
          });

          // Act
          await useCase.execute(command);

          // Assert
          verify(mockGetSecretUsageByConsumer.execute(any)).called(1);
          verify(mockDeregisterSecretUsage.execute(any)).called(1);
        },
      );
    },
  );
}
