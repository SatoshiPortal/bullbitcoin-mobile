import 'package:bb_mobile/features/secrets/domain/entities/secret_entity.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/fingerprint.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/mnemonic_words.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/passphrase.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/seed_bytes.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_store_port.dart';
import 'package:bb_mobile/features/secrets/application/secrets_application_error.dart';
import 'package:bb_mobile/features/secrets/application/usecases/load_all_stored_secrets_usecase.dart';
import 'package:bb_mobile/features/secrets/domain/secrets_domain_error.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'load_all_stored_secrets_usecase_test.mocks.dart';

@GenerateMocks([SecretStorePort])
void main() {
  late LoadAllStoredSecretsUseCase useCase;
  late MockSecretStorePort mockSecretStore;

  // Test data
  final testMnemonicWords1 = MnemonicWords([
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
  ]);

  final testMnemonicWords2 = MnemonicWords([
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
  ]);

  setUp(() {
    mockSecretStore = MockSecretStorePort();

    useCase = LoadAllStoredSecretsUseCase(secretStore: mockSecretStore);
  });

  group('LoadAllStoredSecretsUseCase - Happy Path', () {
    test('should successfully load all stored secrets', () async {
      // Arrange
      final query = LoadAllStoredSecretsQuery();

      final fingerprint1 = Fingerprint.fromHex('aaaa1111');
      final fingerprint2 = Fingerprint.fromHex('bbbb2222');

      final secret1 = MnemonicSecret(
        fingerprint: fingerprint1,
        words: testMnemonicWords1,
      );
      final secret2 = MnemonicSecret(
        fingerprint: fingerprint2,
        words: testMnemonicWords2,
      );
      final secrets = [secret1, secret2];

      when(mockSecretStore.loadAll()).thenAnswer((_) async => secrets);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.secrets.length, 2);
      expect(result.secrets[0], secret1);
      expect(result.secrets[1], secret2);

      // Verify port interactions
      verify(mockSecretStore.loadAll()).called(1);
    });

    test('should return empty list when no secrets are stored', () async {
      // Arrange
      final query = LoadAllStoredSecretsQuery();

      when(mockSecretStore.loadAll()).thenAnswer((_) async => []);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.secrets, isEmpty);

      // Verify port interactions
      verify(mockSecretStore.loadAll()).called(1);
    });

    test('should handle single secret', () async {
      // Arrange
      final query = LoadAllStoredSecretsQuery();

      final fingerprint = Fingerprint.fromHex('51691e00');
      final secret = MnemonicSecret(
        fingerprint: fingerprint,
        words: testMnemonicWords1,
      );

      when(mockSecretStore.loadAll()).thenAnswer((_) async => [secret]);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.secrets.length, 1);
      expect(result.secrets[0], secret);
      expect(result.secrets[0].fingerprint, fingerprint);

      // Verify port interactions
      verify(mockSecretStore.loadAll()).called(1);
    });

    test('should handle both mnemonic and seed secrets', () async {
      // Arrange
      final query = LoadAllStoredSecretsQuery();

      final fingerprint1 = Fingerprint.fromHex('ccccddd1');
      final fingerprint2 = Fingerprint.fromHex('ccccddd2');

      final mnemonicSecret = MnemonicSecret(
        fingerprint: fingerprint1,
        words: testMnemonicWords1,
      );
      final seedSecret = SeedSecret(
        fingerprint: fingerprint2,
        bytes: SeedBytes(List<int>.generate(32, (i) => i)),
      );
      final secrets = [mnemonicSecret, seedSecret];

      when(mockSecretStore.loadAll()).thenAnswer((_) async => secrets);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.secrets.length, 2);
      expect(result.secrets[0], mnemonicSecret);
      expect(result.secrets[1], seedSecret);
      expect(result.secrets[0].fingerprint, fingerprint1);
      expect(result.secrets[1].fingerprint, fingerprint2);

      // Verify port interactions
      verify(mockSecretStore.loadAll()).called(1);
    });

    test('should handle secrets with passphrases', () async {
      // Arrange
      final query = LoadAllStoredSecretsQuery();

      final fingerprint = Fingerprint.fromHex('feedface');
      const passphraseStr = 'my-passphrase';
      final secret = MnemonicSecret(
        fingerprint: fingerprint,
        words: testMnemonicWords1,
        passphrase: Passphrase(passphraseStr),
      );

      when(mockSecretStore.loadAll()).thenAnswer((_) async => [secret]);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.secrets.length, 1);
      expect(result.secrets[0], secret);
      final retrievedSecret = result.secrets[0] as MnemonicSecret;
      expect(retrievedSecret.passphrase?.value, passphraseStr);

      // Verify port interactions
      verify(mockSecretStore.loadAll()).called(1);
    });

    test('should handle many secrets efficiently', () async {
      // Arrange
      final query = LoadAllStoredSecretsQuery();

      final secrets = List.generate(
        10,
        (i) => SeedSecret(
          fingerprint: Fingerprint.fromHex((i * 0x11111111).toRadixString(16).padLeft(8, '0').substring(0, 8)),
          bytes: SeedBytes(List<int>.generate(32, (j) => i + j)),
        ),
      );

      when(mockSecretStore.loadAll()).thenAnswer((_) async => secrets);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.secrets.length, 10);
      for (int i = 0; i < 10; i++) {
        expect(result.secrets[i], secrets[i]);
        expect(result.secrets[i].fingerprint.value, (i * 0x11111111).toRadixString(16).padLeft(8, '0').substring(0, 8));
      }

      // Verify loadAll called once
      verify(mockSecretStore.loadAll()).called(1);
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

        // Verify loadAll was called
        verify(mockSecretStore.loadAll()).called(1);
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
    test('should call loadAll exactly once', () async {
      // Arrange
      final query = LoadAllStoredSecretsQuery();

      final secret = MnemonicSecret(
        fingerprint: Fingerprint.fromHex('abcd1234'),
        words: testMnemonicWords1,
      );

      when(mockSecretStore.loadAll()).thenAnswer((_) async => [secret]);

      // Act
      await useCase.execute(query);

      // Assert - verify exactly one call
      verify(mockSecretStore.loadAll()).called(1);

      // Verify no other interactions with store
      verifyNoMoreInteractions(mockSecretStore);
    });

    test('should preserve secret order from store', () async {
      // Arrange
      final query = LoadAllStoredSecretsQuery();

      final secret1 = MnemonicSecret(
        fingerprint: Fingerprint.fromHex('dddddd11'),
        words: testMnemonicWords1,
      );
      final secret2 = SeedSecret(
        fingerprint: Fingerprint.fromHex('dddddd22'),
        bytes: SeedBytes(List<int>.generate(16, (i) => i + 1)),
      );
      final secret3 = MnemonicSecret(
        fingerprint: Fingerprint.fromHex('dddddd33'),
        words: testMnemonicWords2,
      );

      when(
        mockSecretStore.loadAll(),
      ).thenAnswer((_) async => [secret1, secret2, secret3]);

      // Act
      final result = await useCase.execute(query);

      // Assert - verify order is preserved
      expect(result.secrets[0], same(secret1));
      expect(result.secrets[1], same(secret2));
      expect(result.secrets[2], same(secret3));
    });
  });
}
