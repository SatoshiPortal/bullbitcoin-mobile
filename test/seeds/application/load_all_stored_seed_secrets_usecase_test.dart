import 'package:bb_mobile/core/primitives/seeds/seed_secret.dart';
import 'package:bb_mobile/features/seeds/application/ports/seed_crypto_port.dart';
import 'package:bb_mobile/features/seeds/application/ports/seed_secret_store_port.dart';
import 'package:bb_mobile/features/seeds/application/seeds_application_errors.dart';
import 'package:bb_mobile/features/seeds/application/usecases/load_all_stored_seed_secrets_usecase.dart';
import 'package:bb_mobile/features/seeds/domain/seeds_domain_errors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'load_all_stored_seed_secrets_usecase_test.mocks.dart';

@GenerateMocks([
  SeedSecretStorePort,
  SeedCryptoPort,
])
void main() {
  late LoadAllStoredSeedSecretsUseCase useCase;
  late MockSeedSecretStorePort mockSeedSecretStore;
  late MockSeedCryptoPort mockSeedCrypto;

  // Test data
  final testMnemonicWords1 = [
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

  final testMnemonicWords2 = [
    'zoo',
    'zone',
    'yield',
    'year',
    'yellow',
    'year',
    'window',
    'will',
    'wide',
    'wealth',
    'wave',
    'water',
  ];

  setUp(() {
    mockSeedSecretStore = MockSeedSecretStorePort();
    mockSeedCrypto = MockSeedCryptoPort();

    useCase = LoadAllStoredSeedSecretsUseCase(
      seedSecretStore: mockSeedSecretStore,
      seedCrypto: mockSeedCrypto,
    );
  });

  group('LoadAllStoredSeedSecretsUseCase - Happy Path', () {
    test('should successfully load all seed secrets with fingerprints', () async {
      // Arrange
      final query = LoadAllStoredSeedSecretsQuery();

      final secret1 = SeedMnemonicSecret(words: testMnemonicWords1);
      final secret2 = SeedMnemonicSecret(words: testMnemonicWords2);
      final secrets = [secret1, secret2];

      const fingerprint1 = 'fingerprint-1';
      const fingerprint2 = 'fingerprint-2';

      when(mockSeedSecretStore.loadAll()).thenAnswer((_) async => secrets);
      when(mockSeedCrypto.getFingerprintFromSeedSecret(secret1))
          .thenAnswer((_) async => fingerprint1);
      when(mockSeedCrypto.getFingerprintFromSeedSecret(secret2))
          .thenAnswer((_) async => fingerprint2);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.secretsByFingerprint.length, 2);
      expect(result.secretsByFingerprint[fingerprint1], secret1);
      expect(result.secretsByFingerprint[fingerprint2], secret2);

      // Verify port interactions
      verify(mockSeedSecretStore.loadAll()).called(1);
      verify(mockSeedCrypto.getFingerprintFromSeedSecret(secret1)).called(1);
      verify(mockSeedCrypto.getFingerprintFromSeedSecret(secret2)).called(1);
    });

    test('should return empty map when no secrets are stored', () async {
      // Arrange
      final query = LoadAllStoredSeedSecretsQuery();

      when(mockSeedSecretStore.loadAll()).thenAnswer((_) async => []);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.secretsByFingerprint, isEmpty);

      // Verify port interactions
      verify(mockSeedSecretStore.loadAll()).called(1);
      verifyNever(mockSeedCrypto.getFingerprintFromSeedSecret(any));
    });

    test('should handle single seed secret', () async {
      // Arrange
      final query = LoadAllStoredSeedSecretsQuery();

      final secret = SeedMnemonicSecret(words: testMnemonicWords1);
      const fingerprint = 'single-fingerprint';

      when(mockSeedSecretStore.loadAll()).thenAnswer((_) async => [secret]);
      when(mockSeedCrypto.getFingerprintFromSeedSecret(secret))
          .thenAnswer((_) async => fingerprint);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.secretsByFingerprint.length, 1);
      expect(result.secretsByFingerprint[fingerprint], secret);

      // Verify port interactions
      verify(mockSeedSecretStore.loadAll()).called(1);
      verify(mockSeedCrypto.getFingerprintFromSeedSecret(secret)).called(1);
    });

    test('should handle both mnemonic and bytes secrets', () async {
      // Arrange
      final query = LoadAllStoredSeedSecretsQuery();

      final mnemonicSecret = SeedMnemonicSecret(words: testMnemonicWords1);
      final bytesSecret = SeedBytesSecret( List<int>.generate(32, (i) => i));
      final secrets = [mnemonicSecret, bytesSecret];

      const fingerprint1 = 'mnemonic-fp';
      const fingerprint2 = 'bytes-fp';

      when(mockSeedSecretStore.loadAll()).thenAnswer((_) async => secrets);
      when(mockSeedCrypto.getFingerprintFromSeedSecret(mnemonicSecret))
          .thenAnswer((_) async => fingerprint1);
      when(mockSeedCrypto.getFingerprintFromSeedSecret(bytesSecret))
          .thenAnswer((_) async => fingerprint2);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.secretsByFingerprint.length, 2);
      expect(result.secretsByFingerprint[fingerprint1], mnemonicSecret);
      expect(result.secretsByFingerprint[fingerprint2], bytesSecret);

      // Verify port interactions
      verify(mockSeedSecretStore.loadAll()).called(1);
      verify(mockSeedCrypto.getFingerprintFromSeedSecret(mnemonicSecret)).called(1);
      verify(mockSeedCrypto.getFingerprintFromSeedSecret(bytesSecret)).called(1);
    });

    test('should handle secrets with passphrases', () async {
      // Arrange
      final query = LoadAllStoredSeedSecretsQuery();

      const passphrase = 'my-passphrase';
      final secret = SeedMnemonicSecret(
        words: testMnemonicWords1,
        passphrase: passphrase,
      );
      const fingerprint = 'passphrase-fp';

      when(mockSeedSecretStore.loadAll()).thenAnswer((_) async => [secret]);
      when(mockSeedCrypto.getFingerprintFromSeedSecret(secret))
          .thenAnswer((_) async => fingerprint);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.secretsByFingerprint.length, 1);
      expect(result.secretsByFingerprint[fingerprint], secret);
      final retrievedSecret = result.secretsByFingerprint[fingerprint] as SeedMnemonicSecret;
      expect(retrievedSecret.passphrase, passphrase);

      // Verify port interactions
      verify(mockSeedSecretStore.loadAll()).called(1);
      verify(mockSeedCrypto.getFingerprintFromSeedSecret(secret)).called(1);
    });
  });

  group('LoadAllStoredSeedSecretsUseCase - Error Scenarios', () {
    test('should throw BusinessRuleFailed when loadAll throws domain error',
        () async {
      // Arrange
      final query = LoadAllStoredSeedSecretsQuery();

      final domainError = TestSeedsDomainError('Storage constraint violated');
      when(mockSeedSecretStore.loadAll()).thenThrow(domainError);

      // Act & Assert
      await expectLater(
        () => useCase.execute(query),
        throwsA(
          isA<BusinessRuleFailed>()
              .having((e) => e.domainError, 'domainError', domainError)
              .having((e) => e.cause, 'cause', domainError),
        ),
      );

      // Verify loadAll was called but not crypto
      verify(mockSeedSecretStore.loadAll()).called(1);
      verifyNever(mockSeedCrypto.getFingerprintFromSeedSecret(any));
    });

    test('should throw BusinessRuleFailed when getFingerprintFromSeedSecret throws domain error',
        () async {
      // Arrange
      final query = LoadAllStoredSeedSecretsQuery();

      final secret = SeedMnemonicSecret(words: testMnemonicWords1);
      final domainError = TestSeedsDomainError('Invalid seed format');

      when(mockSeedSecretStore.loadAll()).thenAnswer((_) async => [secret]);
      when(mockSeedCrypto.getFingerprintFromSeedSecret(any))
          .thenThrow(domainError);

      // Act & Assert
      await expectLater(
        () => useCase.execute(query),
        throwsA(
          isA<BusinessRuleFailed>()
              .having((e) => e.domainError, 'domainError', domainError)
              .having((e) => e.cause, 'cause', domainError),
        ),
      );

      // Verify both methods were called
      verify(mockSeedSecretStore.loadAll()).called(1);
      verify(mockSeedCrypto.getFingerprintFromSeedSecret(any)).called(1);
    });

    test('should throw FailedToLoadAllStoredSeedSecretsError when loadAll fails',
        () async {
      // Arrange
      final query = LoadAllStoredSeedSecretsQuery();

      final storageError = Exception('Secure storage unavailable');
      when(mockSeedSecretStore.loadAll()).thenThrow(storageError);

      // Act & Assert
      await expectLater(
        () => useCase.execute(query),
        throwsA(
          isA<FailedToLoadAllStoredSeedSecretsError>()
              .having((e) => e.cause, 'cause', storageError),
        ),
      );

      // Verify loadAll was called
      verify(mockSeedSecretStore.loadAll()).called(1);
    });

    test('should throw FailedToLoadAllStoredSeedSecretsError when fingerprint calculation fails',
        () async {
      // Arrange
      final query = LoadAllStoredSeedSecretsQuery();

      final secret = SeedMnemonicSecret(words: testMnemonicWords1);
      final cryptoError = Exception('Crypto library error');

      when(mockSeedSecretStore.loadAll()).thenAnswer((_) async => [secret]);
      when(mockSeedCrypto.getFingerprintFromSeedSecret(any))
          .thenThrow(cryptoError);

      // Act & Assert
      await expectLater(
        () => useCase.execute(query),
        throwsA(
          isA<FailedToLoadAllStoredSeedSecretsError>()
              .having((e) => e.cause, 'cause', cryptoError),
        ),
      );

      // Verify both methods were called
      verify(mockSeedSecretStore.loadAll()).called(1);
      verify(mockSeedCrypto.getFingerprintFromSeedSecret(any)).called(1);
    });

    test('should rethrow application errors without wrapping', () async {
      // Arrange
      final query = LoadAllStoredSeedSecretsQuery();

      final appError = SeedInUseError('test-fingerprint');
      when(mockSeedSecretStore.loadAll()).thenThrow(appError);

      // Act & Assert
      await expectLater(
        () => useCase.execute(query),
        throwsA(
          isA<SeedInUseError>()
              .having((e) => e.fingerprint, 'fingerprint', 'test-fingerprint'),
        ),
      );
    });
  });

  group('LoadAllStoredSeedSecretsUseCase - Verification Tests', () {
    test('should call ports in correct sequence', () async {
      // Arrange
      final query = LoadAllStoredSeedSecretsQuery();

      final secret1 = SeedMnemonicSecret(words: testMnemonicWords1);
      final secret2 = SeedMnemonicSecret(words: testMnemonicWords2);
      final secrets = [secret1, secret2];

      final callOrder = <String>[];

      when(mockSeedSecretStore.loadAll()).thenAnswer((_) async {
        callOrder.add('loadAll');
        return secrets;
      });
      when(mockSeedCrypto.getFingerprintFromSeedSecret(secret1))
          .thenAnswer((_) async {
        callOrder.add('getFingerprint-1');
        return 'fp-1';
      });
      when(mockSeedCrypto.getFingerprintFromSeedSecret(secret2))
          .thenAnswer((_) async {
        callOrder.add('getFingerprint-2');
        return 'fp-2';
      });

      // Act
      await useCase.execute(query);

      // Assert - verify loadAll is called first, then fingerprints
      expect(callOrder[0], 'loadAll');
      expect(callOrder, contains('getFingerprint-1'));
      expect(callOrder, contains('getFingerprint-2'));
    });

    test('should call loadAll exactly once in happy path', () async {
      // Arrange
      final query = LoadAllStoredSeedSecretsQuery();

      final secret = SeedMnemonicSecret(words: testMnemonicWords1);

      when(mockSeedSecretStore.loadAll()).thenAnswer((_) async => [secret]);
      when(mockSeedCrypto.getFingerprintFromSeedSecret(any))
          .thenAnswer((_) async => 'fp');

      // Act
      await useCase.execute(query);

      // Assert - verify exactly one call
      verify(mockSeedSecretStore.loadAll()).called(1);

      // Verify no other interactions with store
      verifyNoMoreInteractions(mockSeedSecretStore);
    });

    test('should call getFingerprintFromSeedSecret for each secret', () async {
      // Arrange
      final query = LoadAllStoredSeedSecretsQuery();

      final secret1 = SeedMnemonicSecret(words: testMnemonicWords1);
      final secret2 = SeedMnemonicSecret(words: testMnemonicWords2);
      final secret3 = SeedBytesSecret( List<int>.generate(32, (i) => i));

      when(mockSeedSecretStore.loadAll())
          .thenAnswer((_) async => [secret1, secret2, secret3]);
      when(mockSeedCrypto.getFingerprintFromSeedSecret(any))
          .thenAnswer((invocation) async {
        final secret = invocation.positionalArguments[0];
        if (secret == secret1) return 'fp-1';
        if (secret == secret2) return 'fp-2';
        if (secret == secret3) return 'fp-3';
        return 'unknown';
      });

      // Act
      await useCase.execute(query);

      // Assert
      verify(mockSeedCrypto.getFingerprintFromSeedSecret(secret1)).called(1);
      verify(mockSeedCrypto.getFingerprintFromSeedSecret(secret2)).called(1);
      verify(mockSeedCrypto.getFingerprintFromSeedSecret(secret3)).called(1);
    });

    test('should build map with correct fingerprint-secret pairs', () async {
      // Arrange
      final query = LoadAllStoredSeedSecretsQuery();

      final secret1 = SeedMnemonicSecret(words: testMnemonicWords1);
      final secret2 = SeedBytesSecret( [1, 2, 3, 4]);
      const fp1 = 'custom-fp-abc';
      const fp2 = 'custom-fp-xyz';

      when(mockSeedSecretStore.loadAll())
          .thenAnswer((_) async => [secret1, secret2]);
      when(mockSeedCrypto.getFingerprintFromSeedSecret(secret1))
          .thenAnswer((_) async => fp1);
      when(mockSeedCrypto.getFingerprintFromSeedSecret(secret2))
          .thenAnswer((_) async => fp2);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.secretsByFingerprint.keys, containsAll([fp1, fp2]));
      expect(result.secretsByFingerprint[fp1], same(secret1));
      expect(result.secretsByFingerprint[fp2], same(secret2));
    });

    test('should handle many secrets efficiently', () async {
      // Arrange
      final query = LoadAllStoredSeedSecretsQuery();

      final secrets = List.generate(
        10,
        (i) => SeedBytesSecret( List<int>.generate(32, (j) => i + j)),
      );

      when(mockSeedSecretStore.loadAll()).thenAnswer((_) async => secrets);
      when(mockSeedCrypto.getFingerprintFromSeedSecret(any))
          .thenAnswer((invocation) async {
        final index = secrets.indexOf(invocation.positionalArguments[0]);
        return 'fingerprint-$index';
      });

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.secretsByFingerprint.length, 10);
      for (int i = 0; i < 10; i++) {
        expect(result.secretsByFingerprint['fingerprint-$i'], secrets[i]);
      }

      // Verify loadAll called once, but fingerprint called 10 times
      verify(mockSeedSecretStore.loadAll()).called(1);
      verify(mockSeedCrypto.getFingerprintFromSeedSecret(any)).called(10);
    });
  });
}
