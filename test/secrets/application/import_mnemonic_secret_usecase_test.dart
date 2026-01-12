import 'package:bb_mobile/core/primitives/secrets/secret.dart';
import 'package:bb_mobile/core/primitives/secrets/secret_usage_purpose.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_crypto_port.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_store_port.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_usage_repository_port.dart';
import 'package:bb_mobile/features/secrets/application/secrets_application_errors.dart';
import 'package:bb_mobile/features/secrets/application/usecases/import_mnemonic_secret_usecase.dart';
import 'package:bb_mobile/features/secrets/domain/entities/secret_usage_entity.dart';
import 'package:bb_mobile/features/secrets/domain/secrets_domain_errors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'import_mnemonic_secret_usecase_test.mocks.dart';

@GenerateMocks([SecretCryptoPort, SecretStorePort, SecretUsageRepositoryPort])
void main() {
  late ImportMnemonicSecretUseCase useCase;
  late MockSecretCryptoPort mockSecretCrypto;
  late MockSecretStorePort mockSecretStore;
  late MockSecretUsageRepositoryPort mockSecretUsageRepository;

  const testFingerprint = 'test-fingerprint-abc';
  final testMnemonicWords = [
    'abandon',
    'ability',
    'able',
    'about',
    'above',
    'absent',
    'absorb',
    'abstract',
    'absurd',
    'abuse',
    'access',
    'accident',
  ];

  setUp(() {
    mockSecretCrypto = MockSecretCryptoPort();
    mockSecretStore = MockSecretStorePort();
    mockSecretUsageRepository = MockSecretUsageRepositoryPort();

    useCase = ImportMnemonicSecretUseCase(
      secretCrypto: mockSecretCrypto,
      secretStore: mockSecretStore,
      secretUsageRepository: mockSecretUsageRepository,
    );
  });

  group('ImportMnemonicSecretUseCase - Happy Path', () {
    test('should successfully import secret without passphrase', () async {
      // Arrange
      final command = ImportMnemonicSecretCommand(
        mnemonicWords: testMnemonicWords,
        purpose: SecretUsagePurpose.wallet,
        consumerRef: 'wallet-123',
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
              as MnemonicSecret;

      expect(capturedSecret.words, testMnemonicWords);
      expect(capturedSecret.passphrase, isNull);

      verify(
        mockSecretStore.save(
          fingerprint: testFingerprint,
          secret: argThat(
            isA<MnemonicSecret>()
                .having((s) => s.words, 'words', testMnemonicWords)
                .having((s) => s.passphrase, 'passphrase', isNull),
            named: 'secret',
          ),
        ),
      ).called(1);

      verify(
        mockSecretUsageRepository.add(
          fingerprint: testFingerprint,
          purpose: SecretUsagePurpose.wallet,
          consumerRef: 'wallet-123',
        ),
      ).called(1);
    });

    test('should successfully import secret with passphrase', () async {
      // Arrange
      const testPassphrase = 'my-secret-passphrase';
      final command = ImportMnemonicSecretCommand(
        mnemonicWords: testMnemonicWords,
        passphrase: testPassphrase,
        purpose: SecretUsagePurpose.bip85,
        consumerRef: 'bip85-456',
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

      verify(
        mockSecretStore.save(
          fingerprint: testFingerprint,
          secret: argThat(
            isA<MnemonicSecret>()
                .having((s) => s.words, 'words', testMnemonicWords)
                .having((s) => s.passphrase, 'passphrase', testPassphrase),
            named: 'secret',
          ),
        ),
      ).called(1);
    });
  });

  group('ImportMnemonicSecretUseCase - Error Scenarios', () {
    test(
      'should throw BusinessRuleFailed when fingerprint calculation throws domain error',
      () async {
        // Arrange
        final command = ImportMnemonicSecretCommand(
          mnemonicWords: testMnemonicWords,
          purpose: SecretUsagePurpose.wallet,
          consumerRef: 'wallet-123',
        );

        final domainError = TestSecretsDomainError('Invalid mnemonic');
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

        verifyNever(
          mockSecretStore.save(
            fingerprint: anyNamed('fingerprint'),
            secret: anyNamed('secret'),
          ),
        );
        verifyNever(
          mockSecretUsageRepository.add(
            fingerprint: anyNamed('fingerprint'),
            purpose: anyNamed('purpose'),
            consumerRef: anyNamed('consumerRef'),
          ),
        );
      },
    );

    test(
      'should throw FailedToImportMnemonicSecretError when storage fails',
      () async {
        // Arrange
        final command = ImportMnemonicSecretCommand(
          mnemonicWords: testMnemonicWords,
          purpose: SecretUsagePurpose.wallet,
          consumerRef: 'wallet-123',
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
            isA<FailedToImportMnemonicSecretError>().having(
              (e) => e.cause,
              'cause',
              storageError,
            ),
          ),
        );

        verifyNever(
          mockSecretUsageRepository.add(
            fingerprint: anyNamed('fingerprint'),
            purpose: anyNamed('purpose'),
            consumerRef: anyNamed('consumerRef'),
          ),
        );
      },
    );

    test(
      'should throw FailedToImportMnemonicSecretError when repository add fails',
      () async {
        // Arrange
        final command = ImportMnemonicSecretCommand(
          mnemonicWords: testMnemonicWords,
          purpose: SecretUsagePurpose.wallet,
          consumerRef: 'wallet-123',
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
            isA<FailedToImportMnemonicSecretError>().having(
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
      final command = ImportMnemonicSecretCommand(
        mnemonicWords: testMnemonicWords,
        purpose: SecretUsagePurpose.wallet,
        consumerRef: 'wallet-123',
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

  group('ImportMnemonicSecretUseCase - Verification Tests', () {
    test('should call ports in correct sequence', () async {
      // Arrange
      final command = ImportMnemonicSecretCommand(
        mnemonicWords: testMnemonicWords,
        purpose: SecretUsagePurpose.wallet,
        consumerRef: 'wallet-123',
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

    test('should call each port exactly once in happy path', () async {
      // Arrange
      final command = ImportMnemonicSecretCommand(
        mnemonicWords: testMnemonicWords,
        purpose: SecretUsagePurpose.wallet,
        consumerRef: 'wallet-123',
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
      await useCase.execute(command);

      // Assert
      verify(mockSecretCrypto.getFingerprintFromSecret(any)).called(1);
      verify(
        mockSecretStore.save(
          fingerprint: anyNamed('fingerprint'),
          secret: anyNamed('secret'),
        ),
      ).called(1);
      verify(
        mockSecretUsageRepository.add(
          fingerprint: anyNamed('fingerprint'),
          purpose: anyNamed('purpose'),
          consumerRef: anyNamed('consumerRef'),
        ),
      ).called(1);

      verifyNoMoreInteractions(mockSecretCrypto);
      verifyNoMoreInteractions(mockSecretStore);
      verifyNoMoreInteractions(mockSecretUsageRepository);
    });
  });
}

SecretUsage _createTestSecretUsage() {
  return SecretUsage(
    id: 1,
    fingerprint: 'test-fingerprint-abc',
    purpose: SecretUsagePurpose.wallet,
    consumerRef: 'test-consumer',
    createdAt: DateTime.now(),
  );
}
