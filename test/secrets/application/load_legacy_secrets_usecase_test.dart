import 'package:bb_mobile/core/primitives/secrets/secret.dart';
import 'package:bb_mobile/features/secrets/application/ports/legacy_seed_secret_store_port.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_crypto_port.dart';
import 'package:bb_mobile/features/secrets/application/secrets_application_errors.dart';
import 'package:bb_mobile/features/secrets/application/usecases/load_legacy_secrets_usecase.dart';
import 'package:bb_mobile/features/secrets/domain/secrets_domain_errors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'load_legacy_secrets_usecase_test.mocks.dart';

@GenerateMocks([LegacySecretStorePort, SecretCryptoPort])
void main() {
  late LoadLegacySecretsUseCase useCase;
  late MockLegacySecretStorePort mockLegacySecretStore;
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
    mockLegacySecretStore = MockLegacySecretStorePort();
    mockSecretCrypto = MockSecretCryptoPort();

    useCase = LoadLegacySecretsUseCase(
      legacySecretStore: mockLegacySecretStore,
      secretCrypto: mockSecretCrypto,
    );
  });

  group('LoadLegacySecretsUseCase - Happy Path', () {
    test(
      'should successfully load all legacy seed secrets with fingerprints',
      () async {
        // Arrange
        final query = LoadLegacySecretsQuery();

        final secret1 = MnemonicSecret(words: testMnemonicWords1);
        final secret2 = MnemonicSecret(words: testMnemonicWords2);
        final secrets = [secret1, secret2];

        const fingerprint1 = 'legacy-fingerprint-1';
        const fingerprint2 = 'legacy-fingerprint-2';

        when(mockLegacySecretStore.loadAll()).thenAnswer((_) async => secrets);
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
        verify(mockLegacySecretStore.loadAll()).called(1);
        verify(mockSecretCrypto.getFingerprintFromSecret(secret1)).called(1);
        verify(mockSecretCrypto.getFingerprintFromSecret(secret2)).called(1);
      },
    );

    test('should return empty map when no legacy seeds exist', () async {
      // Arrange
      final query = LoadLegacySecretsQuery();

      when(mockLegacySecretStore.loadAll()).thenAnswer((_) async => []);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.secretsByFingerprint, isEmpty);

      // Verify port interactions
      verify(mockLegacySecretStore.loadAll()).called(1);
      verifyNever(mockSecretCrypto.getFingerprintFromSecret(any));
    });

    test('should handle single legacy seed secret', () async {
      // Arrange
      final query = LoadLegacySecretsQuery();

      final secret = MnemonicSecret(words: testMnemonicWords1);
      const fingerprint = 'single-legacy-fingerprint';

      when(mockLegacySecretStore.loadAll()).thenAnswer((_) async => [secret]);
      when(
        mockSecretCrypto.getFingerprintFromSecret(secret),
      ).thenAnswer((_) async => fingerprint);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.secretsByFingerprint.length, 1);
      expect(result.secretsByFingerprint[fingerprint], secret);

      // Verify port interactions
      verify(mockLegacySecretStore.loadAll()).called(1);
      verify(mockSecretCrypto.getFingerprintFromSecret(secret)).called(1);
    });

    test('should handle both mnemonic and bytes legacy secrets', () async {
      // Arrange
      final query = LoadLegacySecretsQuery();

      final mnemonicSecret = MnemonicSecret(words: testMnemonicWords1);
      final bytesSecret = SeedSecret(List<int>.generate(32, (i) => i));
      final secrets = [mnemonicSecret, bytesSecret];

      const fingerprint1 = 'legacy-mnemonic-fp';
      const fingerprint2 = 'legacy-bytes-fp';

      when(mockLegacySecretStore.loadAll()).thenAnswer((_) async => secrets);
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
      verify(mockLegacySecretStore.loadAll()).called(1);
      verify(
        mockSecretCrypto.getFingerprintFromSecret(mnemonicSecret),
      ).called(1);
      verify(mockSecretCrypto.getFingerprintFromSecret(bytesSecret)).called(1);
    });

    test('should handle legacy secrets with passphrases', () async {
      // Arrange
      final query = LoadLegacySecretsQuery();

      const passphrase = 'legacy-passphrase';
      final secret = MnemonicSecret(
        words: testMnemonicWords1,
        passphrase: passphrase,
      );
      const fingerprint = 'legacy-passphrase-fp';

      when(mockLegacySecretStore.loadAll()).thenAnswer((_) async => [secret]);
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
      expect(retrievedSecret.passphrase, passphrase);

      // Verify port interactions
      verify(mockLegacySecretStore.loadAll()).called(1);
      verify(mockSecretCrypto.getFingerprintFromSecret(secret)).called(1);
    });
  });

  group('LoadLegacySecretsUseCase - Error Scenarios', () {
    test(
      'should throw BusinessRuleFailed when loadAll throws domain error',
      () async {
        // Arrange
        final query = LoadLegacySecretsQuery();

        final domainError = TestSecretsDomainError(
          'Legacy storage constraint violated',
        );
        when(mockLegacySecretStore.loadAll()).thenThrow(domainError);

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
        verify(mockLegacySecretStore.loadAll()).called(1);
        verifyNever(mockSecretCrypto.getFingerprintFromSecret(any));
      },
    );

    test(
      'should throw BusinessRuleFailed when getFingerprintFromSecret throws domain error',
      () async {
        // Arrange
        final query = LoadLegacySecretsQuery();

        final secret = MnemonicSecret(words: testMnemonicWords1);
        final domainError = TestSecretsDomainError(
          'Invalid legacy seed format',
        );

        when(mockLegacySecretStore.loadAll()).thenAnswer((_) async => [secret]);
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
        verify(mockLegacySecretStore.loadAll()).called(1);
        verify(mockSecretCrypto.getFingerprintFromSecret(any)).called(1);
      },
    );

    test(
      'should throw FailedToLoadLegacySecretsError when loadAll fails',
      () async {
        // Arrange
        final query = LoadLegacySecretsQuery();

        final storageError = Exception('Legacy storage unavailable');
        when(mockLegacySecretStore.loadAll()).thenThrow(storageError);

        // Act & Assert
        await expectLater(
          () => useCase.execute(query),
          throwsA(
            isA<FailedToLoadLegacySecretsError>().having(
              (e) => e.cause,
              'cause',
              storageError,
            ),
          ),
        );

        // Verify loadAll was called
        verify(mockLegacySecretStore.loadAll()).called(1);
      },
    );

    test(
      'should throw FailedToLoadLegacySecretsError when fingerprint calculation fails',
      () async {
        // Arrange
        final query = LoadLegacySecretsQuery();

        final secret = MnemonicSecret(words: testMnemonicWords1);
        final cryptoError = Exception('Crypto library error');

        when(mockLegacySecretStore.loadAll()).thenAnswer((_) async => [secret]);
        when(
          mockSecretCrypto.getFingerprintFromSecret(any),
        ).thenThrow(cryptoError);

        // Act & Assert
        await expectLater(
          () => useCase.execute(query),
          throwsA(
            isA<FailedToLoadLegacySecretsError>().having(
              (e) => e.cause,
              'cause',
              cryptoError,
            ),
          ),
        );

        // Verify both methods were called
        verify(mockLegacySecretStore.loadAll()).called(1);
        verify(mockSecretCrypto.getFingerprintFromSecret(any)).called(1);
      },
    );

    test('should rethrow application errors without wrapping', () async {
      // Arrange
      final query = LoadLegacySecretsQuery();

      final appError = SecretInUseError('test-fingerprint');
      when(mockLegacySecretStore.loadAll()).thenThrow(appError);

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

  group('LoadLegacySecretsUseCase - Verification Tests', () {
    test('should call ports in correct sequence', () async {
      // Arrange
      final query = LoadLegacySecretsQuery();

      final secret1 = MnemonicSecret(words: testMnemonicWords1);
      final secret2 = MnemonicSecret(words: testMnemonicWords2);
      final secrets = [secret1, secret2];

      final callOrder = <String>[];

      when(mockLegacySecretStore.loadAll()).thenAnswer((_) async {
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
      final query = LoadLegacySecretsQuery();

      final secret = MnemonicSecret(words: testMnemonicWords1);

      when(mockLegacySecretStore.loadAll()).thenAnswer((_) async => [secret]);
      when(
        mockSecretCrypto.getFingerprintFromSecret(any),
      ).thenAnswer((_) async => 'fp');

      // Act
      await useCase.execute(query);

      // Assert - verify exactly one call
      verify(mockLegacySecretStore.loadAll()).called(1);

      // Verify no other interactions with store
      verifyNoMoreInteractions(mockLegacySecretStore);
    });

    test(
      'should call getFingerprintFromSecret for each legacy secret',
      () async {
        // Arrange
        final query = LoadLegacySecretsQuery();

        final secret1 = MnemonicSecret(words: testMnemonicWords1);
        final secret2 = MnemonicSecret(words: testMnemonicWords2);
        final secret3 = SeedSecret(List<int>.generate(32, (i) => i));

        when(
          mockLegacySecretStore.loadAll(),
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
      },
    );

    test('should build map with correct fingerprint-secret pairs', () async {
      // Arrange
      final query = LoadLegacySecretsQuery();

      final secret1 = MnemonicSecret(words: testMnemonicWords1);
      final secret2 = SeedSecret([1, 2, 3, 4]);
      const fp1 = 'legacy-fp-abc';
      const fp2 = 'legacy-fp-xyz';

      when(
        mockLegacySecretStore.loadAll(),
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

    test('should handle many legacy seeds efficiently', () async {
      // Arrange
      final query = LoadLegacySecretsQuery();

      final secrets = List.generate(
        10,
        (i) => SeedSecret(List<int>.generate(32, (j) => i + j)),
      );

      when(mockLegacySecretStore.loadAll()).thenAnswer((_) async => secrets);
      when(mockSecretCrypto.getFingerprintFromSecret(any)).thenAnswer((
        invocation,
      ) async {
        final index = secrets.indexOf(invocation.positionalArguments[0]);
        return 'legacy-fingerprint-$index';
      });

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.secretsByFingerprint.length, 10);
      for (int i = 0; i < 10; i++) {
        expect(
          result.secretsByFingerprint['legacy-fingerprint-$i'],
          secrets[i],
        );
      }

      // Verify loadAll called once, but fingerprint called 10 times
      verify(mockLegacySecretStore.loadAll()).called(1);
      verify(mockSecretCrypto.getFingerprintFromSecret(any)).called(10);
    });

    test('should use LegacySecretStorePort not SecretStorePort', () async {
      // Arrange
      final query = LoadLegacySecretsQuery();

      final secret = MnemonicSecret(words: testMnemonicWords1);

      when(mockLegacySecretStore.loadAll()).thenAnswer((_) async => [secret]);
      when(
        mockSecretCrypto.getFingerprintFromSecret(any),
      ).thenAnswer((_) async => 'fp');

      // Act
      await useCase.execute(query);

      // Assert - verify we're using the legacy store specifically
      verify(mockLegacySecretStore.loadAll()).called(1);
      verifyNoMoreInteractions(mockLegacySecretStore);
    });
  });
}
