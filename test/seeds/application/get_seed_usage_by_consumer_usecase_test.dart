import 'package:bb_mobile/core/primitives/seeds/seed_usage_purpose.dart';
import 'package:bb_mobile/features/seeds/application/ports/seed_usage_repository_port.dart';
import 'package:bb_mobile/features/seeds/application/seeds_application_errors.dart';
import 'package:bb_mobile/features/seeds/application/usecases/get_seed_usage_by_consumer_usecase.dart';
import 'package:bb_mobile/features/seeds/domain/entities/seed_usage_entity.dart';
import 'package:bb_mobile/features/seeds/domain/seeds_domain_errors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'get_seed_usage_by_consumer_usecase_test.mocks.dart';

@GenerateMocks([SeedUsageRepositoryPort])
void main() {
  late GetSeedUsageByConsumerUseCase useCase;
  late MockSeedUsageRepositoryPort mockSeedUsageRepository;

  // Test data
  const testConsumerRef = 'wallet-123';
  const testFingerprint = 'test-fingerprint-12345';

  setUp(() {
    mockSeedUsageRepository = MockSeedUsageRepositoryPort();

    useCase = GetSeedUsageByConsumerUseCase(
      seedUsageRepository: mockSeedUsageRepository,
    );
  });

  group('GetSeedUsageByConsumerUseCase - Happy Path', () {
    test('should successfully get seed usage for wallet consumer', () async {
      // Arrange
      final query = GetSeedUsageByConsumerQuery(
        purpose: SeedUsagePurpose.wallet,
        consumerRef: testConsumerRef,
      );

      final expectedUsage = _createTestSeedUsage(
        purpose: SeedUsagePurpose.wallet,
        consumerRef: testConsumerRef,
      );

      when(
        mockSeedUsageRepository.getByConsumer(
          purpose: anyNamed('purpose'),
          consumerRef: anyNamed('consumerRef'),
        ),
      ).thenAnswer((_) async => expectedUsage);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.usage, expectedUsage);
      expect(result.usage.purpose, SeedUsagePurpose.wallet);
      expect(result.usage.consumerRef, testConsumerRef);
      expect(result.usage.fingerprint, testFingerprint);

      // Verify port interactions
      verify(
        mockSeedUsageRepository.getByConsumer(
          purpose: SeedUsagePurpose.wallet,
          consumerRef: testConsumerRef,
        ),
      ).called(1);
    });

    test('should successfully get seed usage for bip85 consumer', () async {
      // Arrange
      const bip85ConsumerRef = 'bip85-456';
      final query = GetSeedUsageByConsumerQuery(
        purpose: SeedUsagePurpose.bip85,
        consumerRef: bip85ConsumerRef,
      );

      final expectedUsage = _createTestSeedUsage(
        purpose: SeedUsagePurpose.bip85,
        consumerRef: bip85ConsumerRef,
      );

      when(
        mockSeedUsageRepository.getByConsumer(
          purpose: anyNamed('purpose'),
          consumerRef: anyNamed('consumerRef'),
        ),
      ).thenAnswer((_) async => expectedUsage);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.usage, expectedUsage);
      expect(result.usage.purpose, SeedUsagePurpose.bip85);
      expect(result.usage.consumerRef, bip85ConsumerRef);

      // Verify port interactions
      verify(
        mockSeedUsageRepository.getByConsumer(
          purpose: SeedUsagePurpose.bip85,
          consumerRef: bip85ConsumerRef,
        ),
      ).called(1);
    });
  });

  group('GetSeedUsageByConsumerUseCase - Error Scenarios', () {
    test('should throw SeedUsageNotFoundError when usage is null', () async {
      // Arrange
      final query = GetSeedUsageByConsumerQuery(
        purpose: SeedUsagePurpose.wallet,
        consumerRef: testConsumerRef,
      );

      when(
        mockSeedUsageRepository.getByConsumer(
          purpose: anyNamed('purpose'),
          consumerRef: anyNamed('consumerRef'),
        ),
      ).thenAnswer((_) async => null);

      // Act & Assert
      await expectLater(
        () => useCase.execute(query),
        throwsA(
          isA<SeedUsageNotFoundError>()
              .having((e) => e.purpose, 'purpose', SeedUsagePurpose.wallet)
              .having((e) => e.consumerRef, 'consumerRef', testConsumerRef),
        ),
      );

      // Verify getByConsumer was called
      verify(
        mockSeedUsageRepository.getByConsumer(
          purpose: SeedUsagePurpose.wallet,
          consumerRef: testConsumerRef,
        ),
      ).called(1);
    });

    test(
      'should throw BusinessRuleFailed when getByConsumer throws domain error',
      () async {
        // Arrange
        final query = GetSeedUsageByConsumerQuery(
          purpose: SeedUsagePurpose.wallet,
          consumerRef: testConsumerRef,
        );

        final domainError = TestSeedsDomainError('Invalid consumer reference');
        when(
          mockSeedUsageRepository.getByConsumer(
            purpose: anyNamed('purpose'),
            consumerRef: anyNamed('consumerRef'),
          ),
        ).thenThrow(domainError);

        // Act & Assert
        await expectLater(
          () => useCase.execute(query),
          throwsA(
            isA<BusinessRuleFailed>()
                .having((e) => e.domainError, 'domainError', domainError)
                .having((e) => e.cause, 'cause', domainError),
          ),
        );

        // Verify getByConsumer was called
        verify(
          mockSeedUsageRepository.getByConsumer(
            purpose: anyNamed('purpose'),
            consumerRef: anyNamed('consumerRef'),
          ),
        ).called(1);
      },
    );

    test(
      'should throw FailedToGetSeedUsageByConsumerError when getByConsumer fails',
      () async {
        // Arrange
        final query = GetSeedUsageByConsumerQuery(
          purpose: SeedUsagePurpose.wallet,
          consumerRef: testConsumerRef,
        );

        final repositoryError = Exception('Database query failed');
        when(
          mockSeedUsageRepository.getByConsumer(
            purpose: anyNamed('purpose'),
            consumerRef: anyNamed('consumerRef'),
          ),
        ).thenThrow(repositoryError);

        // Act & Assert
        await expectLater(
          () => useCase.execute(query),
          throwsA(
            isA<FailedToGetSeedUsageByConsumerError>()
                .having((e) => e.purpose, 'purpose', SeedUsagePurpose.wallet)
                .having((e) => e.consumerRef, 'consumerRef', testConsumerRef)
                .having((e) => e.cause, 'cause', repositoryError),
          ),
        );

        // Verify getByConsumer was called
        verify(
          mockSeedUsageRepository.getByConsumer(
            purpose: anyNamed('purpose'),
            consumerRef: anyNamed('consumerRef'),
          ),
        ).called(1);
      },
    );

    test('should rethrow application errors without wrapping', () async {
      // Arrange
      final query = GetSeedUsageByConsumerQuery(
        purpose: SeedUsagePurpose.wallet,
        consumerRef: testConsumerRef,
      );

      final appError = SeedInUseError(testFingerprint);
      when(
        mockSeedUsageRepository.getByConsumer(
          purpose: anyNamed('purpose'),
          consumerRef: anyNamed('consumerRef'),
        ),
      ).thenThrow(appError);

      // Act & Assert
      await expectLater(
        () => useCase.execute(query),
        throwsA(
          isA<SeedInUseError>().having(
            (e) => e.fingerprint,
            'fingerprint',
            testFingerprint,
          ),
        ),
      );
    });
  });

  group('GetSeedUsageByConsumerUseCase - Verification Tests', () {
    test('should pass query properties correctly to repository', () async {
      // Arrange
      const customConsumerRef = 'custom-ref-xyz';
      final query = GetSeedUsageByConsumerQuery(
        purpose: SeedUsagePurpose.bip85,
        consumerRef: customConsumerRef,
      );

      final expectedUsage = _createTestSeedUsage(
        purpose: SeedUsagePurpose.bip85,
        consumerRef: customConsumerRef,
      );

      when(
        mockSeedUsageRepository.getByConsumer(
          purpose: anyNamed('purpose'),
          consumerRef: anyNamed('consumerRef'),
        ),
      ).thenAnswer((_) async => expectedUsage);

      // Act
      await useCase.execute(query);

      // Assert
      verify(
        mockSeedUsageRepository.getByConsumer(
          purpose: SeedUsagePurpose.bip85,
          consumerRef: customConsumerRef,
        ),
      ).called(1);
    });

    test('should call getByConsumer exactly once in happy path', () async {
      // Arrange
      final query = GetSeedUsageByConsumerQuery(
        purpose: SeedUsagePurpose.wallet,
        consumerRef: testConsumerRef,
      );

      final expectedUsage = _createTestSeedUsage();

      when(
        mockSeedUsageRepository.getByConsumer(
          purpose: anyNamed('purpose'),
          consumerRef: anyNamed('consumerRef'),
        ),
      ).thenAnswer((_) async => expectedUsage);

      // Act
      await useCase.execute(query);

      // Assert - verify exactly one call
      verify(
        mockSeedUsageRepository.getByConsumer(
          purpose: anyNamed('purpose'),
          consumerRef: anyNamed('consumerRef'),
        ),
      ).called(1);

      // Verify no other interactions
      verifyNoMoreInteractions(mockSeedUsageRepository);
    });

    test('should capture query parameters in repository call', () async {
      // Arrange
      final query = GetSeedUsageByConsumerQuery(
        purpose: SeedUsagePurpose.wallet,
        consumerRef: testConsumerRef,
      );

      SeedUsagePurpose? capturedPurpose;
      String? capturedConsumerRef;

      when(
        mockSeedUsageRepository.getByConsumer(
          purpose: anyNamed('purpose'),
          consumerRef: anyNamed('consumerRef'),
        ),
      ).thenAnswer((invocation) async {
        capturedPurpose =
            invocation.namedArguments[#purpose] as SeedUsagePurpose;
        capturedConsumerRef = invocation.namedArguments[#consumerRef] as String;
        return _createTestSeedUsage();
      });

      // Act
      await useCase.execute(query);

      // Assert
      expect(capturedPurpose, SeedUsagePurpose.wallet);
      expect(capturedConsumerRef, testConsumerRef);
    });

    test('should return result with usage from repository', () async {
      // Arrange
      final query = GetSeedUsageByConsumerQuery(
        purpose: SeedUsagePurpose.wallet,
        consumerRef: testConsumerRef,
      );

      final expectedUsage = _createTestSeedUsage(
        id: 999,
        fingerprint: 'unique-fingerprint',
      );

      when(
        mockSeedUsageRepository.getByConsumer(
          purpose: anyNamed('purpose'),
          consumerRef: anyNamed('consumerRef'),
        ),
      ).thenAnswer((_) async => expectedUsage);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.usage, same(expectedUsage));
      expect(result.usage.id, 999);
      expect(result.usage.fingerprint, 'unique-fingerprint');
    });

    test('should handle different purposes correctly', () async {
      // Test for each purpose type
      for (final purpose in SeedUsagePurpose.values) {
        // Arrange
        reset(mockSeedUsageRepository);
        final query = GetSeedUsageByConsumerQuery(
          purpose: purpose,
          consumerRef: 'ref-for-$purpose',
        );

        final expectedUsage = _createTestSeedUsage(
          purpose: purpose,
          consumerRef: 'ref-for-$purpose',
        );

        when(
          mockSeedUsageRepository.getByConsumer(
            purpose: anyNamed('purpose'),
            consumerRef: anyNamed('consumerRef'),
          ),
        ).thenAnswer((_) async => expectedUsage);

        // Act
        final result = await useCase.execute(query);

        // Assert
        expect(result.usage.purpose, purpose);
        verify(
          mockSeedUsageRepository.getByConsumer(
            purpose: purpose,
            consumerRef: 'ref-for-$purpose',
          ),
        ).called(1);
      }
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
    fingerprint: fingerprint ?? 'test-fingerprint-12345',
    purpose: purpose ?? SeedUsagePurpose.wallet,
    consumerRef: consumerRef ?? 'test-consumer',
    createdAt: DateTime.now(),
  );
}
