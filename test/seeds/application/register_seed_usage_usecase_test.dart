import 'package:bb_mobile/core/primitives/seeds/seed_usage_purpose.dart';
import 'package:bb_mobile/features/seeds/application/ports/seed_usage_repository_port.dart';
import 'package:bb_mobile/features/seeds/application/seeds_application_errors.dart';
import 'package:bb_mobile/features/seeds/application/usecases/register_seed_usage_usecase.dart';
import 'package:bb_mobile/features/seeds/domain/entities/seed_usage_entity.dart';
import 'package:bb_mobile/features/seeds/domain/seeds_domain_errors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'register_seed_usage_usecase_test.mocks.dart';

@GenerateMocks([
  SeedUsageRepositoryPort,
])
void main() {
  late RegisterSeedUsageUseCase useCase;
  late MockSeedUsageRepositoryPort mockSeedUsageRepository;

  // Test data
  const testFingerprint = 'test-fingerprint-12345';
  const testConsumerRef = 'wallet-123';

  setUp(() {
    mockSeedUsageRepository = MockSeedUsageRepositoryPort();

    useCase = RegisterSeedUsageUseCase(
      seedUsageRepository: mockSeedUsageRepository,
    );
  });

  group('RegisterSeedUsageUseCase - Happy Path', () {
    test('should successfully register seed usage for wallet', () async {
      // Arrange
      final command = RegisterSeedUsageCommand(
        fingerprint: testFingerprint,
        purpose: SeedUsagePurpose.wallet,
        consumerRef: testConsumerRef,
      );

      when(mockSeedUsageRepository.add(
        fingerprint: anyNamed('fingerprint'),
        purpose: anyNamed('purpose'),
        consumerRef: anyNamed('consumerRef'),
      )).thenAnswer((_) async => _createTestSeedUsage());

      // Act
      await useCase.execute(command);

      // Assert - verify port interactions
      verify(mockSeedUsageRepository.add(
        fingerprint: testFingerprint,
        purpose: SeedUsagePurpose.wallet,
        consumerRef: testConsumerRef,
      )).called(1);
    });

    test('should successfully register seed usage for bip85', () async {
      // Arrange
      const bip85ConsumerRef = 'bip85-456';
      final command = RegisterSeedUsageCommand(
        fingerprint: testFingerprint,
        purpose: SeedUsagePurpose.bip85,
        consumerRef: bip85ConsumerRef,
      );

      when(mockSeedUsageRepository.add(
        fingerprint: anyNamed('fingerprint'),
        purpose: anyNamed('purpose'),
        consumerRef: anyNamed('consumerRef'),
      )).thenAnswer((_) async => _createTestSeedUsage());

      // Act
      await useCase.execute(command);

      // Assert - verify port interactions
      verify(mockSeedUsageRepository.add(
        fingerprint: testFingerprint,
        purpose: SeedUsagePurpose.bip85,
        consumerRef: bip85ConsumerRef,
      )).called(1);
    });

    test('should successfully register seed usage for nostr', () async {
      // Arrange
      const nostrConsumerRef = 'nostr-pubkey-789';
      final command = RegisterSeedUsageCommand(
        fingerprint: testFingerprint,
        purpose: SeedUsagePurpose.wallet,
        consumerRef: nostrConsumerRef,
      );

      when(mockSeedUsageRepository.add(
        fingerprint: anyNamed('fingerprint'),
        purpose: anyNamed('purpose'),
        consumerRef: anyNamed('consumerRef'),
      )).thenAnswer((_) async => _createTestSeedUsage());

      // Act
      await useCase.execute(command);

      // Assert - verify port interactions
      verify(mockSeedUsageRepository.add(
        fingerprint: testFingerprint,
        purpose: SeedUsagePurpose.wallet,
        consumerRef: nostrConsumerRef,
      )).called(1);
    });
  });

  group('RegisterSeedUsageUseCase - Error Scenarios', () {
    test('should throw BusinessRuleFailed when add throws domain error',
        () async {
      // Arrange
      final command = RegisterSeedUsageCommand(
        fingerprint: testFingerprint,
        purpose: SeedUsagePurpose.wallet,
        consumerRef: testConsumerRef,
      );

      final domainError = TestSeedsDomainError('Invalid purpose');
      when(mockSeedUsageRepository.add(
        fingerprint: anyNamed('fingerprint'),
        purpose: anyNamed('purpose'),
        consumerRef: anyNamed('consumerRef'),
      )).thenThrow(domainError);

      // Act & Assert
      await expectLater(
        () => useCase.execute(command),
        throwsA(
          isA<BusinessRuleFailed>()
              .having((e) => e.domainError, 'domainError', domainError)
              .having((e) => e.cause, 'cause', domainError),
        ),
      );

      // Verify add was called
      verify(mockSeedUsageRepository.add(
        fingerprint: anyNamed('fingerprint'),
        purpose: anyNamed('purpose'),
        consumerRef: anyNamed('consumerRef'),
      )).called(1);
    });

    test('should throw FailedToRegisterSeedUsageError when add fails',
        () async {
      // Arrange
      final command = RegisterSeedUsageCommand(
        fingerprint: testFingerprint,
        purpose: SeedUsagePurpose.wallet,
        consumerRef: testConsumerRef,
      );

      final repositoryError = Exception('Database constraint violation');
      when(mockSeedUsageRepository.add(
        fingerprint: anyNamed('fingerprint'),
        purpose: anyNamed('purpose'),
        consumerRef: anyNamed('consumerRef'),
      )).thenThrow(repositoryError);

      // Act & Assert
      await expectLater(
        () => useCase.execute(command),
        throwsA(
          isA<FailedToRegisterSeedUsageError>()
              .having((e) => e.fingerprint, 'fingerprint', testFingerprint)
              .having((e) => e.cause, 'cause', repositoryError),
        ),
      );

      // Verify add was called
      verify(mockSeedUsageRepository.add(
        fingerprint: anyNamed('fingerprint'),
        purpose: anyNamed('purpose'),
        consumerRef: anyNamed('consumerRef'),
      )).called(1);
    });

    test('should rethrow application errors without wrapping', () async {
      // Arrange
      final command = RegisterSeedUsageCommand(
        fingerprint: testFingerprint,
        purpose: SeedUsagePurpose.wallet,
        consumerRef: testConsumerRef,
      );

      final appError = SeedInUseError(testFingerprint);
      when(mockSeedUsageRepository.add(
        fingerprint: anyNamed('fingerprint'),
        purpose: anyNamed('purpose'),
        consumerRef: anyNamed('consumerRef'),
      )).thenThrow(appError);

      // Act & Assert
      await expectLater(
        () => useCase.execute(command),
        throwsA(
          isA<SeedInUseError>()
              .having((e) => e.fingerprint, 'fingerprint', testFingerprint),
        ),
      );
    });
  });

  group('RegisterSeedUsageUseCase - Verification Tests', () {
    test('should pass command properties correctly to repository', () async {
      // Arrange
      const customFingerprint = 'custom-fp-abc123';
      const customConsumerRef = 'custom-ref-456';
      final command = RegisterSeedUsageCommand(
        fingerprint: customFingerprint,
        purpose: SeedUsagePurpose.bip85,
        consumerRef: customConsumerRef,
      );

      when(mockSeedUsageRepository.add(
        fingerprint: anyNamed('fingerprint'),
        purpose: anyNamed('purpose'),
        consumerRef: anyNamed('consumerRef'),
      )).thenAnswer((_) async => _createTestSeedUsage());

      // Act
      await useCase.execute(command);

      // Assert
      verify(mockSeedUsageRepository.add(
        fingerprint: customFingerprint,
        purpose: SeedUsagePurpose.bip85,
        consumerRef: customConsumerRef,
      )).called(1);
    });

    test('should call add exactly once in happy path', () async {
      // Arrange
      final command = RegisterSeedUsageCommand(
        fingerprint: testFingerprint,
        purpose: SeedUsagePurpose.wallet,
        consumerRef: testConsumerRef,
      );

      when(mockSeedUsageRepository.add(
        fingerprint: anyNamed('fingerprint'),
        purpose: anyNamed('purpose'),
        consumerRef: anyNamed('consumerRef'),
      )).thenAnswer((_) async => _createTestSeedUsage());

      // Act
      await useCase.execute(command);

      // Assert - verify exactly one call
      verify(mockSeedUsageRepository.add(
        fingerprint: anyNamed('fingerprint'),
        purpose: anyNamed('purpose'),
        consumerRef: anyNamed('consumerRef'),
      )).called(1);

      // Verify no other interactions
      verifyNoMoreInteractions(mockSeedUsageRepository);
    });

    test('should capture all command parameters in repository call', () async {
      // Arrange
      final command = RegisterSeedUsageCommand(
        fingerprint: testFingerprint,
        purpose: SeedUsagePurpose.wallet,
        consumerRef: testConsumerRef,
      );

      String? capturedFingerprint;
      SeedUsagePurpose? capturedPurpose;
      String? capturedConsumerRef;

      when(mockSeedUsageRepository.add(
        fingerprint: anyNamed('fingerprint'),
        purpose: anyNamed('purpose'),
        consumerRef: anyNamed('consumerRef'),
      )).thenAnswer((invocation) async {
        capturedFingerprint = invocation.namedArguments[#fingerprint] as String;
        capturedPurpose = invocation.namedArguments[#purpose] as SeedUsagePurpose;
        capturedConsumerRef = invocation.namedArguments[#consumerRef] as String;
        return _createTestSeedUsage();
      });

      // Act
      await useCase.execute(command);

      // Assert
      expect(capturedFingerprint, testFingerprint);
      expect(capturedPurpose, SeedUsagePurpose.wallet);
      expect(capturedConsumerRef, testConsumerRef);
    });

    test('should handle different purposes correctly', () async {
      // Test for each purpose type
      for (final purpose in SeedUsagePurpose.values) {
        // Arrange
        reset(mockSeedUsageRepository);
        final command = RegisterSeedUsageCommand(
          fingerprint: testFingerprint,
          purpose: purpose,
          consumerRef: 'ref-for-$purpose',
        );

        when(mockSeedUsageRepository.add(
          fingerprint: anyNamed('fingerprint'),
          purpose: anyNamed('purpose'),
          consumerRef: anyNamed('consumerRef'),
        )).thenAnswer((_) async => _createTestSeedUsage());

        // Act
        await useCase.execute(command);

        // Assert
        verify(mockSeedUsageRepository.add(
          fingerprint: testFingerprint,
          purpose: purpose,
          consumerRef: 'ref-for-$purpose',
        )).called(1);
      }
    });
  });
}

// Test helper function to create a test SeedUsage entity
SeedUsage _createTestSeedUsage() {
  return SeedUsage(
    id: 1,
    fingerprint: 'test-fingerprint-12345',
    purpose: SeedUsagePurpose.wallet,
    consumerRef: 'test-consumer',
    createdAt: DateTime.now(),
  );
}
