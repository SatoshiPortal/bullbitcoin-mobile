import 'package:bb_mobile/features/secrets/domain/entities/secret_entity.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/fingerprint.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/mnemonic_words.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/passphrase.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/seed_bytes.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_store_port.dart';
import 'package:bb_mobile/features/secrets/application/secrets_application_error.dart';
import 'package:bb_mobile/features/secrets/application/usecases/get_secret_usecase.dart';
import 'package:bb_mobile/features/secrets/domain/secrets_domain_error.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'get_secret_usecase_test.mocks.dart';

@GenerateMocks([SecretStorePort])
void main() {
  // Provide dummy for sealed class Secret
  provideDummy<Secret>(
    MnemonicSecret(
      fingerprint: Fingerprint.fromHex('abcd1234'),
      words: MnemonicWords([
        'dummy',
        'words',
        'for',
        'testing',
        'purposes',
        'only',
        'ignore',
        'this',
        'list',
        'of',
        'words',
        'here',
      ]),
    ),
  );
  late GetSecretUseCase useCase;
  late MockSecretStorePort mockSecretStore;

  // Test data
  final testFingerprint = Fingerprint.fromHex('12345678');
  final testMnemonicWords = MnemonicWords([
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

  setUp(() {
    mockSecretStore = MockSecretStorePort();

    useCase = GetSecretUseCase(secretStore: mockSecretStore);
  });

  group('GetSecretUseCase - Happy Path', () {
    test('should successfully retrieve seed secret', () async {
      // Arrange
      final query = GetSecretQuery(fingerprint: testFingerprint.value);
      final expectedSecret = MnemonicSecret(
        fingerprint: testFingerprint,
        words: testMnemonicWords,
      );

      when(mockSecretStore.load(any)).thenAnswer((_) async => expectedSecret);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.secret, isA<MnemonicSecret>());
      final mnemonicSecret = result.secret as MnemonicSecret;
      expect(mnemonicSecret.words, testMnemonicWords);
      expect(mnemonicSecret.passphrase, isNull);

      // Verify port interactions
      verify(mockSecretStore.load(testFingerprint)).called(1);
    });

    test('should successfully retrieve seed secret with passphrase', () async {
      // Arrange
      final testPassphrase = Passphrase('my-secret-passphrase');
      final query = GetSecretQuery(fingerprint: testFingerprint.value);
      final expectedSecret = MnemonicSecret(
        fingerprint: testFingerprint,
        words: testMnemonicWords,
        passphrase: testPassphrase,
      );

      when(mockSecretStore.load(any)).thenAnswer((_) async => expectedSecret);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.secret, isA<MnemonicSecret>());
      final mnemonicSecret = result.secret as MnemonicSecret;
      expect(mnemonicSecret.words, testMnemonicWords);
      expect(mnemonicSecret.passphrase, testPassphrase);

      // Verify port interactions
      verify(mockSecretStore.load(testFingerprint)).called(1);
    });

    test('should successfully retrieve seed bytes secret', () async {
      // Arrange
      final query = GetSecretQuery(fingerprint: testFingerprint.value);
      final testBytes = SeedBytes(List<int>.generate(32, (i) => i));
      final expectedSecret = SeedSecret(
        fingerprint: testFingerprint,
        bytes: testBytes,
      );

      when(mockSecretStore.load(any)).thenAnswer((_) async => expectedSecret);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.secret, isA<SeedSecret>());
      final bytesSecret = result.secret as SeedSecret;
      expect(bytesSecret.bytes, testBytes);

      // Verify port interactions
      verify(mockSecretStore.load(testFingerprint)).called(1);
    });
  });

  group('GetSecretUseCase - Error Scenarios', () {
    test(
      'should throw BusinessRuleFailed when load throws domain error',
      () async {
        // Arrange
        final query = GetSecretQuery(fingerprint: testFingerprint.value);

        final domainError = TestSecretsDomainError(
          'Invalid fingerprint format',
        );
        when(mockSecretStore.load(any)).thenThrow(domainError);

        // Act & Assert
        await expectLater(
          () => useCase.execute(query),
          throwsA(
            isA<BusinessRuleFailed>()
                .having((e) => e.domainError, 'domainError', domainError)
                .having((e) => e.cause, 'cause', domainError),
          ),
        );

        // Verify load was called
        verify(mockSecretStore.load(testFingerprint)).called(1);
      },
    );

    test('should throw FailedToGetSecretError when load fails', () async {
      // Arrange
      final query = GetSecretQuery(fingerprint: testFingerprint.value);

      final storageError = Exception('Secure storage unavailable');
      when(mockSecretStore.load(any)).thenThrow(storageError);

      // Act & Assert
      await expectLater(
        () => useCase.execute(query),
        throwsA(
          isA<FailedToGetSecretError>()
              .having((e) => e.fingerprint, 'fingerprint', testFingerprint)
              .having((e) => e.cause, 'cause', storageError),
        ),
      );

      // Verify load was called
      verify(mockSecretStore.load(testFingerprint)).called(1);
    });

    test('should rethrow application errors without wrapping', () async {
      // Arrange
      final query = GetSecretQuery(fingerprint: testFingerprint.value);

      final appError = SecretInUseError(testFingerprint.value);
      when(mockSecretStore.load(any)).thenThrow(appError);

      // Act & Assert
      await expectLater(
        () => useCase.execute(query),
        throwsA(
          isA<SecretInUseError>().having(
            (e) => e.fingerprint,
            'fingerprint',
            testFingerprint.value,
          ),
        ),
      );
    });
  });

  group('GetSecretUseCase - Verification Tests', () {
    test('should pass correct fingerprint to load', () async {
      // Arrange
      final customFingerprint = Fingerprint.fromHex('fedcba98');
      final query = GetSecretQuery(fingerprint: customFingerprint.value);
      final expectedSecret = MnemonicSecret(
        fingerprint: customFingerprint,
        words: testMnemonicWords,
      );

      when(mockSecretStore.load(any)).thenAnswer((_) async => expectedSecret);

      // Act
      await useCase.execute(query);

      // Assert
      verify(mockSecretStore.load(customFingerprint)).called(1);
    });

    test('should call load exactly once in happy path', () async {
      // Arrange
      final query = GetSecretQuery(fingerprint: testFingerprint.value);
      final expectedSecret = MnemonicSecret(
        fingerprint: testFingerprint,
        words: testMnemonicWords,
      );

      when(mockSecretStore.load(any)).thenAnswer((_) async => expectedSecret);

      // Act
      await useCase.execute(query);

      // Assert - verify exactly one call
      verify(mockSecretStore.load(any)).called(1);

      // Verify no other interactions
      verifyNoMoreInteractions(mockSecretStore);
    });

    test('should return result with loaded secret', () async {
      // Arrange
      final query = GetSecretQuery(fingerprint: testFingerprint.value);
      final testBytes = SeedBytes(List<int>.generate(64, (i) => i * 2));
      final expectedSecret = SeedSecret(
        fingerprint: testFingerprint,
        bytes: testBytes,
      );

      when(mockSecretStore.load(any)).thenAnswer((_) async => expectedSecret);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.secret, same(expectedSecret));
    });

    test('should correctly capture loaded secret', () async {
      // Arrange
      final testPassphrase = Passphrase('test-pass');
      final query = GetSecretQuery(fingerprint: testFingerprint.value);
      final expectedSecret = MnemonicSecret(
        fingerprint: testFingerprint,
        words: testMnemonicWords,
        passphrase: testPassphrase,
      );

      Secret? returnedSecret;
      when(mockSecretStore.load(any)).thenAnswer((_) async {
        returnedSecret = expectedSecret;
        return expectedSecret;
      });

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.secret, returnedSecret);
      expect(result.secret, isA<MnemonicSecret>());
      final mnemonicSecret = result.secret as MnemonicSecret;
      expect(mnemonicSecret.words, testMnemonicWords);
      expect(mnemonicSecret.passphrase, testPassphrase);
    });
  });
}
