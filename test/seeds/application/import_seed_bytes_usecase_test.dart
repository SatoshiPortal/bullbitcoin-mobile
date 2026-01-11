import 'dart:typed_data';

import 'package:bb_mobile/core/primitives/seeds/seed_secret.dart';
import 'package:bb_mobile/core/primitives/seeds/seed_usage_purpose.dart';
import 'package:bb_mobile/features/seeds/application/ports/seed_crypto_port.dart';
import 'package:bb_mobile/features/seeds/application/ports/seed_secret_store_port.dart';
import 'package:bb_mobile/features/seeds/application/ports/seed_usage_repository_port.dart';
import 'package:bb_mobile/features/seeds/application/seeds_application_errors.dart';
import 'package:bb_mobile/features/seeds/application/usecases/import_seed_bytes_usecase.dart';
import 'package:bb_mobile/features/seeds/domain/entities/seed_usage_entity.dart';
import 'package:bb_mobile/features/seeds/domain/seeds_domain_errors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'import_seed_bytes_usecase_test.mocks.dart';

@GenerateMocks([
  SeedCryptoPort,
  SeedSecretStorePort,
  SeedUsageRepositoryPort,
])
void main() {
  late ImportSeedBytesUseCase useCase;
  late MockSeedCryptoPort mockSeedCrypto;
  late MockSeedSecretStorePort mockSeedSecretStore;
  late MockSeedUsageRepositoryPort mockSeedUsageRepository;

  const testFingerprint = 'test-fingerprint-bytes';
  final testSeedBytes = Uint8List.fromList(
    List.generate(32, (index) => index),
  );

  setUp(() {
    mockSeedCrypto = MockSeedCryptoPort();
    mockSeedSecretStore = MockSeedSecretStorePort();
    mockSeedUsageRepository = MockSeedUsageRepositoryPort();

    useCase = ImportSeedBytesUseCase(
      seedCrypto: mockSeedCrypto,
      seedSecretStore: mockSeedSecretStore,
      seedUsageRepository: mockSeedUsageRepository,
    );
  });

  group('ImportSeedBytesUseCase - Happy Path', () {
    test('should successfully import seed from bytes', () async {
      // Arrange
      final command = ImportSeedBytesCommand(
        seedBytes: testSeedBytes,
        purpose: SeedUsagePurpose.wallet,
        consumerRef: 'wallet-456',
      );

      when(mockSeedCrypto.getFingerprintFromSeedSecret(any))
          .thenAnswer((_) async => testFingerprint);
      when(mockSeedSecretStore.save(
        fingerprint: anyNamed('fingerprint'),
        secret: anyNamed('secret'),
      )).thenAnswer((_) async {});
      when(mockSeedUsageRepository.add(
        fingerprint: anyNamed('fingerprint'),
        purpose: anyNamed('purpose'),
        consumerRef: anyNamed('consumerRef'),
      )).thenAnswer((_) async => _createTestSeedUsage());

      // Act
      final result = await useCase.execute(command);

      // Assert
      expect(result.fingerprint, testFingerprint);

      // Verify the secret was created correctly
      final capturedSecret = verify(mockSeedCrypto.getFingerprintFromSeedSecret(
        captureAny,
      )).captured.single as SeedBytesSecret;

      expect(capturedSecret.bytes, testSeedBytes);

      verify(mockSeedSecretStore.save(
        fingerprint: testFingerprint,
        secret: argThat(
          isA<SeedBytesSecret>()
              .having((s) => s.bytes, 'bytes', testSeedBytes),
          named: 'secret',
        ),
      )).called(1);

      verify(mockSeedUsageRepository.add(
        fingerprint: testFingerprint,
        purpose: SeedUsagePurpose.wallet,
        consumerRef: 'wallet-456',
      )).called(1);
    });
  });

  group('ImportSeedBytesUseCase - Error Scenarios', () {
    test('should throw BusinessRuleFailed when fingerprint calculation throws domain error',
        () async {
      // Arrange
      final command = ImportSeedBytesCommand(
        seedBytes: testSeedBytes,
        purpose: SeedUsagePurpose.wallet,
        consumerRef: 'wallet-456',
      );

      final domainError = TestSeedsDomainError('Invalid seed bytes');
      when(mockSeedCrypto.getFingerprintFromSeedSecret(any))
          .thenThrow(domainError);

      // Act & Assert
      await expectLater(
        () => useCase.execute(command),
        throwsA(
          isA<BusinessRuleFailed>()
              .having((e) => e.domainError, 'domainError', domainError),
        ),
      );
    });

    test('should throw FailedToImportSeedBytesError when storage fails',
        () async {
      // Arrange
      final command = ImportSeedBytesCommand(
        seedBytes: testSeedBytes,
        purpose: SeedUsagePurpose.wallet,
        consumerRef: 'wallet-456',
      );

      final storageError = Exception('Storage unavailable');
      when(mockSeedCrypto.getFingerprintFromSeedSecret(any))
          .thenAnswer((_) async => testFingerprint);
      when(mockSeedSecretStore.save(
        fingerprint: anyNamed('fingerprint'),
        secret: anyNamed('secret'),
      )).thenThrow(storageError);

      // Act & Assert
      await expectLater(
        () => useCase.execute(command),
        throwsA(
          isA<FailedToImportSeedBytesError>()
              .having((e) => e.cause, 'cause', storageError),
        ),
      );
    });

    test('should throw FailedToImportSeedBytesError when repository add fails',
        () async {
      // Arrange
      final command = ImportSeedBytesCommand(
        seedBytes: testSeedBytes,
        purpose: SeedUsagePurpose.wallet,
        consumerRef: 'wallet-456',
      );

      final repositoryError = Exception('Database error');
      when(mockSeedCrypto.getFingerprintFromSeedSecret(any))
          .thenAnswer((_) async => testFingerprint);
      when(mockSeedSecretStore.save(
        fingerprint: anyNamed('fingerprint'),
        secret: anyNamed('secret'),
      )).thenAnswer((_) async {});
      when(mockSeedUsageRepository.add(
        fingerprint: anyNamed('fingerprint'),
        purpose: anyNamed('purpose'),
        consumerRef: anyNamed('consumerRef'),
      )).thenThrow(repositoryError);

      // Act & Assert
      await expectLater(
        () => useCase.execute(command),
        throwsA(
          isA<FailedToImportSeedBytesError>()
              .having((e) => e.cause, 'cause', repositoryError),
        ),
      );
    });

    test('should rethrow application errors without wrapping', () async {
      // Arrange
      final command = ImportSeedBytesCommand(
        seedBytes: testSeedBytes,
        purpose: SeedUsagePurpose.wallet,
        consumerRef: 'wallet-456',
      );

      final appError = SeedInUseError('existing-fp');
      when(mockSeedCrypto.getFingerprintFromSeedSecret(any))
          .thenThrow(appError);

      // Act & Assert
      await expectLater(
        () => useCase.execute(command),
        throwsA(isA<SeedInUseError>()),
      );
    });
  });

  group('ImportSeedBytesUseCase - Verification Tests', () {
    test('should call ports in correct sequence', () async {
      // Arrange
      final command = ImportSeedBytesCommand(
        seedBytes: testSeedBytes,
        purpose: SeedUsagePurpose.wallet,
        consumerRef: 'wallet-456',
      );

      final callOrder = <String>[];

      when(mockSeedCrypto.getFingerprintFromSeedSecret(any))
          .thenAnswer((_) async {
        callOrder.add('getFingerprintFromSeedSecret');
        return testFingerprint;
      });
      when(mockSeedSecretStore.save(
        fingerprint: anyNamed('fingerprint'),
        secret: anyNamed('secret'),
      )).thenAnswer((_) async {
        callOrder.add('save');
      });
      when(mockSeedUsageRepository.add(
        fingerprint: anyNamed('fingerprint'),
        purpose: anyNamed('purpose'),
        consumerRef: anyNamed('consumerRef'),
      )).thenAnswer((_) async {
        callOrder.add('add');
        return _createTestSeedUsage();
      });

      // Act
      await useCase.execute(command);

      // Assert
      expect(callOrder, [
        'getFingerprintFromSeedSecret',
        'save',
        'add',
      ]);
    });
  });
}

SeedUsage _createTestSeedUsage() {
  return SeedUsage(
    id: 1,
    fingerprint: 'test-fingerprint-bytes',
    purpose: SeedUsagePurpose.wallet,
    consumerRef: 'test-consumer',
    createdAt: DateTime.now(),
  );
}
