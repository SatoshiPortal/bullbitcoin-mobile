import 'package:bb_mobile/core/primitives/seeds/seed_secret.dart';
import 'package:bb_mobile/features/seeds/application/ports/seed_secret_store_port.dart';
import 'package:bb_mobile/features/seeds/application/seeds_application_errors.dart';
import 'package:bb_mobile/features/seeds/application/usecases/get_seed_secret_usecase.dart';
import 'package:bb_mobile/features/seeds/domain/seeds_domain_errors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'get_seed_secret_usecase_test.mocks.dart';

@GenerateMocks([
  SeedSecretStorePort,
])
void main() {
  // Provide dummy for sealed class SeedSecret
  provideDummy<SeedSecret>(SeedMnemonicSecret(words: ['dummy']));
  late GetSeedSecretUseCase useCase;
  late MockSeedSecretStorePort mockSeedSecretStore;

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
    mockSeedSecretStore = MockSeedSecretStorePort();

    useCase = GetSeedSecretUseCase(
      seedSecretStore: mockSeedSecretStore,
    );
  });

  group('GetSeedSecretUseCase - Happy Path', () {
    test('should successfully retrieve seed secret', () async {
      // Arrange
      final query = GetSeedSecretQuery(fingerprint: testFingerprint);
      final expectedSecret = SeedMnemonicSecret(words: testMnemonicWords);

      when(mockSeedSecretStore.load(any)).thenAnswer((_) async => expectedSecret);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.secret, isA<SeedMnemonicSecret>());
      final mnemonicSecret = result.secret as SeedMnemonicSecret;
      expect(mnemonicSecret.words, testMnemonicWords);
      expect(mnemonicSecret.passphrase, isNull);

      // Verify port interactions
      verify(mockSeedSecretStore.load(testFingerprint)).called(1);
    });

    test('should successfully retrieve seed secret with passphrase', () async {
      // Arrange
      const testPassphrase = 'my-secret-passphrase';
      final query = GetSeedSecretQuery(fingerprint: testFingerprint);
      final expectedSecret = SeedMnemonicSecret(
        words: testMnemonicWords,
        passphrase: testPassphrase,
      );

      when(mockSeedSecretStore.load(any)).thenAnswer((_) async => expectedSecret);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.secret, isA<SeedMnemonicSecret>());
      final mnemonicSecret = result.secret as SeedMnemonicSecret;
      expect(mnemonicSecret.words, testMnemonicWords);
      expect(mnemonicSecret.passphrase, testPassphrase);

      // Verify port interactions
      verify(mockSeedSecretStore.load(testFingerprint)).called(1);
    });

    test('should successfully retrieve seed bytes secret', () async {
      // Arrange
      final query = GetSeedSecretQuery(fingerprint: testFingerprint);
      final testBytes = List<int>.generate(32, (i) => i);
      final expectedSecret = SeedBytesSecret( testBytes);

      when(mockSeedSecretStore.load(any)).thenAnswer((_) async => expectedSecret);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.secret, isA<SeedBytesSecret>());
      final bytesSecret = result.secret as SeedBytesSecret;
      expect(bytesSecret.bytes, testBytes);

      // Verify port interactions
      verify(mockSeedSecretStore.load(testFingerprint)).called(1);
    });
  });

  group('GetSeedSecretUseCase - Error Scenarios', () {
    test('should throw BusinessRuleFailed when load throws domain error',
        () async {
      // Arrange
      final query = GetSeedSecretQuery(fingerprint: testFingerprint);

      final domainError = TestSeedsDomainError('Invalid fingerprint format');
      when(mockSeedSecretStore.load(any)).thenThrow(domainError);

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
      verify(mockSeedSecretStore.load(testFingerprint)).called(1);
    });

    test('should throw FailedToGetSeedSecretError when load fails', () async {
      // Arrange
      final query = GetSeedSecretQuery(fingerprint: testFingerprint);

      final storageError = Exception('Secure storage unavailable');
      when(mockSeedSecretStore.load(any)).thenThrow(storageError);

      // Act & Assert
      await expectLater(
        () => useCase.execute(query),
        throwsA(
          isA<FailedToGetSeedSecretError>()
              .having((e) => e.fingerprint, 'fingerprint', testFingerprint)
              .having((e) => e.cause, 'cause', storageError),
        ),
      );

      // Verify load was called
      verify(mockSeedSecretStore.load(testFingerprint)).called(1);
    });

    test('should rethrow application errors without wrapping', () async {
      // Arrange
      final query = GetSeedSecretQuery(fingerprint: testFingerprint);

      final appError = SeedInUseError(testFingerprint);
      when(mockSeedSecretStore.load(any)).thenThrow(appError);

      // Act & Assert
      await expectLater(
        () => useCase.execute(query),
        throwsA(
          isA<SeedInUseError>()
              .having((e) => e.fingerprint, 'fingerprint', testFingerprint),
        ),
      );
    });
  });

  group('GetSeedSecretUseCase - Verification Tests', () {
    test('should pass correct fingerprint to load', () async {
      // Arrange
      const customFingerprint = 'custom-fp-xyz789';
      final query = GetSeedSecretQuery(fingerprint: customFingerprint);
      final expectedSecret = SeedMnemonicSecret(words: testMnemonicWords);

      when(mockSeedSecretStore.load(any)).thenAnswer((_) async => expectedSecret);

      // Act
      await useCase.execute(query);

      // Assert
      verify(mockSeedSecretStore.load(customFingerprint)).called(1);
    });

    test('should call load exactly once in happy path', () async {
      // Arrange
      final query = GetSeedSecretQuery(fingerprint: testFingerprint);
      final expectedSecret = SeedMnemonicSecret(words: testMnemonicWords);

      when(mockSeedSecretStore.load(any)).thenAnswer((_) async => expectedSecret);

      // Act
      await useCase.execute(query);

      // Assert - verify exactly one call
      verify(mockSeedSecretStore.load(any)).called(1);

      // Verify no other interactions
      verifyNoMoreInteractions(mockSeedSecretStore);
    });

    test('should return result with loaded secret', () async {
      // Arrange
      final query = GetSeedSecretQuery(fingerprint: testFingerprint);
      final testBytes = List<int>.generate(64, (i) => i * 2);
      final expectedSecret = SeedBytesSecret( testBytes);

      when(mockSeedSecretStore.load(any)).thenAnswer((_) async => expectedSecret);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.secret, same(expectedSecret));
    });

    test('should correctly capture loaded secret', () async {
      // Arrange
      const testPassphrase = 'test-pass';
      final query = GetSeedSecretQuery(fingerprint: testFingerprint);
      final expectedSecret = SeedMnemonicSecret(
        words: testMnemonicWords,
        passphrase: testPassphrase,
      );

      SeedSecret? returnedSecret;
      when(mockSeedSecretStore.load(any)).thenAnswer((_) async {
        returnedSecret = expectedSecret;
        return expectedSecret;
      });

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.secret, returnedSecret);
      expect(result.secret, isA<SeedMnemonicSecret>());
      final mnemonicSecret = result.secret as SeedMnemonicSecret;
      expect(mnemonicSecret.words, testMnemonicWords);
      expect(mnemonicSecret.passphrase, testPassphrase);
    });
  });
}
