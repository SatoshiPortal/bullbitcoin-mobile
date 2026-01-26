import 'dart:typed_data';
import 'package:bb_mobile/features/secrets/domain/value_objects/mnemonic_words.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/passphrase.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/seed_bytes.dart';

import 'package:bb_mobile/features/secrets/domain/entities/secret_entity.dart';
import 'package:bb_mobile/features/secrets/domain/primitives/secret_usage_purpose.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_crypto_port.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_store_port.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_usage_repository_port.dart';
import 'package:bb_mobile/features/secrets/application/secrets_application_error.dart';
import 'package:bb_mobile/features/secrets/application/usecases/import_seed_secret_usecase.dart';
import 'package:bb_mobile/features/secrets/domain/entities/secret_usage_entity.dart';
import 'package:bb_mobile/features/secrets/domain/secrets_domain_error.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'import_seed_secret_usecase_test.mocks.dart';

@GenerateMocks([SecretCryptoPort, SecretStorePort, SecretUsageRepositoryPort])
void main() {
  late ImportSeedSecretUseCase useCase;
  late MockSecretCryptoPort mockSecretCrypto;
  late MockSecretStorePort mockSecretStore;
  late MockSecretUsageRepositoryPort mockSecretUsageRepository;

  const testFingerprint = 'test-fingerprint-bytes';
  final testSecretBytes = Uint8List.fromList(
    List.generate(32, (index) => index),
  );

  setUp(() {
    mockSecretCrypto = MockSecretCryptoPort();
    mockSecretStore = MockSecretStorePort();
    mockSecretUsageRepository = MockSecretUsageRepositoryPort();

    useCase = ImportSeedSecretUseCase(
      secretCrypto: mockSecretCrypto,
      secretStore: mockSecretStore,
      secretUsageRepository: mockSecretUsageRepository,
    );
  });

  group('ImportSeedSecretUseCase - Happy Path', () {
    test('should successfully import seed from bytes', () async {
      // Arrange
      final command = ImportSeedSecretCommand(
        bytes: testSecretBytes,
        purpose: SecretUsagePurpose.wallet,
        consumerRef: 'wallet-456',
      );

      when(
        mockSecretCrypto.getFingerprintFromSecret(any),
      ).thenAnswer((_) async => testFingerprint);
      when(
        mockSecretStore.save(
          fingerprint: anyNamed('fingerprint'),
          secret: anyNamed('secret'),
        ),
      ).thenAnswer((_) async {
        return null;
      });
      when(
        mockSecretUsageRepository.add(
          fingerprint: anyNamed('fingerprint'),
          purpose: anyNamed('purpose'),
          consumerRef: anyNamed('consumerRef'),
        ),
      ).thenAnswer((_) async => _createTestSecretUsage());

      // Act
      final result = await useCase.execute(command);

      // Assert
      expect(result.fingerprint, testFingerprint);

      // Verify the secret was created correctly
      final capturedSecret =
          verify(
                mockSecretCrypto.getFingerprintFromSecret(captureAny),
              ).captured.single
              as SeedSecret;

      expect(capturedSecret.bytes, testSecretBytes);

      verify(
        mockSecretStore.save(
          fingerprint: testFingerprint,
          secret: argThat(
            isA<SeedSecret>().having((s) => s.bytes, 'bytes', testSecretBytes),
            named: 'secret',
          ),
        ),
      ).called(1);

      verify(
        mockSecretUsageRepository.add(
          fingerprint: testFingerprint,
          purpose: SecretUsagePurpose.wallet,
          consumerRef: 'wallet-456',
        ),
      ).called(1);
    });
  });

  group('ImportSeedSecretUseCase - Error Scenarios', () {
    test(
      'should throw BusinessRuleFailed when fingerprint calculation throws domain error',
      () async {
        // Arrange
        final command = ImportSeedSecretCommand(
          bytes: testSecretBytes,
          purpose: SecretUsagePurpose.wallet,
          consumerRef: 'wallet-456',
        );

        final domainError = TestSecretsDomainError('Invalid seed bytes');
        when(
          mockSecretCrypto.getFingerprintFromSecret(any),
        ).thenThrow(domainError);

        // Act & Assert
        await expectLater(
          () => useCase.execute(command),
          throwsA(
            isA<BusinessRuleFailed>().having(
              (e) => e.domainError,
              'domainError',
              domainError,
            ),
          ),
        );
      },
    );

    test('should throw FailedToImportSeedError when storage fails', () async {
      // Arrange
      final command = ImportSeedSecretCommand(
        bytes: testSecretBytes,
        purpose: SecretUsagePurpose.wallet,
        consumerRef: 'wallet-456',
      );

      final storageError = Exception('Storage unavailable');
      when(
        mockSecretCrypto.getFingerprintFromSecret(any),
      ).thenAnswer((_) async => testFingerprint);
      when(
        mockSecretStore.save(
          fingerprint: anyNamed('fingerprint'),
          secret: anyNamed('secret'),
        ),
      ).thenThrow(storageError);

      // Act & Assert
      await expectLater(
        () => useCase.execute(command),
        throwsA(
          isA<FailedToImportSeedSecretError>().having(
            (e) => e.cause,
            'cause',
            storageError,
          ),
        ),
      );
    });

    test(
      'should throw FailedToImportSeedSecretError when repository add fails',
      () async {
        // Arrange
        final command = ImportSeedSecretCommand(
          bytes: testSecretBytes,
          purpose: SecretUsagePurpose.wallet,
          consumerRef: 'wallet-456',
        );

        final repositoryError = Exception('Database error');
        when(
          mockSecretCrypto.getFingerprintFromSecret(any),
        ).thenAnswer((_) async => testFingerprint);
        when(
          mockSecretStore.save(
            fingerprint: anyNamed('fingerprint'),
            secret: anyNamed('secret'),
          ),
        ).thenAnswer((_) async {
          return null;
        });
        when(
          mockSecretUsageRepository.add(
            fingerprint: anyNamed('fingerprint'),
            purpose: anyNamed('purpose'),
            consumerRef: anyNamed('consumerRef'),
          ),
        ).thenThrow(repositoryError);

        // Act & Assert
        await expectLater(
          () => useCase.execute(command),
          throwsA(
            isA<FailedToImportSeedSecretError>().having(
              (e) => e.cause,
              'cause',
              repositoryError,
            ),
          ),
        );
      },
    );

    test('should rethrow application errors without wrapping', () async {
      // Arrange
      final command = ImportSeedSecretCommand(
        bytes: testSecretBytes,
        purpose: SecretUsagePurpose.wallet,
        consumerRef: 'wallet-456',
      );

      final appError = SecretInUseError('existing-fp');
      when(mockSecretCrypto.getFingerprintFromSecret(any)).thenThrow(appError);

      // Act & Assert
      await expectLater(
        () => useCase.execute(command),
        throwsA(isA<SecretInUseError>()),
      );
    });
  });

  group('ImportSecretBytesUseCase - Verification Tests', () {
    test('should call ports in correct sequence', () async {
      // Arrange
      final command = ImportSeedSecretCommand(
        bytes: testSecretBytes,
        purpose: SecretUsagePurpose.wallet,
        consumerRef: 'wallet-456',
      );

      final callOrder = <String>[];

      when(mockSecretCrypto.getFingerprintFromSecret(any)).thenAnswer((
        _,
      ) async {
        callOrder.add('getFingerprintFromSecret');
        return testFingerprint;
      });
      when(
        mockSecretStore.save(
          fingerprint: anyNamed('fingerprint'),
          secret: anyNamed('secret'),
        ),
      ).thenAnswer((_) async {
        callOrder.add('save');
        return null;
      });
      when(
        mockSecretUsageRepository.add(
          fingerprint: anyNamed('fingerprint'),
          purpose: anyNamed('purpose'),
          consumerRef: anyNamed('consumerRef'),
        ),
      ).thenAnswer((_) async {
        callOrder.add('add');
        return _createTestSecretUsage();
      });

      // Act
      await useCase.execute(command);

      // Assert
      expect(callOrder, ['getFingerprintFromSecret', 'save', 'add']);
    });
  });
}

SecretUsage _createTestSecretUsage() {
  return SecretUsage(
    id: 1,
    fingerprint: 'test-fingerprint-bytes',
    purpose: SecretUsagePurpose.wallet,
    consumerRef: 'test-consumer',
    createdAt: DateTime.now(),
  );
}
