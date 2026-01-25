import 'package:bb_mobile/features/secrets/domain/secret.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/mnemonic_words.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/passphrase.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/seed_bytes.dart';
import 'package:bb_mobile/features/secrets/domain/secret_usage_purpose.dart';
import 'package:bb_mobile/features/secrets/application/ports/mnemonic_generator_port.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_crypto_port.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_store_port.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_usage_repository_port.dart';
import 'package:bb_mobile/features/secrets/application/secrets_application_errors.dart';
import 'package:bb_mobile/features/secrets/application/usecases/create_new_mnemonic_secret_usecase.dart';
import 'package:bb_mobile/features/secrets/domain/entities/secret_usage_entity.dart';
import 'package:bb_mobile/features/secrets/domain/secrets_domain_errors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'create_new_mnemonic_secret_usecase_test.mocks.dart';

@GenerateMocks([
  MnemonicGeneratorPort,
  SecretCryptoPort,
  SecretStorePort,
  SecretUsageRepositoryPort,
])
void main() {
  late CreateNewMnemonicSecretUseCase useCase;
  late MockMnemonicGeneratorPort mockMnemonicGenerator;
  late MockSecretCryptoPort mockSecretCrypto;
  late MockSecretStorePort mockSecretStore;
  late MockSecretUsageRepositoryPort mockSecretUsageRepository;

  // Test data
  const testFingerprint = 'test-fingerprint-12345';
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
    mockMnemonicGenerator = MockMnemonicGeneratorPort();
    mockSecretCrypto = MockSecretCryptoPort();
    mockSecretStore = MockSecretStorePort();
    mockSecretUsageRepository = MockSecretUsageRepositoryPort();

    useCase = CreateNewMnemonicSecretUseCase(
      mnemonicGenerator: mockMnemonicGenerator,
      secretCrypto: mockSecretCrypto,
      secretStore: mockSecretStore,
      secretUsageRepository: mockSecretUsageRepository,
    );
  });

  group('CreateNewSecretMnemonicUseCase - Happy Path', () {
    test('should successfully create new seed without passphrase', () async {
      // Arrange
      final command = CreateNewMnemonicSecretCommand(
        purpose: SecretUsagePurpose.wallet,
        consumerRef: 'wallet-123',
      );

      when(
        mockMnemonicGenerator.generateMnemonic(),
      ).thenAnswer((_) async => testMnemonicWords);
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
      expect(result.secret, isA<MnemonicSecret>());

      final secret = result.secret;
      expect(secret.words, testMnemonicWords);
      expect(secret.passphrase, isNull);

      // Verify port interactions
      verify(mockMnemonicGenerator.generateMnemonic()).called(1);
      verify(mockSecretCrypto.getFingerprintFromSecret(any)).called(1);
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

    test('should successfully create new seed with passphrase', () async {
      // Arrange
      const testPassphrase = 'super-secret-passphrase';
      final command = CreateNewMnemonicSecretCommand(
        passphrase: testPassphrase,
        purpose: SecretUsagePurpose.bip85,
        consumerRef: 'bip85-456',
      );

      when(
        mockMnemonicGenerator.generateMnemonic(),
      ).thenAnswer((_) async => testMnemonicWords);
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
      expect(result.secret, isA<MnemonicSecret>());

      final secret = result.secret;
      expect(secret.words, testMnemonicWords);
      expect(secret.passphrase, testPassphrase);

      // Verify passphrase was passed correctly
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
      verify(
        mockSecretUsageRepository.add(
          fingerprint: testFingerprint,
          purpose: SecretUsagePurpose.bip85,
          consumerRef: 'bip85-456',
        ),
      ).called(1);
    });
  });

  group('CreateNewMnemonicSecretUseCase - Error Scenarios', () {
    test(
      'should throw FailedToCreateNewMnemonicSecretError when mnemonic generation fails',
      () async {
        // Arrange
        final command = CreateNewMnemonicSecretCommand(
          purpose: SecretUsagePurpose.wallet,
          consumerRef: 'wallet-123',
        );

        final generationError = Exception('RNG failure');
        when(
          mockMnemonicGenerator.generateMnemonic(),
        ).thenThrow(generationError);

        // Act & Assert
        expect(
          () => useCase.execute(command),
          throwsA(
            isA<FailedToCreateNewMnemonicSecretError>().having(
              (e) => e.cause,
              'cause',
              generationError,
            ),
          ),
        );

        // Verify no other ports were called
        verifyNever(mockSecretCrypto.getFingerprintFromSecret(any));
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
      'should throw BusinessRuleFailed when fingerprint calculation throws domain error',
      () async {
        // Arrange
        final command = CreateNewMnemonicSecretCommand(
          purpose: SecretUsagePurpose.wallet,
          consumerRef: 'wallet-123',
        );

        final domainError = TestSecretsDomainError('Invalid seed format');
        when(
          mockMnemonicGenerator.generateMnemonic(),
        ).thenAnswer((_) async => testMnemonicWords);
        when(
          mockSecretCrypto.getFingerprintFromSecret(any),
        ).thenThrow(domainError);

        // Act & Assert
        await expectLater(
          () => useCase.execute(command),
          throwsA(
            isA<BusinessRuleFailed>()
                .having((e) => e.domainError, 'domainError', domainError)
                .having((e) => e.cause, 'cause', domainError),
          ),
        );

        // Verify mnemonic was generated but no storage happened
        verify(mockMnemonicGenerator.generateMnemonic()).called(1);
        verify(mockSecretCrypto.getFingerprintFromSecret(any)).called(1);
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
      'should throw FailedToCreateNewMnemonicSecretError when secret storage fails',
      () async {
        // Arrange
        final command = CreateNewMnemonicSecretCommand(
          purpose: SecretUsagePurpose.wallet,
          consumerRef: 'wallet-123',
        );

        final storageError = Exception('Secure storage unavailable');
        when(
          mockMnemonicGenerator.generateMnemonic(),
        ).thenAnswer((_) async => testMnemonicWords);
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
        expect(
          () => useCase.execute(command),
          throwsA(
            isA<FailedToCreateNewMnemonicSecretError>().having(
              (e) => e.cause,
              'cause',
              storageError,
            ),
          ),
        );

        // Verify usage repository was not called
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
      'should throw FailedToCreateNewMnemonicSecretError when usage repository add fails',
      () async {
        // Arrange
        final command = CreateNewMnemonicSecretCommand(
          purpose: SecretUsagePurpose.wallet,
          consumerRef: 'wallet-123',
        );

        final repositoryError = Exception('Database connection failed');
        when(
          mockMnemonicGenerator.generateMnemonic(),
        ).thenAnswer((_) async => testMnemonicWords);
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
            isA<FailedToCreateNewMnemonicSecretError>().having(
              (e) => e.cause,
              'cause',
              repositoryError,
            ),
          ),
        );

        // Verify all steps up to repository were called
        verify(mockMnemonicGenerator.generateMnemonic()).called(1);
        verify(mockSecretCrypto.getFingerprintFromSecret(any)).called(1);
        verify(
          mockSecretStore.save(
            fingerprint: anyNamed('fingerprint'),
            secret: anyNamed('secret'),
          ),
        ).called(1);
      },
    );

    test('should rethrow application errors without wrapping', () async {
      // Arrange
      final command = CreateNewMnemonicSecretCommand(
        purpose: SecretUsagePurpose.wallet,
        consumerRef: 'wallet-123',
      );

      final appError = SecretInUseError('existing-fingerprint');
      when(
        mockMnemonicGenerator.generateMnemonic(),
      ).thenAnswer((_) async => testMnemonicWords);
      when(mockSecretCrypto.getFingerprintFromSecret(any)).thenThrow(appError);

      // Act & Assert
      expect(
        () => useCase.execute(command),
        throwsA(
          isA<SecretInUseError>().having(
            (e) => e.fingerprint,
            'fingerprint',
            'existing-fingerprint',
          ),
        ),
      );
    });
  });

  group('CreateNewMnemonicSecretUseCase - Verification Tests', () {
    test('should call ports in correct sequence', () async {
      // Arrange
      final command = CreateNewMnemonicSecretCommand(
        purpose: SecretUsagePurpose.wallet,
        consumerRef: 'wallet-123',
      );

      final callOrder = <String>[];

      when(mockMnemonicGenerator.generateMnemonic()).thenAnswer((_) async {
        callOrder.add('generateMnemonic');
        return testMnemonicWords;
      });
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

      // Assert - verify exact order
      expect(callOrder, [
        'generateMnemonic',
        'getFingerprintFromSecret',
        'save',
        'add',
      ]);
    });

    test(
      'should pass correct SecretMnemonicSecret to getFingerprintFromSecret',
      () async {
        // Arrange
        const testPassphrase = 'my-passphrase';
        final command = CreateNewMnemonicSecretCommand(
          passphrase: testPassphrase,
          purpose: SecretUsagePurpose.wallet,
          consumerRef: 'wallet-123',
        );

        Secret? capturedSecret;
        when(
          mockMnemonicGenerator.generateMnemonic(),
        ).thenAnswer((_) async => testMnemonicWords);
        when(mockSecretCrypto.getFingerprintFromSecret(any)).thenAnswer((
          invocation,
        ) async {
          capturedSecret = invocation.positionalArguments[0] as Secret;
          return testFingerprint;
        });
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
        expect(capturedSecret, isA<MnemonicSecret>());
        final mnemonicSecret = capturedSecret as MnemonicSecret;
        expect(mnemonicSecret.words, testMnemonicWords);
        expect(mnemonicSecret.passphrase, testPassphrase);
      },
    );

    test('should pass command properties correctly to repository', () async {
      // Arrange
      final command = CreateNewMnemonicSecretCommand(
        purpose: SecretUsagePurpose.bip85,
        consumerRef: 'bip85-special-ref',
      );

      when(
        mockMnemonicGenerator.generateMnemonic(),
      ).thenAnswer((_) async => testMnemonicWords);
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
      verify(
        mockSecretUsageRepository.add(
          fingerprint: testFingerprint,
          purpose: SecretUsagePurpose.bip85,
          consumerRef: 'bip85-special-ref',
        ),
      ).called(1);
    });

    test('should call each port exactly once in happy path', () async {
      // Arrange
      final command = CreateNewMnemonicSecretCommand(
        purpose: SecretUsagePurpose.wallet,
        consumerRef: 'wallet-123',
      );

      when(
        mockMnemonicGenerator.generateMnemonic(),
      ).thenAnswer((_) async => testMnemonicWords);
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

      // Assert - verify exactly one call each
      verify(mockMnemonicGenerator.generateMnemonic()).called(1);
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

      // Verify no other interactions
      verifyNoMoreInteractions(mockMnemonicGenerator);
      verifyNoMoreInteractions(mockSecretCrypto);
      verifyNoMoreInteractions(mockSecretStore);
      verifyNoMoreInteractions(mockSecretUsageRepository);
    });

    test(
      'should return result with same fingerprint from crypto port',
      () async {
        // Arrange
        const customFingerprint = 'custom-fp-xyz789';
        final command = CreateNewMnemonicSecretCommand(
          purpose: SecretUsagePurpose.wallet,
          consumerRef: 'wallet-123',
        );

        when(
          mockMnemonicGenerator.generateMnemonic(),
        ).thenAnswer((_) async => testMnemonicWords);
        when(
          mockSecretCrypto.getFingerprintFromSecret(any),
        ).thenAnswer((_) async => customFingerprint);
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
        expect(result.fingerprint, customFingerprint);
      },
    );
  });
}

// Test helper function to create a test SecretUsage entity
SecretUsage _createTestSecretUsage() {
  return SecretUsage(
    id: 1,
    fingerprint: 'test-fingerprint-12345',
    purpose: SecretUsagePurpose.wallet,
    consumerRef: 'test-consumer',
    createdAt: DateTime.now(),
  );
}
