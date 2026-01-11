import 'package:bb_mobile/core/primitives/seeds/seed_secret.dart';
import 'package:bb_mobile/features/seeds/application/ports/legacy_seed_secret_store_port.dart';
import 'package:bb_mobile/features/seeds/application/ports/seed_crypto_port.dart';
import 'package:bb_mobile/features/seeds/application/seeds_application_errors.dart';
import 'package:bb_mobile/features/seeds/application/usecases/load_legacy_seeds_usecase.dart';
import 'package:bb_mobile/features/seeds/domain/seeds_domain_errors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'load_legacy_seeds_usecase_test.mocks.dart';

@GenerateMocks([
  LegacySeedSecretStorePort,
  SeedCryptoPort,
])
void main() {
  late LoadLegacySeedsUseCase useCase;
  late MockLegacySeedSecretStorePort mockLegacySeedSecretStore;
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
    mockLegacySeedSecretStore = MockLegacySeedSecretStorePort();
    mockSeedCrypto = MockSeedCryptoPort();

    useCase = LoadLegacySeedsUseCase(
      legacySeedSecretStore: mockLegacySeedSecretStore,
      seedCrypto: mockSeedCrypto,
    );
  });

  group('LoadLegacySeedsUseCase - Happy Path', () {
    test('should successfully load all legacy seed secrets with fingerprints',
        () async {
      // Arrange
      final query = LoadLegacySeedsQuery();

      final secret1 = SeedMnemonicSecret(words: testMnemonicWords1);
      final secret2 = SeedMnemonicSecret(words: testMnemonicWords2);
      final secrets = [secret1, secret2];

      const fingerprint1 = 'legacy-fingerprint-1';
      const fingerprint2 = 'legacy-fingerprint-2';

      when(mockLegacySeedSecretStore.loadAll()).thenAnswer((_) async => secrets);
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
      verify(mockLegacySeedSecretStore.loadAll()).called(1);
      verify(mockSeedCrypto.getFingerprintFromSeedSecret(secret1)).called(1);
      verify(mockSeedCrypto.getFingerprintFromSeedSecret(secret2)).called(1);
    });

    test('should return empty map when no legacy seeds exist', () async {
      // Arrange
      final query = LoadLegacySeedsQuery();

      when(mockLegacySeedSecretStore.loadAll()).thenAnswer((_) async => []);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.secretsByFingerprint, isEmpty);

      // Verify port interactions
      verify(mockLegacySeedSecretStore.loadAll()).called(1);
      verifyNever(mockSeedCrypto.getFingerprintFromSeedSecret(any));
    });

    test('should handle single legacy seed secret', () async {
      // Arrange
      final query = LoadLegacySeedsQuery();

      final secret = SeedMnemonicSecret(words: testMnemonicWords1);
      const fingerprint = 'single-legacy-fingerprint';

      when(mockLegacySeedSecretStore.loadAll()).thenAnswer((_) async => [secret]);
      when(mockSeedCrypto.getFingerprintFromSeedSecret(secret))
          .thenAnswer((_) async => fingerprint);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.secretsByFingerprint.length, 1);
      expect(result.secretsByFingerprint[fingerprint], secret);

      // Verify port interactions
      verify(mockLegacySeedSecretStore.loadAll()).called(1);
      verify(mockSeedCrypto.getFingerprintFromSeedSecret(secret)).called(1);
    });

    test('should handle both mnemonic and bytes legacy secrets', () async {
      // Arrange
      final query = LoadLegacySeedsQuery();

      final mnemonicSecret = SeedMnemonicSecret(words: testMnemonicWords1);
      final bytesSecret = SeedBytesSecret( List<int>.generate(32, (i) => i));
      final secrets = [mnemonicSecret, bytesSecret];

      const fingerprint1 = 'legacy-mnemonic-fp';
      const fingerprint2 = 'legacy-bytes-fp';

      when(mockLegacySeedSecretStore.loadAll()).thenAnswer((_) async => secrets);
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
      verify(mockLegacySeedSecretStore.loadAll()).called(1);
      verify(mockSeedCrypto.getFingerprintFromSeedSecret(mnemonicSecret)).called(1);
      verify(mockSeedCrypto.getFingerprintFromSeedSecret(bytesSecret)).called(1);
    });

    test('should handle legacy secrets with passphrases', () async {
      // Arrange
      final query = LoadLegacySeedsQuery();

      const passphrase = 'legacy-passphrase';
      final secret = SeedMnemonicSecret(
        words: testMnemonicWords1,
        passphrase: passphrase,
      );
      const fingerprint = 'legacy-passphrase-fp';

      when(mockLegacySeedSecretStore.loadAll()).thenAnswer((_) async => [secret]);
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
      verify(mockLegacySeedSecretStore.loadAll()).called(1);
      verify(mockSeedCrypto.getFingerprintFromSeedSecret(secret)).called(1);
    });
  });

  group('LoadLegacySeedsUseCase - Error Scenarios', () {
    test('should throw BusinessRuleFailed when loadAll throws domain error',
        () async {
      // Arrange
      final query = LoadLegacySeedsQuery();

      final domainError = TestSeedsDomainError('Legacy storage constraint violated');
      when(mockLegacySeedSecretStore.loadAll()).thenThrow(domainError);

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
      verify(mockLegacySeedSecretStore.loadAll()).called(1);
      verifyNever(mockSeedCrypto.getFingerprintFromSeedSecret(any));
    });

    test('should throw BusinessRuleFailed when getFingerprintFromSeedSecret throws domain error',
        () async {
      // Arrange
      final query = LoadLegacySeedsQuery();

      final secret = SeedMnemonicSecret(words: testMnemonicWords1);
      final domainError = TestSeedsDomainError('Invalid legacy seed format');

      when(mockLegacySeedSecretStore.loadAll()).thenAnswer((_) async => [secret]);
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
      verify(mockLegacySeedSecretStore.loadAll()).called(1);
      verify(mockSeedCrypto.getFingerprintFromSeedSecret(any)).called(1);
    });

    test('should throw FailedToLoadLegacySeedsError when loadAll fails',
        () async {
      // Arrange
      final query = LoadLegacySeedsQuery();

      final storageError = Exception('Legacy storage unavailable');
      when(mockLegacySeedSecretStore.loadAll()).thenThrow(storageError);

      // Act & Assert
      await expectLater(
        () => useCase.execute(query),
        throwsA(
          isA<FailedToLoadLegacySeedsError>()
              .having((e) => e.cause, 'cause', storageError),
        ),
      );

      // Verify loadAll was called
      verify(mockLegacySeedSecretStore.loadAll()).called(1);
    });

    test('should throw FailedToLoadLegacySeedsError when fingerprint calculation fails',
        () async {
      // Arrange
      final query = LoadLegacySeedsQuery();

      final secret = SeedMnemonicSecret(words: testMnemonicWords1);
      final cryptoError = Exception('Crypto library error');

      when(mockLegacySeedSecretStore.loadAll()).thenAnswer((_) async => [secret]);
      when(mockSeedCrypto.getFingerprintFromSeedSecret(any))
          .thenThrow(cryptoError);

      // Act & Assert
      await expectLater(
        () => useCase.execute(query),
        throwsA(
          isA<FailedToLoadLegacySeedsError>()
              .having((e) => e.cause, 'cause', cryptoError),
        ),
      );

      // Verify both methods were called
      verify(mockLegacySeedSecretStore.loadAll()).called(1);
      verify(mockSeedCrypto.getFingerprintFromSeedSecret(any)).called(1);
    });

    test('should rethrow application errors without wrapping', () async {
      // Arrange
      final query = LoadLegacySeedsQuery();

      final appError = SeedInUseError('test-fingerprint');
      when(mockLegacySeedSecretStore.loadAll()).thenThrow(appError);

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

  group('LoadLegacySeedsUseCase - Verification Tests', () {
    test('should call ports in correct sequence', () async {
      // Arrange
      final query = LoadLegacySeedsQuery();

      final secret1 = SeedMnemonicSecret(words: testMnemonicWords1);
      final secret2 = SeedMnemonicSecret(words: testMnemonicWords2);
      final secrets = [secret1, secret2];

      final callOrder = <String>[];

      when(mockLegacySeedSecretStore.loadAll()).thenAnswer((_) async {
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
      final query = LoadLegacySeedsQuery();

      final secret = SeedMnemonicSecret(words: testMnemonicWords1);

      when(mockLegacySeedSecretStore.loadAll()).thenAnswer((_) async => [secret]);
      when(mockSeedCrypto.getFingerprintFromSeedSecret(any))
          .thenAnswer((_) async => 'fp');

      // Act
      await useCase.execute(query);

      // Assert - verify exactly one call
      verify(mockLegacySeedSecretStore.loadAll()).called(1);

      // Verify no other interactions with store
      verifyNoMoreInteractions(mockLegacySeedSecretStore);
    });

    test('should call getFingerprintFromSeedSecret for each legacy secret',
        () async {
      // Arrange
      final query = LoadLegacySeedsQuery();

      final secret1 = SeedMnemonicSecret(words: testMnemonicWords1);
      final secret2 = SeedMnemonicSecret(words: testMnemonicWords2);
      final secret3 = SeedBytesSecret( List<int>.generate(32, (i) => i));

      when(mockLegacySeedSecretStore.loadAll())
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
      final query = LoadLegacySeedsQuery();

      final secret1 = SeedMnemonicSecret(words: testMnemonicWords1);
      final secret2 = SeedBytesSecret( [1, 2, 3, 4]);
      const fp1 = 'legacy-fp-abc';
      const fp2 = 'legacy-fp-xyz';

      when(mockLegacySeedSecretStore.loadAll())
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

    test('should handle many legacy seeds efficiently', () async {
      // Arrange
      final query = LoadLegacySeedsQuery();

      final secrets = List.generate(
        10,
        (i) => SeedBytesSecret( List<int>.generate(32, (j) => i + j)),
      );

      when(mockLegacySeedSecretStore.loadAll()).thenAnswer((_) async => secrets);
      when(mockSeedCrypto.getFingerprintFromSeedSecret(any))
          .thenAnswer((invocation) async {
        final index = secrets.indexOf(invocation.positionalArguments[0]);
        return 'legacy-fingerprint-$index';
      });

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.secretsByFingerprint.length, 10);
      for (int i = 0; i < 10; i++) {
        expect(result.secretsByFingerprint['legacy-fingerprint-$i'], secrets[i]);
      }

      // Verify loadAll called once, but fingerprint called 10 times
      verify(mockLegacySeedSecretStore.loadAll()).called(1);
      verify(mockSeedCrypto.getFingerprintFromSeedSecret(any)).called(10);
    });

    test('should use LegacySeedSecretStorePort not SeedSecretStorePort',
        () async {
      // Arrange
      final query = LoadLegacySeedsQuery();

      final secret = SeedMnemonicSecret(words: testMnemonicWords1);

      when(mockLegacySeedSecretStore.loadAll()).thenAnswer((_) async => [secret]);
      when(mockSeedCrypto.getFingerprintFromSeedSecret(any))
          .thenAnswer((_) async => 'fp');

      // Act
      await useCase.execute(query);

      // Assert - verify we're using the legacy store specifically
      verify(mockLegacySeedSecretStore.loadAll()).called(1);
      verifyNoMoreInteractions(mockLegacySeedSecretStore);
    });
  });
}
