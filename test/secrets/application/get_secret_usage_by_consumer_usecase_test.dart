import 'package:bb_mobile/features/secrets/domain/secret_usage_purpose.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_usage_repository_port.dart';
import 'package:bb_mobile/features/secrets/application/secrets_application_error.dart';
import 'package:bb_mobile/features/secrets/application/usecases/get_secret_usage_by_consumer_usecase.dart';
import 'package:bb_mobile/features/secrets/domain/entities/secret_usage_entity.dart';
import 'package:bb_mobile/features/secrets/domain/secrets_domain_error.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'get_secret_usage_by_consumer_usecase_test.mocks.dart';

@GenerateMocks([SecretUsageRepositoryPort])
void main() {
  late GetSecretUsageByConsumerUseCase useCase;
  late MockSecretUsageRepositoryPort mockSecretUsageRepository;

  // Test data
  const testConsumerRef = 'wallet-123';
  const testFingerprint = 'test-fingerprint-12345';

  setUp(() {
    mockSecretUsageRepository = MockSecretUsageRepositoryPort();

    useCase = GetSecretUsageByConsumerUseCase(
      secretUsageRepository: mockSecretUsageRepository,
    );
  });

  group('GetSecretUsageByConsumerUseCase - Happy Path', () {
    test('should successfully get secret usage for wallet consumer', () async {
      // Arrange
      final query = GetSecretUsageByConsumerQuery(
        purpose: SecretUsagePurpose.wallet,
        consumerRef: testConsumerRef,
      );

      final expectedUsage = _createTestSecretUsage(
        purpose: SecretUsagePurpose.wallet,
        consumerRef: testConsumerRef,
      );

      when(
        mockSecretUsageRepository.getByConsumer(
          purpose: anyNamed('purpose'),
          consumerRef: anyNamed('consumerRef'),
        ),
      ).thenAnswer((_) async => expectedUsage);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.usage, expectedUsage);
      expect(result.usage.purpose, SecretUsagePurpose.wallet);
      expect(result.usage.consumerRef, testConsumerRef);
      expect(result.usage.fingerprint, testFingerprint);

      // Verify port interactions
      verify(
        mockSecretUsageRepository.getByConsumer(
          purpose: SecretUsagePurpose.wallet,
          consumerRef: testConsumerRef,
        ),
      ).called(1);
    });

    test('should successfully get secret usage for bip85 consumer', () async {
      // Arrange
      const bip85ConsumerRef = 'bip85-456';
      final query = GetSecretUsageByConsumerQuery(
        purpose: SecretUsagePurpose.bip85,
        consumerRef: bip85ConsumerRef,
      );

      final expectedUsage = _createTestSecretUsage(
        purpose: SecretUsagePurpose.bip85,
        consumerRef: bip85ConsumerRef,
      );

      when(
        mockSecretUsageRepository.getByConsumer(
          purpose: anyNamed('purpose'),
          consumerRef: anyNamed('consumerRef'),
        ),
      ).thenAnswer((_) async => expectedUsage);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.usage, expectedUsage);
      expect(result.usage.purpose, SecretUsagePurpose.bip85);
      expect(result.usage.consumerRef, bip85ConsumerRef);

      // Verify port interactions
      verify(
        mockSecretUsageRepository.getByConsumer(
          purpose: SecretUsagePurpose.bip85,
          consumerRef: bip85ConsumerRef,
        ),
      ).called(1);
    });
  });

  group('GetSecretUsageByConsumerUseCase - Error Scenarios', () {
    test('should throw SecretUsageNotFoundError when usage is null', () async {
      // Arrange
      final query = GetSecretUsageByConsumerQuery(
        purpose: SecretUsagePurpose.wallet,
        consumerRef: testConsumerRef,
      );

      when(
        mockSecretUsageRepository.getByConsumer(
          purpose: anyNamed('purpose'),
          consumerRef: anyNamed('consumerRef'),
        ),
      ).thenAnswer((_) async => null);

      // Act & Assert
      await expectLater(
        () => useCase.execute(query),
        throwsA(
          isA<SecretUsageNotFoundError>()
              .having((e) => e.purpose, 'purpose', SecretUsagePurpose.wallet)
              .having((e) => e.consumerRef, 'consumerRef', testConsumerRef),
        ),
      );

      // Verify getByConsumer was called
      verify(
        mockSecretUsageRepository.getByConsumer(
          purpose: SecretUsagePurpose.wallet,
          consumerRef: testConsumerRef,
        ),
      ).called(1);
    });

    test(
      'should throw BusinessRuleFailed when getByConsumer throws domain error',
      () async {
        // Arrange
        final query = GetSecretUsageByConsumerQuery(
          purpose: SecretUsagePurpose.wallet,
          consumerRef: testConsumerRef,
        );

        final domainError = TestSecretsDomainError(
          'Invalid consumer reference',
        );
        when(
          mockSecretUsageRepository.getByConsumer(
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
          mockSecretUsageRepository.getByConsumer(
            purpose: anyNamed('purpose'),
            consumerRef: anyNamed('consumerRef'),
          ),
        ).called(1);
      },
    );

    test(
      'should throw FailedToGetSecretUsageByConsumerError when getByConsumer fails',
      () async {
        // Arrange
        final query = GetSecretUsageByConsumerQuery(
          purpose: SecretUsagePurpose.wallet,
          consumerRef: testConsumerRef,
        );

        final repositoryError = Exception('Database query failed');
        when(
          mockSecretUsageRepository.getByConsumer(
            purpose: anyNamed('purpose'),
            consumerRef: anyNamed('consumerRef'),
          ),
        ).thenThrow(repositoryError);

        // Act & Assert
        await expectLater(
          () => useCase.execute(query),
          throwsA(
            isA<FailedToGetSecretUsageByConsumerError>()
                .having((e) => e.purpose, 'purpose', SecretUsagePurpose.wallet)
                .having((e) => e.consumerRef, 'consumerRef', testConsumerRef)
                .having((e) => e.cause, 'cause', repositoryError),
          ),
        );

        // Verify getByConsumer was called
        verify(
          mockSecretUsageRepository.getByConsumer(
            purpose: anyNamed('purpose'),
            consumerRef: anyNamed('consumerRef'),
          ),
        ).called(1);
      },
    );

    test('should rethrow application errors without wrapping', () async {
      // Arrange
      final query = GetSecretUsageByConsumerQuery(
        purpose: SecretUsagePurpose.wallet,
        consumerRef: testConsumerRef,
      );

      final appError = SecretInUseError(testFingerprint);
      when(
        mockSecretUsageRepository.getByConsumer(
          purpose: anyNamed('purpose'),
          consumerRef: anyNamed('consumerRef'),
        ),
      ).thenThrow(appError);

      // Act & Assert
      await expectLater(
        () => useCase.execute(query),
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

  group('GetSecretUsageByConsumerUseCase - Verification Tests', () {
    test('should pass query properties correctly to repository', () async {
      // Arrange
      const customConsumerRef = 'custom-ref-xyz';
      final query = GetSecretUsageByConsumerQuery(
        purpose: SecretUsagePurpose.bip85,
        consumerRef: customConsumerRef,
      );

      final expectedUsage = _createTestSecretUsage(
        purpose: SecretUsagePurpose.bip85,
        consumerRef: customConsumerRef,
      );

      when(
        mockSecretUsageRepository.getByConsumer(
          purpose: anyNamed('purpose'),
          consumerRef: anyNamed('consumerRef'),
        ),
      ).thenAnswer((_) async => expectedUsage);

      // Act
      await useCase.execute(query);

      // Assert
      verify(
        mockSecretUsageRepository.getByConsumer(
          purpose: SecretUsagePurpose.bip85,
          consumerRef: customConsumerRef,
        ),
      ).called(1);
    });

    test('should call getByConsumer exactly once in happy path', () async {
      // Arrange
      final query = GetSecretUsageByConsumerQuery(
        purpose: SecretUsagePurpose.wallet,
        consumerRef: testConsumerRef,
      );

      final expectedUsage = _createTestSecretUsage();

      when(
        mockSecretUsageRepository.getByConsumer(
          purpose: anyNamed('purpose'),
          consumerRef: anyNamed('consumerRef'),
        ),
      ).thenAnswer((_) async => expectedUsage);

      // Act
      await useCase.execute(query);

      // Assert - verify exactly one call
      verify(
        mockSecretUsageRepository.getByConsumer(
          purpose: anyNamed('purpose'),
          consumerRef: anyNamed('consumerRef'),
        ),
      ).called(1);

      // Verify no other interactions
      verifyNoMoreInteractions(mockSecretUsageRepository);
    });

    test('should capture query parameters in repository call', () async {
      // Arrange
      final query = GetSecretUsageByConsumerQuery(
        purpose: SecretUsagePurpose.wallet,
        consumerRef: testConsumerRef,
      );

      SecretUsagePurpose? capturedPurpose;
      String? capturedConsumerRef;

      when(
        mockSecretUsageRepository.getByConsumer(
          purpose: anyNamed('purpose'),
          consumerRef: anyNamed('consumerRef'),
        ),
      ).thenAnswer((invocation) async {
        capturedPurpose =
            invocation.namedArguments[#purpose] as SecretUsagePurpose;
        capturedConsumerRef = invocation.namedArguments[#consumerRef] as String;
        return _createTestSecretUsage();
      });

      // Act
      await useCase.execute(query);

      // Assert
      expect(capturedPurpose, SecretUsagePurpose.wallet);
      expect(capturedConsumerRef, testConsumerRef);
    });

    test('should return result with usage from repository', () async {
      // Arrange
      final query = GetSecretUsageByConsumerQuery(
        purpose: SecretUsagePurpose.wallet,
        consumerRef: testConsumerRef,
      );

      final expectedUsage = _createTestSecretUsage(
        id: 999,
        fingerprint: 'unique-fingerprint',
      );

      when(
        mockSecretUsageRepository.getByConsumer(
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
      for (final purpose in SecretUsagePurpose.values) {
        // Arrange
        reset(mockSecretUsageRepository);
        final query = GetSecretUsageByConsumerQuery(
          purpose: purpose,
          consumerRef: 'ref-for-$purpose',
        );

        final expectedUsage = _createTestSecretUsage(
          purpose: purpose,
          consumerRef: 'ref-for-$purpose',
        );

        when(
          mockSecretUsageRepository.getByConsumer(
            purpose: anyNamed('purpose'),
            consumerRef: anyNamed('consumerRef'),
          ),
        ).thenAnswer((_) async => expectedUsage);

        // Act
        final result = await useCase.execute(query);

        // Assert
        expect(result.usage.purpose, purpose);
        verify(
          mockSecretUsageRepository.getByConsumer(
            purpose: purpose,
            consumerRef: 'ref-for-$purpose',
          ),
        ).called(1);
      }
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
    fingerprint: fingerprint ?? 'test-fingerprint-12345',
    purpose: purpose ?? SecretUsagePurpose.wallet,
    consumerRef: consumerRef ?? 'test-consumer',
    createdAt: DateTime.now(),
  );
}
