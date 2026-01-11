import 'package:bb_mobile/core/primitives/seeds/seed_secret.dart';
import 'package:bb_mobile/core/primitives/seeds/seed_usage_purpose.dart';
import 'package:bb_mobile/features/seeds/application/ports/seed_crypto_port.dart';
import 'package:bb_mobile/features/seeds/application/ports/seed_secret_store_port.dart';
import 'package:bb_mobile/features/seeds/application/ports/seed_usage_repository_port.dart';
import 'package:bb_mobile/features/seeds/application/seeds_application_errors.dart';
import 'package:bb_mobile/features/seeds/application/usecases/import_seed_mnemonic_usecase.dart';
import 'package:bb_mobile/features/seeds/domain/entities/seed_usage_entity.dart';
import 'package:bb_mobile/features/seeds/domain/seeds_domain_errors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'import_seed_mnemonic_usecase_test.mocks.dart';

@GenerateMocks([
  SeedCryptoPort,
  SeedSecretStorePort,
  SeedUsageRepositoryPort,
])
void main() {
  late ImportSeedMnemonicUseCase useCase;
  late MockSeedCryptoPort mockSeedCrypto;
  late MockSeedSecretStorePort mockSeedSecretStore;
  late MockSeedUsageRepositoryPort mockSeedUsageRepository;

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
    mockSeedCrypto = MockSeedCryptoPort();
    mockSeedSecretStore = MockSeedSecretStorePort();
    mockSeedUsageRepository = MockSeedUsageRepositoryPort();

    useCase = ImportSeedMnemonicUseCase(
      seedCrypto: mockSeedCrypto,
      seedSecretStore: mockSeedSecretStore,
      seedUsageRepository: mockSeedUsageRepository,
    );
  });

  group('ImportSeedMnemonicUseCase - Happy Path', () {
    test('should successfully import seed without passphrase', () async {
      // Arrange
      final command = ImportSeedMnemonicCommand(
        mnemonicWords: testMnemonicWords,
        purpose: SeedUsagePurpose.wallet,
        consumerRef: 'wallet-123',
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
      )).captured.single as SeedMnemonicSecret;

      expect(capturedSecret.words, testMnemonicWords);
      expect(capturedSecret.passphrase, isNull);

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

    test('should successfully import seed with passphrase', () async {
      // Arrange
      const testPassphrase = 'my-secret-passphrase';
      final command = ImportSeedMnemonicCommand(
        mnemonicWords: testMnemonicWords,
        passphrase: testPassphrase,
        purpose: SeedUsagePurpose.bip85,
        consumerRef: 'bip85-456',
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

      verify(mockSeedSecretStore.save(
        fingerprint: testFingerprint,
        secret: argThat(
          isA<SeedMnemonicSecret>()
              .having((s) => s.words, 'words', testMnemonicWords)
              .having((s) => s.passphrase, 'passphrase', testPassphrase),
          named: 'secret',
        ),
      )).called(1);
    });
  });

  group('ImportSeedMnemonicUseCase - Error Scenarios', () {
    test('should throw BusinessRuleFailed when fingerprint calculation throws domain error',
        () async {
      // Arrange
      final command = ImportSeedMnemonicCommand(
        mnemonicWords: testMnemonicWords,
        purpose: SeedUsagePurpose.wallet,
        consumerRef: 'wallet-123',
      );

      final domainError = TestSeedsDomainError('Invalid mnemonic');
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

    test('should throw FailedToImportSeedMnemonicError when storage fails',
        () async {
      // Arrange
      final command = ImportSeedMnemonicCommand(
        mnemonicWords: testMnemonicWords,
        purpose: SeedUsagePurpose.wallet,
        consumerRef: 'wallet-123',
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
          isA<FailedToImportSeedMnemonicError>()
              .having((e) => e.cause, 'cause', storageError),
        ),
      );

      verifyNever(mockSeedUsageRepository.add(
        fingerprint: anyNamed('fingerprint'),
        purpose: anyNamed('purpose'),
        consumerRef: anyNamed('consumerRef'),
      ));
    });

    test('should throw FailedToImportSeedMnemonicError when repository add fails',
        () async {
      // Arrange
      final command = ImportSeedMnemonicCommand(
        mnemonicWords: testMnemonicWords,
        purpose: SeedUsagePurpose.wallet,
        consumerRef: 'wallet-123',
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
          isA<FailedToImportSeedMnemonicError>()
              .having((e) => e.cause, 'cause', repositoryError),
        ),
      );
    });

    test('should rethrow application errors without wrapping', () async {
      // Arrange
      final command = ImportSeedMnemonicCommand(
        mnemonicWords: testMnemonicWords,
        purpose: SeedUsagePurpose.wallet,
        consumerRef: 'wallet-123',
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

  group('ImportSeedMnemonicUseCase - Verification Tests', () {
    test('should call ports in correct sequence', () async {
      // Arrange
      final command = ImportSeedMnemonicCommand(
        mnemonicWords: testMnemonicWords,
        purpose: SeedUsagePurpose.wallet,
        consumerRef: 'wallet-123',
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

    test('should call each port exactly once in happy path', () async {
      // Arrange
      final command = ImportSeedMnemonicCommand(
        mnemonicWords: testMnemonicWords,
        purpose: SeedUsagePurpose.wallet,
        consumerRef: 'wallet-123',
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
      await useCase.execute(command);

      // Assert
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

      verifyNoMoreInteractions(mockSeedCrypto);
      verifyNoMoreInteractions(mockSeedSecretStore);
      verifyNoMoreInteractions(mockSeedUsageRepository);
    });
  });
}

SeedUsage _createTestSeedUsage() {
  return SeedUsage(
    id: 1,
    fingerprint: 'test-fingerprint-abc',
    purpose: SeedUsagePurpose.wallet,
    consumerRef: 'test-consumer',
    createdAt: DateTime.now(),
  );
}
