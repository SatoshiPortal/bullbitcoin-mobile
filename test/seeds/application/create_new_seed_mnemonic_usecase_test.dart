import 'package:bb_mobile/core/primitives/seeds/seed_secret.dart';
import 'package:bb_mobile/core/primitives/seeds/seed_usage_purpose.dart';
import 'package:bb_mobile/features/seeds/application/ports/mnemonic_generator_port.dart';
import 'package:bb_mobile/features/seeds/application/ports/seed_crypto_port.dart';
import 'package:bb_mobile/features/seeds/application/ports/seed_secret_store_port.dart';
import 'package:bb_mobile/features/seeds/application/ports/seed_usage_repository_port.dart';
import 'package:bb_mobile/features/seeds/application/seeds_application_errors.dart';
import 'package:bb_mobile/features/seeds/application/usecases/create_new_seed_mnemonic_usecase.dart';
import 'package:bb_mobile/features/seeds/domain/entities/seed_usage_entity.dart';
import 'package:bb_mobile/features/seeds/domain/seeds_domain_errors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'create_new_seed_mnemonic_usecase_test.mocks.dart';

@GenerateMocks([
  MnemonicGeneratorPort,
  SeedCryptoPort,
  SeedSecretStorePort,
  SeedUsageRepositoryPort,
])
void main() {
  late CreateNewSeedMnemonicUseCase useCase;
  late MockMnemonicGeneratorPort mockMnemonicGenerator;
  late MockSeedCryptoPort mockSeedCrypto;
  late MockSeedSecretStorePort mockSeedSecretStore;
  late MockSeedUsageRepositoryPort mockSeedUsageRepository;

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
    mockSeedCrypto = MockSeedCryptoPort();
    mockSeedSecretStore = MockSeedSecretStorePort();
    mockSeedUsageRepository = MockSeedUsageRepositoryPort();

    useCase = CreateNewSeedMnemonicUseCase(
      mnemonicGenerator: mockMnemonicGenerator,
      seedCrypto: mockSeedCrypto,
      seedSecretStore: mockSeedSecretStore,
      seedUsageRepository: mockSeedUsageRepository,
    );
  });

  group('CreateNewSeedMnemonicUseCase - Happy Path', () {
    test('should successfully create new seed without passphrase', () async {
      // Arrange
      final command = CreateNewSeedMnemonicCommand(
        purpose: SeedUsagePurpose.wallet,
        consumerRef: 'wallet-123',
      );

      when(mockMnemonicGenerator.generateMnemonic())
          .thenAnswer((_) async => testMnemonicWords);
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
      expect(result.secret, isA<SeedMnemonicSecret>());

      final secret = result.secret as SeedMnemonicSecret;
      expect(secret.words, testMnemonicWords);
      expect(secret.passphrase, isNull);

      // Verify port interactions
      verify(mockMnemonicGenerator.generateMnemonic()).called(1);
      verify(mockSeedCrypto.getFingerprintFromSeedSecret(any)).called(1);
      verify(mockSeedSecretStore.save(
        fingerprint: testFingerprint,
        secret: argThat(
          isA<SeedMnemonicSecret>()
              .having((s) => s.words, 'words', testMnemonicWords)
              .having((s) => s.passphrase, 'passphrase', isNull),
          named: 'secret',
        ),
      )).called(1);
      verify(mockSeedUsageRepository.add(
        fingerprint: testFingerprint,
        purpose: SeedUsagePurpose.wallet,
        consumerRef: 'wallet-123',
      )).called(1);
    });

    test('should successfully create new seed with passphrase', () async {
      // Arrange
      const testPassphrase = 'super-secret-passphrase';
      final command = CreateNewSeedMnemonicCommand(
        passphrase: testPassphrase,
        purpose: SeedUsagePurpose.bip85,
        consumerRef: 'bip85-456',
      );

      when(mockMnemonicGenerator.generateMnemonic())
          .thenAnswer((_) async => testMnemonicWords);
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
      expect(result.secret, isA<SeedMnemonicSecret>());

      final secret = result.secret as SeedMnemonicSecret;
      expect(secret.words, testMnemonicWords);
      expect(secret.passphrase, testPassphrase);

      // Verify passphrase was passed correctly
      verify(mockSeedSecretStore.save(
        fingerprint: testFingerprint,
        secret: argThat(
          isA<SeedMnemonicSecret>()
              .having((s) => s.words, 'words', testMnemonicWords)
              .having((s) => s.passphrase, 'passphrase', testPassphrase),
          named: 'secret',
        ),
      )).called(1);
      verify(mockSeedUsageRepository.add(
        fingerprint: testFingerprint,
        purpose: SeedUsagePurpose.bip85,
        consumerRef: 'bip85-456',
      )).called(1);
    });
  });

  group('CreateNewSeedMnemonicUseCase - Error Scenarios', () {
    test('should throw FailedToCreateNewSeedMnemonicError when mnemonic generation fails',
        () async {
      // Arrange
      final command = CreateNewSeedMnemonicCommand(
        purpose: SeedUsagePurpose.wallet,
        consumerRef: 'wallet-123',
      );

      final generationError = Exception('RNG failure');
      when(mockMnemonicGenerator.generateMnemonic()).thenThrow(generationError);

      // Act & Assert
      expect(
        () => useCase.execute(command),
        throwsA(
          isA<FailedToCreateNewSeedMnemonicError>()
              .having((e) => e.cause, 'cause', generationError),
        ),
      );

      // Verify no other ports were called
      verifyNever(mockSeedCrypto.getFingerprintFromSeedSecret(any));
      verifyNever(mockSeedSecretStore.save(
        fingerprint: anyNamed('fingerprint'),
        secret: anyNamed('secret'),
      ));
      verifyNever(mockSeedUsageRepository.add(
        fingerprint: anyNamed('fingerprint'),
        purpose: anyNamed('purpose'),
        consumerRef: anyNamed('consumerRef'),
      ));
    });

    test('should throw BusinessRuleFailed when fingerprint calculation throws domain error',
        () async {
      // Arrange
      final command = CreateNewSeedMnemonicCommand(
        purpose: SeedUsagePurpose.wallet,
        consumerRef: 'wallet-123',
      );

      final domainError = TestSeedsDomainError('Invalid seed format');
      when(mockMnemonicGenerator.generateMnemonic())
          .thenAnswer((_) async => testMnemonicWords);
      when(mockSeedCrypto.getFingerprintFromSeedSecret(any))
          .thenThrow(domainError);

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
      verify(mockSeedCrypto.getFingerprintFromSeedSecret(any)).called(1);
      verifyNever(mockSeedSecretStore.save(
        fingerprint: anyNamed('fingerprint'),
        secret: anyNamed('secret'),
      ));
      verifyNever(mockSeedUsageRepository.add(
        fingerprint: anyNamed('fingerprint'),
        purpose: anyNamed('purpose'),
        consumerRef: anyNamed('consumerRef'),
      ));
    });

    test('should throw FailedToCreateNewSeedMnemonicError when secret storage fails',
        () async {
      // Arrange
      final command = CreateNewSeedMnemonicCommand(
        purpose: SeedUsagePurpose.wallet,
        consumerRef: 'wallet-123',
      );

      final storageError = Exception('Secure storage unavailable');
      when(mockMnemonicGenerator.generateMnemonic())
          .thenAnswer((_) async => testMnemonicWords);
      when(mockSeedCrypto.getFingerprintFromSeedSecret(any))
          .thenAnswer((_) async => testFingerprint);
      when(mockSeedSecretStore.save(
        fingerprint: anyNamed('fingerprint'),
        secret: anyNamed('secret'),
      )).thenThrow(storageError);

      // Act & Assert
      expect(
        () => useCase.execute(command),
        throwsA(
          isA<FailedToCreateNewSeedMnemonicError>()
              .having((e) => e.cause, 'cause', storageError),
        ),
      );

      // Verify usage repository was not called
      verifyNever(mockSeedUsageRepository.add(
        fingerprint: anyNamed('fingerprint'),
        purpose: anyNamed('purpose'),
        consumerRef: anyNamed('consumerRef'),
      ));
    });

    test('should throw FailedToCreateNewSeedMnemonicError when usage repository add fails',
        () async {
      // Arrange
      final command = CreateNewSeedMnemonicCommand(
        purpose: SeedUsagePurpose.wallet,
        consumerRef: 'wallet-123',
      );

      final repositoryError = Exception('Database connection failed');
      when(mockMnemonicGenerator.generateMnemonic())
          .thenAnswer((_) async => testMnemonicWords);
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
          isA<FailedToCreateNewSeedMnemonicError>()
              .having((e) => e.cause, 'cause', repositoryError),
        ),
      );

      // Verify all steps up to repository were called
      verify(mockMnemonicGenerator.generateMnemonic()).called(1);
      verify(mockSeedCrypto.getFingerprintFromSeedSecret(any)).called(1);
      verify(mockSeedSecretStore.save(
        fingerprint: anyNamed('fingerprint'),
        secret: anyNamed('secret'),
      )).called(1);
    });

    test('should rethrow application errors without wrapping', () async {
      // Arrange
      final command = CreateNewSeedMnemonicCommand(
        purpose: SeedUsagePurpose.wallet,
        consumerRef: 'wallet-123',
      );

      final appError = SeedInUseError('existing-fingerprint');
      when(mockMnemonicGenerator.generateMnemonic())
          .thenAnswer((_) async => testMnemonicWords);
      when(mockSeedCrypto.getFingerprintFromSeedSecret(any))
          .thenThrow(appError);

      // Act & Assert
      expect(
        () => useCase.execute(command),
        throwsA(
          isA<SeedInUseError>()
              .having((e) => e.fingerprint, 'fingerprint', 'existing-fingerprint'),
        ),
      );
    });
  });

  group('CreateNewSeedMnemonicUseCase - Verification Tests', () {
    test('should call ports in correct sequence', () async {
      // Arrange
      final command = CreateNewSeedMnemonicCommand(
        purpose: SeedUsagePurpose.wallet,
        consumerRef: 'wallet-123',
      );

      final callOrder = <String>[];

      when(mockMnemonicGenerator.generateMnemonic()).thenAnswer((_) async {
        callOrder.add('generateMnemonic');
        return testMnemonicWords;
      });
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

      // Assert - verify exact order
      expect(callOrder, [
        'generateMnemonic',
        'getFingerprintFromSeedSecret',
        'save',
        'add',
      ]);
    });

    test('should pass correct SeedMnemonicSecret to getFingerprintFromSeedSecret',
        () async {
      // Arrange
      const testPassphrase = 'my-passphrase';
      final command = CreateNewSeedMnemonicCommand(
        passphrase: testPassphrase,
        purpose: SeedUsagePurpose.wallet,
        consumerRef: 'wallet-123',
      );

      SeedSecret? capturedSecret;
      when(mockMnemonicGenerator.generateMnemonic())
          .thenAnswer((_) async => testMnemonicWords);
      when(mockSeedCrypto.getFingerprintFromSeedSecret(any))
          .thenAnswer((invocation) async {
        capturedSecret = invocation.positionalArguments[0] as SeedSecret;
        return testFingerprint;
      });
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
      await useCase.execute(command);

      // Assert
      expect(capturedSecret, isA<SeedMnemonicSecret>());
      final mnemonicSecret = capturedSecret as SeedMnemonicSecret;
      expect(mnemonicSecret.words, testMnemonicWords);
      expect(mnemonicSecret.passphrase, testPassphrase);
    });

    test('should pass command properties correctly to repository', () async {
      // Arrange
      final command = CreateNewSeedMnemonicCommand(
        purpose: SeedUsagePurpose.bip85,
        consumerRef: 'bip85-special-ref',
      );

      when(mockMnemonicGenerator.generateMnemonic())
          .thenAnswer((_) async => testMnemonicWords);
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
      await useCase.execute(command);

      // Assert
      verify(mockSeedUsageRepository.add(
        fingerprint: testFingerprint,
        purpose: SeedUsagePurpose.bip85,
        consumerRef: 'bip85-special-ref',
      )).called(1);
    });

    test('should call each port exactly once in happy path', () async {
      // Arrange
      final command = CreateNewSeedMnemonicCommand(
        purpose: SeedUsagePurpose.wallet,
        consumerRef: 'wallet-123',
      );

      when(mockMnemonicGenerator.generateMnemonic())
          .thenAnswer((_) async => testMnemonicWords);
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
      await useCase.execute(command);

      // Assert - verify exactly one call each
      verify(mockMnemonicGenerator.generateMnemonic()).called(1);
      verify(mockSeedCrypto.getFingerprintFromSeedSecret(any)).called(1);
      verify(mockSeedSecretStore.save(
        fingerprint: anyNamed('fingerprint'),
        secret: anyNamed('secret'),
      )).called(1);
      verify(mockSeedUsageRepository.add(
        fingerprint: anyNamed('fingerprint'),
        purpose: anyNamed('purpose'),
        consumerRef: anyNamed('consumerRef'),
      )).called(1);

      // Verify no other interactions
      verifyNoMoreInteractions(mockMnemonicGenerator);
      verifyNoMoreInteractions(mockSeedCrypto);
      verifyNoMoreInteractions(mockSeedSecretStore);
      verifyNoMoreInteractions(mockSeedUsageRepository);
    });

    test('should return result with same fingerprint from crypto port', () async {
      // Arrange
      const customFingerprint = 'custom-fp-xyz789';
      final command = CreateNewSeedMnemonicCommand(
        purpose: SeedUsagePurpose.wallet,
        consumerRef: 'wallet-123',
      );

      when(mockMnemonicGenerator.generateMnemonic())
          .thenAnswer((_) async => testMnemonicWords);
      when(mockSeedCrypto.getFingerprintFromSeedSecret(any))
          .thenAnswer((_) async => customFingerprint);
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
      expect(result.fingerprint, customFingerprint);
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
