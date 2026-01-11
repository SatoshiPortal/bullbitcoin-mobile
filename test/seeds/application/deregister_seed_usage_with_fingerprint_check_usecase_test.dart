import 'package:bb_mobile/core/primitives/seeds/seed_usage_purpose.dart';
import 'package:bb_mobile/features/seeds/application/seeds_application_errors.dart';
import 'package:bb_mobile/features/seeds/application/usecases/deregister_seed_usage_usecase.dart';
import 'package:bb_mobile/features/seeds/application/usecases/deregister_seed_usage_with_fingerprint_check_usecase.dart';
import 'package:bb_mobile/features/seeds/application/usecases/get_seed_usage_by_consumer_usecase.dart';
import 'package:bb_mobile/features/seeds/domain/entities/seed_usage_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'deregister_seed_usage_with_fingerprint_check_usecase_test.mocks.dart';

@GenerateMocks([
  GetSeedUsageByConsumerUseCase,
  DeregisterSeedUsageUseCase,
])
void main() {
  late DeregisterSeedUsageWithFingerprintCheckUseCase useCase;
  late MockGetSeedUsageByConsumerUseCase mockGetSeedUsageByConsumer;
  late MockDeregisterSeedUsageUseCase mockDeregisterSeedUsage;

  // Test data
  const testFingerprint = 'abcd1234';
  const testPurpose = SeedUsagePurpose.wallet;
  const testConsumerRef = 'wallet-123';
  const testUsageId = 42;

  final testSeedUsage = SeedUsage(
    id: testUsageId,
    fingerprint: testFingerprint,
    purpose: testPurpose,
    consumerRef: testConsumerRef,
    createdAt: DateTime(2024, 1, 1),
  );

  setUp(() {
    mockGetSeedUsageByConsumer = MockGetSeedUsageByConsumerUseCase();
    mockDeregisterSeedUsage = MockDeregisterSeedUsageUseCase();

    useCase = DeregisterSeedUsageWithFingerprintCheckUseCase(
      getSeedUsageByConsumer: mockGetSeedUsageByConsumer,
      deregisterSeedUsage: mockDeregisterSeedUsage,
    );
  });

  group('DeregisterSeedUsageWithFingerprintCheckUseCase - Happy Path', () {
    test('should successfully deregister usage when fingerprint matches',
        () async {
      // Arrange
      final command = DeregisterSeedUsageWithFingerprintCheckCommand(
        fingerprint: testFingerprint,
        purpose: testPurpose,
        consumerRef: testConsumerRef,
      );

      when(mockGetSeedUsageByConsumer.execute(any)).thenAnswer(
        (_) async => GetSeedUsageByConsumerResult(usage: testSeedUsage),
      );

      when(mockDeregisterSeedUsage.execute(any)).thenAnswer((_) async {});

      // Act
      await useCase.execute(command);

      // Assert - verify both use cases were called
      verify(
        mockGetSeedUsageByConsumer.execute(
          argThat(
            isA<GetSeedUsageByConsumerQuery>()
                .having((q) => q.purpose, 'purpose', testPurpose)
                .having((q) => q.consumerRef, 'consumerRef', testConsumerRef),
          ),
        ),
      ).called(1);

      verify(
        mockDeregisterSeedUsage.execute(
          argThat(
            isA<DeregisterSeedUsageCommand>()
                .having((c) => c.seedUsageId, 'seedUsageId', testUsageId),
          ),
        ),
      ).called(1);
    });

    test('should pass correct parameters to get usage use case', () async {
      // Arrange
      const customPurpose = SeedUsagePurpose.bip85;
      const customConsumerRef = 'bip85-456';

      final customUsage = SeedUsage(
        id: 99,
        fingerprint: testFingerprint,
        purpose: customPurpose,
        consumerRef: customConsumerRef,
        createdAt: DateTime(2024, 2, 1),
      );

      final command = DeregisterSeedUsageWithFingerprintCheckCommand(
        fingerprint: testFingerprint,
        purpose: customPurpose,
        consumerRef: customConsumerRef,
      );

      when(mockGetSeedUsageByConsumer.execute(any)).thenAnswer(
        (_) async => GetSeedUsageByConsumerResult(usage: customUsage),
      );

      when(mockDeregisterSeedUsage.execute(any)).thenAnswer((_) async {});

      // Act
      await useCase.execute(command);

      // Assert
      verify(
        mockGetSeedUsageByConsumer.execute(
          argThat(
            isA<GetSeedUsageByConsumerQuery>()
                .having((q) => q.purpose, 'purpose', customPurpose)
                .having((q) => q.consumerRef, 'consumerRef', customConsumerRef),
          ),
        ),
      ).called(1);
    });

    test('should call use cases in correct order', () async {
      // Arrange
      final command = DeregisterSeedUsageWithFingerprintCheckCommand(
        fingerprint: testFingerprint,
        purpose: testPurpose,
        consumerRef: testConsumerRef,
      );

      final callOrder = <String>[];

      when(mockGetSeedUsageByConsumer.execute(any)).thenAnswer((_) async {
        callOrder.add('get');
        return GetSeedUsageByConsumerResult(usage: testSeedUsage);
      });

      when(mockDeregisterSeedUsage.execute(any)).thenAnswer((_) async {
        callOrder.add('deregister');
      });

      // Act
      await useCase.execute(command);

      // Assert
      expect(callOrder, ['get', 'deregister']);
    });
  });

  group('DeregisterSeedUsageWithFingerprintCheckUseCase - Fingerprint Mismatch',
      () {
    test('should throw FingerprintMismatchError when fingerprints do not match',
        () async {
      // Arrange
      const wrongFingerprint = 'wrong1234';

      final usageWithDifferentFingerprint = SeedUsage(
        id: testUsageId,
        fingerprint: wrongFingerprint,
        purpose: testPurpose,
        consumerRef: testConsumerRef,
        createdAt: DateTime(2024, 1, 1),
      );

      final command = DeregisterSeedUsageWithFingerprintCheckCommand(
        fingerprint: testFingerprint,
        purpose: testPurpose,
        consumerRef: testConsumerRef,
      );

      when(mockGetSeedUsageByConsumer.execute(any)).thenAnswer(
        (_) async =>
            GetSeedUsageByConsumerResult(usage: usageWithDifferentFingerprint),
      );

      // Act & Assert
      await expectLater(
        () => useCase.execute(command),
        throwsA(
          isA<FingerprintMismatchError>()
              .having((e) => e.seedUsageId, 'seedUsageId', testUsageId)
              .having((e) => e.purpose, 'purpose', testPurpose)
              .having((e) => e.consumerRef, 'consumerRef', testConsumerRef),
        ),
      );

      // Verify get was called but deregister was not
      verify(mockGetSeedUsageByConsumer.execute(any)).called(1);
      verifyNever(mockDeregisterSeedUsage.execute(any));
    });

    test('should not call deregister when fingerprint check fails', () async {
      // Arrange
      final usageWithWrongFingerprint = SeedUsage(
        id: testUsageId,
        fingerprint: 'different-fingerprint',
        purpose: testPurpose,
        consumerRef: testConsumerRef,
        createdAt: DateTime(2024, 1, 1),
      );

      final command = DeregisterSeedUsageWithFingerprintCheckCommand(
        fingerprint: testFingerprint,
        purpose: testPurpose,
        consumerRef: testConsumerRef,
      );

      when(mockGetSeedUsageByConsumer.execute(any)).thenAnswer(
        (_) async =>
            GetSeedUsageByConsumerResult(usage: usageWithWrongFingerprint),
      );

      // Act
      try {
        await useCase.execute(command);
      } catch (_) {
        // Expected to throw
      }

      // Assert - deregister should never be called
      verifyNever(mockDeregisterSeedUsage.execute(any));
    });

    test(
        'should throw FingerprintMismatchError with correct details for different purpose',
        () async {
      // Arrange
      const wrongFingerprint = 'xyz9876';
      const customPurpose = SeedUsagePurpose.bip85;
      const customConsumerRef = 'custom-ref';

      final usageWithDifferentFingerprint = SeedUsage(
        id: 77,
        fingerprint: wrongFingerprint,
        purpose: customPurpose,
        consumerRef: customConsumerRef,
        createdAt: DateTime(2024, 3, 1),
      );

      final command = DeregisterSeedUsageWithFingerprintCheckCommand(
        fingerprint: 'expected-fingerprint',
        purpose: customPurpose,
        consumerRef: customConsumerRef,
      );

      when(mockGetSeedUsageByConsumer.execute(any)).thenAnswer(
        (_) async =>
            GetSeedUsageByConsumerResult(usage: usageWithDifferentFingerprint),
      );

      // Act & Assert
      await expectLater(
        () => useCase.execute(command),
        throwsA(
          isA<FingerprintMismatchError>()
              .having((e) => e.seedUsageId, 'seedUsageId', 77)
              .having((e) => e.purpose, 'purpose', customPurpose)
              .having((e) => e.consumerRef, 'consumerRef', customConsumerRef),
        ),
      );
    });
  });

  group('DeregisterSeedUsageWithFingerprintCheckUseCase - Error Propagation',
      () {
    test('should propagate SeedUsageNotFoundError from get usage use case',
        () async {
      // Arrange
      final command = DeregisterSeedUsageWithFingerprintCheckCommand(
        fingerprint: testFingerprint,
        purpose: testPurpose,
        consumerRef: testConsumerRef,
      );

      final notFoundError = SeedUsageNotFoundError(
        purpose: testPurpose,
        consumerRef: testConsumerRef,
      );

      when(mockGetSeedUsageByConsumer.execute(any)).thenThrow(notFoundError);

      // Act & Assert
      await expectLater(
        () => useCase.execute(command),
        throwsA(
          isA<SeedUsageNotFoundError>()
              .having((e) => e.purpose, 'purpose', testPurpose)
              .having((e) => e.consumerRef, 'consumerRef', testConsumerRef),
        ),
      );

      // Deregister should not be called
      verifyNever(mockDeregisterSeedUsage.execute(any));
    });

    test('should propagate errors from deregister use case', () async {
      // Arrange
      final command = DeregisterSeedUsageWithFingerprintCheckCommand(
        fingerprint: testFingerprint,
        purpose: testPurpose,
        consumerRef: testConsumerRef,
      );

      when(mockGetSeedUsageByConsumer.execute(any)).thenAnswer(
        (_) async => GetSeedUsageByConsumerResult(usage: testSeedUsage),
      );

      final deregisterError = FailedToDeregisterSeedUsageError(
        testUsageId,
        Exception('Database error'),
      );

      when(mockDeregisterSeedUsage.execute(any)).thenThrow(deregisterError);

      // Act & Assert
      await expectLater(
        () => useCase.execute(command),
        throwsA(
          isA<FailedToDeregisterSeedUsageError>().having(
            (e) => e.seedUsageId,
            'seedUsageId',
            testUsageId,
          ),
        ),
      );

      // Both use cases should have been called
      verify(mockGetSeedUsageByConsumer.execute(any)).called(1);
      verify(mockDeregisterSeedUsage.execute(any)).called(1);
    });

    test('should propagate generic errors from get usage use case', () async {
      // Arrange
      final command = DeregisterSeedUsageWithFingerprintCheckCommand(
        fingerprint: testFingerprint,
        purpose: testPurpose,
        consumerRef: testConsumerRef,
      );

      final getUsageError = FailedToGetSeedUsageByConsumerError(
        purpose: testPurpose,
        consumerRef: testConsumerRef,
        cause: Exception('Repository error'),
      );

      when(mockGetSeedUsageByConsumer.execute(any)).thenThrow(getUsageError);

      // Act & Assert
      await expectLater(
        () => useCase.execute(command),
        throwsA(isA<FailedToGetSeedUsageByConsumerError>()),
      );
    });
  });

  group('DeregisterSeedUsageWithFingerprintCheckUseCase - Verification Tests',
      () {
    test('should only call each use case once in happy path', () async {
      // Arrange
      final command = DeregisterSeedUsageWithFingerprintCheckCommand(
        fingerprint: testFingerprint,
        purpose: testPurpose,
        consumerRef: testConsumerRef,
      );

      when(mockGetSeedUsageByConsumer.execute(any)).thenAnswer(
        (_) async => GetSeedUsageByConsumerResult(usage: testSeedUsage),
      );

      when(mockDeregisterSeedUsage.execute(any)).thenAnswer((_) async {});

      // Act
      await useCase.execute(command);

      // Assert
      verify(mockGetSeedUsageByConsumer.execute(any)).called(1);
      verify(mockDeregisterSeedUsage.execute(any)).called(1);
      verifyNoMoreInteractions(mockGetSeedUsageByConsumer);
      verifyNoMoreInteractions(mockDeregisterSeedUsage);
    });

    test('should pass usage ID from get result to deregister command',
        () async {
      // Arrange
      const customUsageId = 999;

      final customUsage = SeedUsage(
        id: customUsageId,
        fingerprint: testFingerprint,
        purpose: testPurpose,
        consumerRef: testConsumerRef,
        createdAt: DateTime(2024, 1, 1),
      );

      final command = DeregisterSeedUsageWithFingerprintCheckCommand(
        fingerprint: testFingerprint,
        purpose: testPurpose,
        consumerRef: testConsumerRef,
      );

      when(mockGetSeedUsageByConsumer.execute(any)).thenAnswer(
        (_) async => GetSeedUsageByConsumerResult(usage: customUsage),
      );

      when(mockDeregisterSeedUsage.execute(any)).thenAnswer((_) async {});

      // Act
      await useCase.execute(command);

      // Assert
      verify(
        mockDeregisterSeedUsage.execute(
          argThat(
            isA<DeregisterSeedUsageCommand>()
                .having((c) => c.seedUsageId, 'seedUsageId', customUsageId),
          ),
        ),
      ).called(1);
    });

    test(
        'should handle case where usage exists with matching fingerprint for bip85',
        () async {
      // Arrange
      const bip85Fingerprint = 'bip85-fp';
      const bip85ConsumerRef = 'bip85-789';

      final bip85Usage = SeedUsage(
        id: 111,
        fingerprint: bip85Fingerprint,
        purpose: SeedUsagePurpose.bip85,
        consumerRef: bip85ConsumerRef,
        createdAt: DateTime(2024, 4, 1),
      );

      final command = DeregisterSeedUsageWithFingerprintCheckCommand(
        fingerprint: bip85Fingerprint,
        purpose: SeedUsagePurpose.bip85,
        consumerRef: bip85ConsumerRef,
      );

      when(mockGetSeedUsageByConsumer.execute(any)).thenAnswer(
        (_) async => GetSeedUsageByConsumerResult(usage: bip85Usage),
      );

      when(mockDeregisterSeedUsage.execute(any)).thenAnswer((_) async {});

      // Act
      await useCase.execute(command);

      // Assert
      verify(mockGetSeedUsageByConsumer.execute(any)).called(1);
      verify(mockDeregisterSeedUsage.execute(any)).called(1);
    });
  });
}
