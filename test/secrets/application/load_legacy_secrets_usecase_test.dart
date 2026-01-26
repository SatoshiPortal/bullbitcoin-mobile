import 'package:bb_mobile/features/secrets/domain/entities/secret_entity.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/fingerprint.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/mnemonic_words.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/passphrase.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/seed_bytes.dart';
import 'package:bb_mobile/features/secrets/application/ports/legacy_seed_secret_store_port.dart';
import 'package:bb_mobile/features/secrets/application/secrets_application_error.dart';
import 'package:bb_mobile/features/secrets/application/usecases/load_legacy_secrets_usecase.dart';
import 'package:bb_mobile/features/secrets/domain/secrets_domain_error.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'load_legacy_secrets_usecase_test.mocks.dart';

@GenerateMocks([LegacySecretStorePort])
void main() {
  late LoadLegacySecretsUseCase useCase;
  late MockLegacySecretStorePort mockLegacySecretStore;

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

    useCase = LoadLegacySecretsUseCase(
      legacySecretStore: mockLegacySecretStore,
    );
  });

  group('LoadLegacySecretsUseCase - Happy Path', () {
    test('should successfully load all legacy secrets', () async {
      // Arrange
      final query = LoadLegacySecretsQuery();

      final fingerprint1 = Fingerprint.fromHex('1e6ac111');
      final fingerprint2 = Fingerprint.fromHex('1e6ac222');

      final secret1 = MnemonicSecret(
        fingerprint: fingerprint1,
        words: MnemonicWords(testMnemonicWords1),
      );
      final secret2 = MnemonicSecret(
        fingerprint: fingerprint2,
        words: MnemonicWords(testMnemonicWords2),
      );
      final secrets = [secret1, secret2];

      when(mockLegacySecretStore.loadAll()).thenAnswer((_) async => secrets);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.secrets.length, 2);
      expect(result.secrets[0], secret1);
      expect(result.secrets[1], secret2);

      // Verify port interactions
      verify(mockLegacySecretStore.loadAll()).called(1);
    });

    test('should return empty list when no legacy secrets exist', () async {
      // Arrange
      final query = LoadLegacySecretsQuery();

      when(mockLegacySecretStore.loadAll()).thenAnswer((_) async => []);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.secrets, isEmpty);

      // Verify port interactions
      verify(mockLegacySecretStore.loadAll()).called(1);
    });

    test('should handle single legacy secret', () async {
      // Arrange
      final query = LoadLegacySecretsQuery();

      final fingerprint = Fingerprint.fromHex('51691e6f');
      final secret = MnemonicSecret(
        fingerprint: fingerprint,
        words: MnemonicWords(testMnemonicWords1),
      );

      when(mockLegacySecretStore.loadAll()).thenAnswer((_) async => [secret]);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.secrets.length, 1);
      expect(result.secrets[0], secret);
      expect(result.secrets[0].fingerprint, fingerprint);

      // Verify port interactions
      verify(mockLegacySecretStore.loadAll()).called(1);
    });

    test('should handle both mnemonic and seed legacy secrets', () async {
      // Arrange
      final query = LoadLegacySecretsQuery();

      final fingerprint1 = Fingerprint.fromHex('1e6acaaa');
      final fingerprint2 = Fingerprint.fromHex('1e6acbbb');

      final mnemonicSecret = MnemonicSecret(
        fingerprint: fingerprint1,
        words: MnemonicWords(testMnemonicWords1),
      );
      final seedSecret = SeedSecret(
        fingerprint: fingerprint2,
        bytes: SeedBytes(List<int>.generate(32, (i) => i)),
      );
      final secrets = [mnemonicSecret, seedSecret];

      when(mockLegacySecretStore.loadAll()).thenAnswer((_) async => secrets);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.secrets.length, 2);
      expect(result.secrets[0], mnemonicSecret);
      expect(result.secrets[1], seedSecret);
      expect(result.secrets[0].fingerprint, fingerprint1);
      expect(result.secrets[1].fingerprint, fingerprint2);

      // Verify port interactions
      verify(mockLegacySecretStore.loadAll()).called(1);
    });

    test('should handle legacy secrets with passphrases', () async {
      // Arrange
      final query = LoadLegacySecretsQuery();

      final fingerprint = Fingerprint.fromHex('1e6acccc');
      const passphraseStr = 'legacy-passphrase';
      final secret = MnemonicSecret(
        fingerprint: fingerprint,
        words: MnemonicWords(testMnemonicWords1),
        passphrase: Passphrase(passphraseStr),
      );

      when(mockLegacySecretStore.loadAll()).thenAnswer((_) async => [secret]);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.secrets.length, 1);
      expect(result.secrets[0], secret);
      final retrievedSecret = result.secrets[0] as MnemonicSecret;
      expect(retrievedSecret.passphrase?.value, passphraseStr);

      // Verify port interactions
      verify(mockLegacySecretStore.loadAll()).called(1);
    });

    test('should handle many legacy secrets efficiently', () async {
      // Arrange
      final query = LoadLegacySecretsQuery();

      final secrets = List.generate(
        10,
        (i) => SeedSecret(
          fingerprint: Fingerprint.fromHex((i * 0x11111111).toRadixString(16).padLeft(8, '0').substring(0, 8)),
          bytes: SeedBytes(List<int>.generate(32, (j) => i + j)),
        ),
      );

      when(mockLegacySecretStore.loadAll()).thenAnswer((_) async => secrets);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.secrets.length, 10);
      for (int i = 0; i < 10; i++) {
        expect(result.secrets[i], secrets[i]);
        expect(result.secrets[i].fingerprint.value, (i * 0x11111111).toRadixString(16).padLeft(8, '0').substring(0, 8));
      }

      // Verify loadAll called once
      verify(mockLegacySecretStore.loadAll()).called(1);
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

        // Verify loadAll was called
        verify(mockLegacySecretStore.loadAll()).called(1);
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
    test('should call loadAll exactly once', () async {
      // Arrange
      final query = LoadLegacySecretsQuery();

      final secret = MnemonicSecret(
        fingerprint: Fingerprint.fromHex('abcdef12'),
        words: MnemonicWords(testMnemonicWords1),
      );

      when(mockLegacySecretStore.loadAll()).thenAnswer((_) async => [secret]);

      // Act
      await useCase.execute(query);

      // Assert - verify exactly one call
      verify(mockLegacySecretStore.loadAll()).called(1);

      // Verify no other interactions with store
      verifyNoMoreInteractions(mockLegacySecretStore);
    });

    test('should preserve secret order from legacy store', () async {
      // Arrange
      final query = LoadLegacySecretsQuery();

      final secret1 = MnemonicSecret(
        fingerprint: Fingerprint.fromHex('1e9ac111'),
        words: MnemonicWords(testMnemonicWords1),
      );
      final secret2 = SeedSecret(
        fingerprint: Fingerprint.fromHex('1e9ac222'),
        bytes: SeedBytes([
          1,
          2,
          3,
          4,
          5,
          6,
          7,
          8,
          9,
          10,
          11,
          12,
          13,
          14,
          15,
          16,
        ]),
      );
      final secret3 = MnemonicSecret(
        fingerprint: Fingerprint.fromHex('1e9ac333'),
        words: MnemonicWords(testMnemonicWords2),
      );

      when(
        mockLegacySecretStore.loadAll(),
      ).thenAnswer((_) async => [secret1, secret2, secret3]);

      // Act
      final result = await useCase.execute(query);

      // Assert - verify order is preserved
      expect(result.secrets[0], same(secret1));
      expect(result.secrets[1], same(secret2));
      expect(result.secrets[2], same(secret3));
    });

    test('should use LegacySecretStorePort not SecretStorePort', () async {
      // Arrange
      final query = LoadLegacySecretsQuery();

      final secret = MnemonicSecret(
        fingerprint: Fingerprint.fromHex('fedcba98'),
        words: MnemonicWords(testMnemonicWords1),
      );

      when(mockLegacySecretStore.loadAll()).thenAnswer((_) async => [secret]);

      // Act
      await useCase.execute(query);

      // Assert - verify we're using the legacy store specifically
      verify(mockLegacySecretStore.loadAll()).called(1);
      verifyNoMoreInteractions(mockLegacySecretStore);
    });
  });
}
