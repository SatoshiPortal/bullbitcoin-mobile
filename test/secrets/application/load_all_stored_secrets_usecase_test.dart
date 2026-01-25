import 'package:bb_mobile/features/secrets/domain/secret.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/mnemonic_words.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/passphrase.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/seed_bytes.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_crypto_port.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_store_port.dart';
import 'package:bb_mobile/features/secrets/application/secrets_application_errors.dart';
import 'package:bb_mobile/features/secrets/application/usecases/load_all_stored_secrets_usecase.dart';
import 'package:bb_mobile/features/secrets/domain/secrets_domain_errors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'load_all_stored_secrets_usecase_test.mocks.dart';

@GenerateMocks([SecretStorePort, SecretCryptoPort])
void main() {
  late LoadAllStoredSecretsUseCase useCase;
  late MockSecretStorePort mockSecretStore;
  late MockSecretCryptoPort mockSecretCrypto;

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
    mockSecretStore = MockSecretStorePort();
    mockSecretCrypto = MockSecretCryptoPort();

    useCase = LoadAllStoredSecretsUseCase(
      secretStore: mockSecretStore,
      secretCrypto: mockSecretCrypto,
    );
  });

  group('LoadAllStoredSecretsUseCase - Happy Path', () {
    test(
      'should successfully load all seed secrets with fingerprints',
      () async {
        // Arrange
        final query = LoadAllStoredSecretsQuery();

        final secret1 = MnemonicSecret(words: MnemonicWords(testMnemonicWords1));
        final secret2 = MnemonicSecret(words: MnemonicWords(testMnemonicWords2));
        final secrets = [secret1, secret2];

        const fingerprint1 = 'fingerprint-1';
        const fingerprint2 = 'fingerprint-2';

        when(mockSecretStore.loadAll()).thenAnswer((_) async => secrets);
        when(
          mockSecretCrypto.getFingerprintFromSecret(secret1),
        ).thenAnswer((_) async => fingerprint1);
        when(
          mockSecretCrypto.getFingerprintFromSecret(secret2),
        ).thenAnswer((_) async => fingerprint2);

        // Act
        final result = await useCase.execute(query);

        // Assert
        expect(result.secretsByFingerprint.length, 2);
        expect(result.secretsByFingerprint[fingerprint1], secret1);
        expect(result.secretsByFingerprint[fingerprint2], secret2);

        // Verify port interactions
        verify(mockSecretStore.loadAll()).called(1);
        verify(mockSecretCrypto.getFingerprintFromSecret(secret1)).called(1);
        verify(mockSecretCrypto.getFingerprintFromSecret(secret2)).called(1);
      },
    );

    test('should return empty map when no secrets are stored', () async {
      // Arrange
      final query = LoadAllStoredSecretsQuery();

      when(mockSecretStore.loadAll()).thenAnswer((_) async => []);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.secretsByFingerprint, isEmpty);

      // Verify port interactions
      verify(mockSecretStore.loadAll()).called(1);
      verifyNever(mockSecretCrypto.getFingerprintFromSecret(any));
    });

    test('should handle single seed secret', () async {
      // Arrange
      final query = LoadAllStoredSecretsQuery();

      final secret = MnemonicSecret(words: MnemonicWords(testMnemonicWords1));
      const fingerprint = 'single-fingerprint';

      when(mockSecretStore.loadAll()).thenAnswer((_) async => [secret]);
      when(
        mockSecretCrypto.getFingerprintFromSecret(secret),
      ).thenAnswer((_) async => fingerprint);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.secretsByFingerprint.length, 1);
      expect(result.secretsByFingerprint[fingerprint], secret);

      // Verify port interactions
      verify(mockSecretStore.loadAll()).called(1);
      verify(mockSecretCrypto.getFingerprintFromSecret(secret)).called(1);
    });

    test('should handle both mnemonic and bytes secrets', () async {
      // Arrange
      final query = LoadAllStoredSecretsQuery();

      final mnemonicSecret = MnemonicSecret(words: MnemonicWords(testMnemonicWords1));
      final bytesSecret = SeedSecret(SeedBytes(List<int>.generate(32, (i) => i)));
      final secrets = [mnemonicSecret, bytesSecret];

      const fingerprint1 = 'mnemonic-fp';
      const fingerprint2 = 'bytes-fp';

      when(mockSecretStore.loadAll()).thenAnswer((_) async => secrets);
      when(
        mockSecretCrypto.getFingerprintFromSecret(mnemonicSecret),
      ).thenAnswer((_) async => fingerprint1);
      when(
        mockSecretCrypto.getFingerprintFromSecret(bytesSecret),
      ).thenAnswer((_) async => fingerprint2);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.secretsByFingerprint.length, 2);
      expect(result.secretsByFingerprint[fingerprint1], mnemonicSecret);
      expect(result.secretsByFingerprint[fingerprint2], bytesSecret);

      // Verify port interactions
      verify(mockSecretStore.loadAll()).called(1);
      verify(
        mockSecretCrypto.getFingerprintFromSecret(mnemonicSecret),
      ).called(1);
      verify(mockSecretCrypto.getFingerprintFromSecret(bytesSecret)).called(1);
    });

    test('should handle secrets with passphrases', () async {
      // Arrange
      final query = LoadAllStoredSecretsQuery();

      const passphraseStr = 'my-passphrase';
      final secret = MnemonicSecret(
        words: MnemonicWords(testMnemonicWords1),
        passphrase: Passphrase(passphraseStr),
      );
      const fingerprint = 'passphrase-fp';

      when(mockSecretStore.loadAll()).thenAnswer((_) async => [secret]);
      when(
        mockSecretCrypto.getFingerprintFromSecret(secret),
      ).thenAnswer((_) async => fingerprint);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.secretsByFingerprint.length, 1);
      expect(result.secretsByFingerprint[fingerprint], secret);
      final retrievedSecret =
          result.secretsByFingerprint[fingerprint] as MnemonicSecret;
      expect(retrievedSecret.passphrase?.value, passphraseStr);

      // Verify port interactions
      verify(mockSecretStore.loadAll()).called(1);
      verify(mockSecretCrypto.getFingerprintFromSecret(secret)).called(1);
    });
  });

  group('LoadAllStoredSecretsUseCase - Error Scenarios', () {
    test(
      'should throw BusinessRuleFailed when loadAll throws domain error',
      () async {
        // Arrange
        final query = LoadAllStoredSecretsQuery();

        final domainError = TestSecretsDomainError(
          'Storage constraint violated',
        );
        when(mockSecretStore.loadAll()).thenThrow(domainError);

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
        verify(mockSecretStore.loadAll()).called(1);
        verifyNever(mockSecretCrypto.getFingerprintFromSecret(any));
      },
    );

    test(
      'should throw BusinessRuleFailed when getFingerprintFromSecret throws domain error',
      () async {
        // Arrange
        final query = LoadAllStoredSecretsQuery();

        final secret = MnemonicSecret(words: MnemonicWords(testMnemonicWords1));
        final domainError = TestSecretsDomainError('Invalid seed format');

        when(mockSecretStore.loadAll()).thenAnswer((_) async => [secret]);
        when(
          mockSecretCrypto.getFingerprintFromSecret(any),
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

        // Verify both methods were called
        verify(mockSecretStore.loadAll()).called(1);
        verify(mockSecretCrypto.getFingerprintFromSecret(any)).called(1);
      },
    );

    test(
      'should throw FailedToLoadAllStoredSecretsError when loadAll fails',
      () async {
        // Arrange
        final query = LoadAllStoredSecretsQuery();

        final storageError = Exception('Secure storage unavailable');
        when(mockSecretStore.loadAll()).thenThrow(storageError);

        // Act & Assert
        await expectLater(
          () => useCase.execute(query),
          throwsA(
            isA<FailedToLoadAllStoredSecretsError>().having(
              (e) => e.cause,
              'cause',
              storageError,
            ),
          ),
        );

        // Verify loadAll was called
        verify(mockSecretStore.loadAll()).called(1);
      },
    );

    test(
      'should throw FailedToLoadAllStoredSecretsError when fingerprint calculation fails',
      () async {
        // Arrange
        final query = LoadAllStoredSecretsQuery();

        final secret = MnemonicSecret(words: MnemonicWords(testMnemonicWords1));
        final cryptoError = Exception('Crypto library error');

        when(mockSecretStore.loadAll()).thenAnswer((_) async => [secret]);
        when(
          mockSecretCrypto.getFingerprintFromSecret(any),
        ).thenThrow(cryptoError);

        // Act & Assert
        await expectLater(
          () => useCase.execute(query),
          throwsA(
            isA<FailedToLoadAllStoredSecretsError>().having(
              (e) => e.cause,
              'cause',
              cryptoError,
            ),
          ),
        );

        // Verify both methods were called
        verify(mockSecretStore.loadAll()).called(1);
        verify(mockSecretCrypto.getFingerprintFromSecret(any)).called(1);
      },
    );

    test('should rethrow application errors without wrapping', () async {
      // Arrange
      final query = LoadAllStoredSecretsQuery();

      final appError = SecretInUseError('test-fingerprint');
      when(mockSecretStore.loadAll()).thenThrow(appError);

      // Act & Assert
      await expectLater(
        () => useCase.execute(query),
        throwsA(
          isA<SecretInUseError>().having(
            (e) => e.fingerprint,
            'fingerprint',
            'test-fingerprint',
          ),
        ),
      );
    });
  });

  group('LoadAllStoredSecretsUseCase - Verification Tests', () {
    test('should call ports in correct sequence', () async {
      // Arrange
      final query = LoadAllStoredSecretsQuery();

      final secret1 = MnemonicSecret(words: MnemonicWords(testMnemonicWords1));
      final secret2 = MnemonicSecret(words: MnemonicWords(testMnemonicWords2));
      final secrets = [secret1, secret2];

      final callOrder = <String>[];

      when(mockSecretStore.loadAll()).thenAnswer((_) async {
        callOrder.add('loadAll');
        return secrets;
      });
      when(mockSecretCrypto.getFingerprintFromSecret(secret1)).thenAnswer((
        _,
      ) async {
        callOrder.add('getFingerprint-1');
        return 'fp-1';
      });
      when(mockSecretCrypto.getFingerprintFromSecret(secret2)).thenAnswer((
        _,
      ) async {
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
      final query = LoadAllStoredSecretsQuery();

      final secret = MnemonicSecret(words: MnemonicWords(testMnemonicWords1));

      when(mockSecretStore.loadAll()).thenAnswer((_) async => [secret]);
      when(
        mockSecretCrypto.getFingerprintFromSecret(any),
      ).thenAnswer((_) async => 'fp');

      // Act
      await useCase.execute(query);

      // Assert - verify exactly one call
      verify(mockSecretStore.loadAll()).called(1);

      // Verify no other interactions with store
      verifyNoMoreInteractions(mockSecretStore);
    });

    test('should call getFingerprintFromSecret for each secret', () async {
      // Arrange
      final query = LoadAllStoredSecretsQuery();

      final secret1 = MnemonicSecret(words: MnemonicWords(testMnemonicWords1));
      final secret2 = MnemonicSecret(words: MnemonicWords(testMnemonicWords2));
      final secret3 = SeedSecret(SeedBytes(List<int>.generate(32, (i) => i)));

      when(
        mockSecretStore.loadAll(),
      ).thenAnswer((_) async => [secret1, secret2, secret3]);
      when(mockSecretCrypto.getFingerprintFromSecret(any)).thenAnswer((
        invocation,
      ) async {
        final secret = invocation.positionalArguments[0];
        if (secret == secret1) return 'fp-1';
        if (secret == secret2) return 'fp-2';
        if (secret == secret3) return 'fp-3';
        return 'unknown';
      });

      // Act
      await useCase.execute(query);

      // Assert
      verify(mockSecretCrypto.getFingerprintFromSecret(secret1)).called(1);
      verify(mockSecretCrypto.getFingerprintFromSecret(secret2)).called(1);
      verify(mockSecretCrypto.getFingerprintFromSecret(secret3)).called(1);
    });

    test('should build map with correct fingerprint-secret pairs', () async {
      // Arrange
      final query = LoadAllStoredSecretsQuery();

      final secret1 = MnemonicSecret(words: MnemonicWords(testMnemonicWords1));
      final secret2 = SeedSecret(SeedBytes([1, 2, 3, 4]));
      const fp1 = 'custom-fp-abc';
      const fp2 = 'custom-fp-xyz';

      when(
        mockSecretStore.loadAll(),
      ).thenAnswer((_) async => [secret1, secret2]);
      when(
        mockSecretCrypto.getFingerprintFromSecret(secret1),
      ).thenAnswer((_) async => fp1);
      when(
        mockSecretCrypto.getFingerprintFromSecret(secret2),
      ).thenAnswer((_) async => fp2);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.secretsByFingerprint.keys, containsAll([fp1, fp2]));
      expect(result.secretsByFingerprint[fp1], same(secret1));
      expect(result.secretsByFingerprint[fp2], same(secret2));
    });

    test('should handle many secrets efficiently', () async {
      // Arrange
      final query = LoadAllStoredSecretsQuery();

      final secrets = List.generate(
        10,
        (i) => SeedSecret(SeedBytes(List<int>.generate(32, (j) => i + j))),
      );

      when(mockSecretStore.loadAll()).thenAnswer((_) async => secrets);
      when(mockSecretCrypto.getFingerprintFromSecret(any)).thenAnswer((
        invocation,
      ) async {
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
      verify(mockSecretStore.loadAll()).called(1);
      verify(mockSecretCrypto.getFingerprintFromSecret(any)).called(10);
    });
  });
}
