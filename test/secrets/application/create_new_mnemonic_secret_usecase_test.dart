import 'package:bb_mobile/features/secrets/domain/entities/secret_entity.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/mnemonic_words.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/passphrase.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/secret_usage_id.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/secret_consumer.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/fingerprint.dart';
import 'package:bb_mobile/features/secrets/application/ports/mnemonic_generator_port.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_crypto_port.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_store_port.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_usage_repository_port.dart';
import 'package:bb_mobile/features/secrets/application/secrets_application_error.dart';
import 'package:bb_mobile/features/secrets/application/usecases/create_new_mnemonic_secret_usecase.dart';
import 'package:bb_mobile/features/secrets/domain/entities/secret_usage_entity.dart';
import 'package:bb_mobile/features/secrets/domain/secrets_domain_error.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'create_new_mnemonic_secret_usecase_test.mocks.dart';

@GenerateMocks([
  MnemonicGeneratorPort,
  SecretCryptoPort,
  SecretStorePort,
  SecretUsageRepositoryPort,
])
void main() {
  late CreateNewMnemonicSecretUseCase useCase;
  late MockMnemonicGeneratorPort mockMnemonicGenerator;
  late MockSecretCryptoPort mockSecretCrypto;
  late MockSecretStorePort mockSecretStore;
  late MockSecretUsageRepositoryPort mockSecretUsageRepository;

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
    mockMnemonicGenerator = MockMnemonicGeneratorPort();
    mockSecretCrypto = MockSecretCryptoPort();
    mockSecretStore = MockSecretStorePort();
    mockSecretUsageRepository = MockSecretUsageRepositoryPort();

    useCase = CreateNewMnemonicSecretUseCase(
      mnemonicGenerator: mockMnemonicGenerator,
      secretCrypto: mockSecretCrypto,
      secretStore: mockSecretStore,
      secretUsageRepository: mockSecretUsageRepository,
    );
  });

  group('CreateNewSecretMnemonicUseCase - Happy Path', () {
    test('should successfully create new seed without passphrase', () async {
      // Arrange
      final command = CreateNewMnemonicSecretCommand.forWallet(
        walletId: 'wallet-123',
      );

      when(
        mockMnemonicGenerator.generateMnemonic(),
      ).thenAnswer((_) async => testMnemonicWords);
      when(
        mockSecretCrypto.getFingerprintFromMnemonic(
          mnemonicWords: testMnemonicWords,
          passphrase: null,
        ),
      ).thenAnswer((_) => testFingerprint);
      when(mockSecretStore.save(any)).thenAnswer((_) async {
        return;
      });
      when(
        mockSecretUsageRepository.add(
          fingerprint: anyNamed('fingerprint'),
          consumer: anyNamed('consumer'),
        ),
      ).thenAnswer((_) async => _createTestSecretUsage());

      // Act
      final result = await useCase.execute(command);

      // Assert
      expect(result.secret, isA<MnemonicSecret>());

      final secret = result.secret;
      expect(secret.words, testMnemonicWords);
      expect(secret.passphrase, isNull);

      // Verify port interactions
      verify(mockMnemonicGenerator.generateMnemonic()).called(1);
      verify(
        mockSecretCrypto.getFingerprintFromMnemonic(
          mnemonicWords: testMnemonicWords,
          passphrase: null,
        ),
      ).called(1);
      verify(
        mockSecretStore.save(
          argThat(
            isA<MnemonicSecret>()
                .having((s) => s.words, 'words', testMnemonicWords)
                .having((s) => s.passphrase, 'passphrase', isNull),
          ),
        ),
      ).called(1);
      verify(
        mockSecretUsageRepository.add(
          fingerprint: testFingerprint,
          consumer: argThat(
            isA<WalletConsumer>().having(
              (c) => c.walletId,
              'walletId',
              'wallet-123',
            ),
            named: 'consumer',
          ),
        ),
      ).called(1);
    });

    test('should successfully create new seed with passphrase', () async {
      // Arrange
      const testPassphraseStr = 'super-secret-passphrase';
      final command = CreateNewMnemonicSecretCommand.forBip85(
        bip85Path: "m/83696968'/0'/0'",
        passphrase: testPassphraseStr,
      );

      when(
        mockMnemonicGenerator.generateMnemonic(),
      ).thenAnswer((_) async => testMnemonicWords);
      when(
        mockSecretCrypto.getFingerprintFromMnemonic(
          mnemonicWords: anyNamed('mnemonicWords'),
          passphrase: anyNamed('passphrase'),
        ),
      ).thenAnswer((_) => testFingerprint);
      when(mockSecretStore.save(any)).thenAnswer((_) async {
        return;
      });
      when(
        mockSecretUsageRepository.add(
          fingerprint: anyNamed('fingerprint'),
          consumer: anyNamed('consumer'),
        ),
      ).thenAnswer((_) async => _createTestSecretUsage());

      // Act
      final result = await useCase.execute(command);

      // Assert
      expect(result.secret, isA<MnemonicSecret>());

      final secret = result.secret;
      expect(secret.words, testMnemonicWords);
      expect(secret.passphrase, isA<Passphrase>());
      expect(secret.passphrase!.value, testPassphraseStr);

      // Verify passphrase was passed correctly
      verify(
        mockSecretStore.save(
          argThat(
            isA<MnemonicSecret>()
                .having((s) => s.words, 'words', testMnemonicWords)
                .having(
                  (s) => s.passphrase?.value,
                  'passphrase',
                  testPassphraseStr,
                ),
          ),
        ),
      ).called(1);
      verify(
        mockSecretUsageRepository.add(
          fingerprint: testFingerprint,
          consumer: argThat(
            isA<Bip85Consumer>().having(
              (c) => c.bip85Path,
              'bip85Path',
              "m/83696968'/0'/0'",
            ),
            named: 'consumer',
          ),
        ),
      ).called(1);
    });
  });

  group('CreateNewMnemonicSecretUseCase - Input Validation', () {
    test(
      'should throw InvalidPassphraseInputError when passphrase too long',
      () async {
        // Arrange
        final longPassphrase = 'a' * 257; // 257 characters, max is 256
        final command = CreateNewMnemonicSecretCommand.forWallet(
          walletId: 'wallet-123',
          passphrase: longPassphrase,
        );

        // Act & Assert
        await expectLater(
          () => useCase.execute(command),
          throwsA(
            isA<InvalidPassphraseInputError>()
                .having((e) => e.length, 'length', 257)
                .having(
                  (e) => e.message,
                  'message',
                  contains('Passphrase too long'),
                ),
          ),
        );

        // Verify no other ports were called (validation happens before generation)
        verifyNever(mockMnemonicGenerator.generateMnemonic());
        verifyNever(
          mockSecretCrypto.getFingerprintFromMnemonic(
            mnemonicWords: anyNamed('mnemonicWords'),
            passphrase: anyNamed('passphrase'),
          ),
        );
        verifyNever(mockSecretStore.save(any));
        verifyNever(
          mockSecretUsageRepository.add(
            fingerprint: anyNamed('fingerprint'),
            consumer: anyNamed('consumer'),
          ),
        );
      },
    );

    test('should accept passphrase at exactly 256 characters', () async {
      // Arrange
      final maxPassphrase = 'a' * 256; // exactly 256 characters
      final command = CreateNewMnemonicSecretCommand.forWallet(
        walletId: 'wallet-123',
        passphrase: maxPassphrase,
      );

      when(
        mockMnemonicGenerator.generateMnemonic(),
      ).thenAnswer((_) async => testMnemonicWords);
      when(
        mockSecretCrypto.getFingerprintFromMnemonic(
          mnemonicWords: anyNamed('mnemonicWords'),
          passphrase: anyNamed('passphrase'),
        ),
      ).thenAnswer((_) => testFingerprint);
      when(mockSecretStore.save(any)).thenAnswer((_) async {
        return;
      });
      when(
        mockSecretUsageRepository.add(
          fingerprint: anyNamed('fingerprint'),
          consumer: anyNamed('consumer'),
        ),
      ).thenAnswer((_) async => _createTestSecretUsage());

      // Act
      final result = await useCase.execute(command);

      // Assert - should succeed with 256 chars
      expect(result.secret.passphrase?.value, maxPassphrase);
    });
  });

  group('CreateNewMnemonicSecretUseCase - Error Scenarios', () {
    test(
      'should throw FailedToCreateNewMnemonicSecretError when mnemonic generation fails',
      () async {
        // Arrange
        final command = CreateNewMnemonicSecretCommand.forWallet(
          walletId: 'wallet-123',
        );

        final generationError = Exception('RNG failure');
        when(
          mockMnemonicGenerator.generateMnemonic(),
        ).thenThrow(generationError);

        // Act & Assert
        expect(
          () => useCase.execute(command),
          throwsA(
            isA<FailedToCreateNewMnemonicSecretError>().having(
              (e) => e.cause,
              'cause',
              generationError,
            ),
          ),
        );

        // Verify no other ports were called
        verifyNever(
          mockSecretCrypto.getFingerprintFromMnemonic(
            mnemonicWords: anyNamed('mnemonicWords'),
            passphrase: anyNamed('passphrase'),
          ),
        );
        verifyNever(mockSecretStore.save(any));
        verifyNever(
          mockSecretUsageRepository.add(
            fingerprint: anyNamed('fingerprint'),
            consumer: anyNamed('consumer'),
          ),
        );
      },
    );

    test(
      'should throw BusinessRuleFailed when fingerprint calculation throws domain error',
      () async {
        // Arrange
        final command = CreateNewMnemonicSecretCommand.forWallet(
          walletId: 'wallet-123',
        );

        final domainError = TestSecretsDomainError('Invalid seed format');
        when(
          mockMnemonicGenerator.generateMnemonic(),
        ).thenAnswer((_) async => testMnemonicWords);
        when(
          mockSecretCrypto.getFingerprintFromMnemonic(
            mnemonicWords: anyNamed('mnemonicWords'),
            passphrase: anyNamed('passphrase'),
          ),
        ).thenThrow(domainError);

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
        verify(
          mockSecretCrypto.getFingerprintFromMnemonic(
            mnemonicWords: anyNamed('mnemonicWords'),
            passphrase: anyNamed('passphrase'),
          ),
        ).called(1);
        verifyNever(mockSecretStore.save(any));
        verifyNever(
          mockSecretUsageRepository.add(
            fingerprint: anyNamed('fingerprint'),
            consumer: anyNamed('consumer'),
          ),
        );
      },
    );

    test(
      'should throw FailedToCreateNewMnemonicSecretError when secret storage fails',
      () async {
        // Arrange
        final command = CreateNewMnemonicSecretCommand.forWallet(
          walletId: 'wallet-123',
        );

        final storageError = Exception('Secure storage unavailable');
        when(
          mockMnemonicGenerator.generateMnemonic(),
        ).thenAnswer((_) async => testMnemonicWords);
        when(
          mockSecretCrypto.getFingerprintFromMnemonic(
            mnemonicWords: anyNamed('mnemonicWords'),
            passphrase: anyNamed('passphrase'),
          ),
        ).thenAnswer((_) => testFingerprint);
        when(mockSecretStore.save(any)).thenThrow(storageError);

        // Act & Assert
        expect(
          () => useCase.execute(command),
          throwsA(
            isA<FailedToCreateNewMnemonicSecretError>().having(
              (e) => e.cause,
              'cause',
              storageError,
            ),
          ),
        );

        // Verify usage repository was not called
        verifyNever(
          mockSecretUsageRepository.add(
            fingerprint: anyNamed('fingerprint'),
            consumer: anyNamed('consumer'),
          ),
        );
      },
    );

    test(
      'should throw FailedToCreateNewMnemonicSecretError when usage repository add fails',
      () async {
        // Arrange
        final command = CreateNewMnemonicSecretCommand.forWallet(
          walletId: 'wallet-123',
        );

        final repositoryError = Exception('Database connection failed');
        when(
          mockMnemonicGenerator.generateMnemonic(),
        ).thenAnswer((_) async => testMnemonicWords);
        when(
          mockSecretCrypto.getFingerprintFromMnemonic(
            mnemonicWords: anyNamed('mnemonicWords'),
            passphrase: anyNamed('passphrase'),
          ),
        ).thenAnswer((_) => testFingerprint);
        when(mockSecretStore.save(any)).thenAnswer((_) async {
          return;
        });
        when(
          mockSecretUsageRepository.add(
            fingerprint: anyNamed('fingerprint'),
            consumer: anyNamed('consumer'),
          ),
        ).thenThrow(repositoryError);

        // Act & Assert
        await expectLater(
          () => useCase.execute(command),
          throwsA(
            isA<FailedToCreateNewMnemonicSecretError>().having(
              (e) => e.cause,
              'cause',
              repositoryError,
            ),
          ),
        );

        // Verify all steps up to repository were called
        verify(mockMnemonicGenerator.generateMnemonic()).called(1);
        verify(
          mockSecretCrypto.getFingerprintFromMnemonic(
            mnemonicWords: anyNamed('mnemonicWords'),
            passphrase: anyNamed('passphrase'),
          ),
        ).called(1);
        verify(mockSecretStore.save(any)).called(1);
      },
    );

    test('should rethrow application errors without wrapping', () async {
      // Arrange
      final command = CreateNewMnemonicSecretCommand.forWallet(
        walletId: 'wallet-123',
      );

      final appError = SecretInUseError('existing-fingerprint');
      when(
        mockMnemonicGenerator.generateMnemonic(),
      ).thenAnswer((_) async => testMnemonicWords);
      when(
        mockSecretCrypto.getFingerprintFromMnemonic(
          mnemonicWords: anyNamed('mnemonicWords'),
          passphrase: anyNamed('passphrase'),
        ),
      ).thenThrow(appError);

      // Act & Assert
      expect(
        () => useCase.execute(command),
        throwsA(
          isA<SecretInUseError>().having(
            (e) => e.fingerprint,
            'fingerprint',
            'existing-fingerprint',
          ),
        ),
      );
    });
  });

  group('CreateNewMnemonicSecretUseCase - Verification Tests', () {
    test('should call ports in correct sequence', () async {
      // Arrange
      final command = CreateNewMnemonicSecretCommand.forWallet(
        walletId: 'wallet-123',
      );

      final callOrder = <String>[];

      when(mockMnemonicGenerator.generateMnemonic()).thenAnswer((_) async {
        callOrder.add('generateMnemonic');
        return testMnemonicWords;
      });
      when(
        mockSecretCrypto.getFingerprintFromMnemonic(
          mnemonicWords: anyNamed('mnemonicWords'),
          passphrase: anyNamed('passphrase'),
        ),
      ).thenAnswer((_) {
        callOrder.add('getFingerprintFromMnemonic');
        return testFingerprint;
      });
      when(mockSecretStore.save(any)).thenAnswer((_) async {
        callOrder.add('save');
        return;
      });
      when(
        mockSecretUsageRepository.add(
          fingerprint: anyNamed('fingerprint'),
          consumer: anyNamed('consumer'),
        ),
      ).thenAnswer((_) async {
        callOrder.add('add');
        return _createTestSecretUsage();
      });

      // Act
      await useCase.execute(command);

      // Assert - verify exact order
      expect(callOrder, [
        'generateMnemonic',
        'getFingerprintFromMnemonic',
        'save',
        'add',
      ]);
    });

    test(
      'should pass correct SecretMnemonicSecret to getFingerprintFromMnemonic',
      () async {
        // Arrange
        const testPassphrase = 'my-passphrase';
        final command = CreateNewMnemonicSecretCommand.forWallet(
          walletId: 'wallet-123',
          passphrase: testPassphrase,
        );

        MnemonicWords? capturedWords;
        Passphrase? capturedPassphrase;
        when(
          mockMnemonicGenerator.generateMnemonic(),
        ).thenAnswer((_) async => testMnemonicWords);
        when(
          mockSecretCrypto.getFingerprintFromMnemonic(
            mnemonicWords: anyNamed('mnemonicWords'),
            passphrase: anyNamed('passphrase'),
          ),
        ).thenAnswer((invocation) {
          capturedWords =
              invocation.namedArguments[#mnemonicWords] as MnemonicWords?;
          capturedPassphrase =
              invocation.namedArguments[#passphrase] as Passphrase?;
          return testFingerprint;
        });
        when(mockSecretStore.save(any)).thenAnswer((_) async {
          return;
        });
        when(
          mockSecretUsageRepository.add(
            fingerprint: anyNamed('fingerprint'),
            consumer: anyNamed('consumer'),
          ),
        ).thenAnswer((_) async => _createTestSecretUsage());

        // Act
        await useCase.execute(command);

        // Assert
        expect(capturedWords, testMnemonicWords);
        expect(capturedPassphrase, isA<Passphrase>());
        expect(capturedPassphrase!.value, testPassphrase);
      },
    );

    test('should pass command properties correctly to repository', () async {
      // Arrange
      final command = CreateNewMnemonicSecretCommand.forBip85(
        bip85Path: "m/83696968'/1'/5'",
      );

      when(
        mockMnemonicGenerator.generateMnemonic(),
      ).thenAnswer((_) async => testMnemonicWords);
      when(
        mockSecretCrypto.getFingerprintFromMnemonic(
          mnemonicWords: anyNamed('mnemonicWords'),
          passphrase: anyNamed('passphrase'),
        ),
      ).thenAnswer((_) => testFingerprint);
      when(mockSecretStore.save(any)).thenAnswer((_) async {
        return;
      });
      when(
        mockSecretUsageRepository.add(
          fingerprint: anyNamed('fingerprint'),
          consumer: anyNamed('consumer'),
        ),
      ).thenAnswer((_) async => _createTestSecretUsage());

      // Act
      await useCase.execute(command);

      // Assert
      verify(
        mockSecretUsageRepository.add(
          fingerprint: testFingerprint,
          consumer: argThat(
            isA<Bip85Consumer>().having(
              (c) => c.bip85Path,
              'bip85Path',
              "m/83696968'/1'/5'",
            ),
            named: 'consumer',
          ),
        ),
      ).called(1);
    });

    test('should call each port exactly once in happy path', () async {
      // Arrange
      final command = CreateNewMnemonicSecretCommand.forWallet(
        walletId: 'wallet-123',
      );

      when(
        mockMnemonicGenerator.generateMnemonic(),
      ).thenAnswer((_) async => testMnemonicWords);
      when(
        mockSecretCrypto.getFingerprintFromMnemonic(
          mnemonicWords: anyNamed('mnemonicWords'),
          passphrase: anyNamed('passphrase'),
        ),
      ).thenAnswer((_) => testFingerprint);
      when(mockSecretStore.save(any)).thenAnswer((_) async {
        return;
      });
      when(
        mockSecretUsageRepository.add(
          fingerprint: anyNamed('fingerprint'),
          consumer: anyNamed('consumer'),
        ),
      ).thenAnswer((_) async => _createTestSecretUsage());

      // Act
      await useCase.execute(command);

      // Assert - verify exactly one call each
      verify(mockMnemonicGenerator.generateMnemonic()).called(1);
      verify(
        mockSecretCrypto.getFingerprintFromMnemonic(
          mnemonicWords: anyNamed('mnemonicWords'),
          passphrase: anyNamed('passphrase'),
        ),
      ).called(1);
      verify(mockSecretStore.save(any)).called(1);
      verify(
        mockSecretUsageRepository.add(
          fingerprint: anyNamed('fingerprint'),
          consumer: anyNamed('consumer'),
        ),
      ).called(1);

      // Verify no other interactions
      verifyNoMoreInteractions(mockMnemonicGenerator);
      verifyNoMoreInteractions(mockSecretCrypto);
      verifyNoMoreInteractions(mockSecretStore);
      verifyNoMoreInteractions(mockSecretUsageRepository);
    });

    test(
      'should return result with same fingerprint from crypto port',
      () async {
        // Arrange
        final customFingerprint = Fingerprint.fromHex('ffffffff');
        final command = CreateNewMnemonicSecretCommand.forWallet(
          walletId: 'wallet-123',
        );

        when(
          mockMnemonicGenerator.generateMnemonic(),
        ).thenAnswer((_) async => testMnemonicWords);
        when(
          mockSecretCrypto.getFingerprintFromMnemonic(
            mnemonicWords: anyNamed('mnemonicWords'),
            passphrase: anyNamed('passphrase'),
          ),
        ).thenAnswer((_) => customFingerprint);
        when(mockSecretStore.save(any)).thenAnswer((_) async {
          return;
        });
        when(
          mockSecretUsageRepository.add(
            fingerprint: anyNamed('fingerprint'),
            consumer: anyNamed('consumer'),
          ),
        ).thenAnswer((_) async => _createTestSecretUsage());

        // Act
        final result = await useCase.execute(command);

        // Assert
        expect(result.secret.fingerprint, customFingerprint);
      },
    );
  });
}

// Test helper function to create a test SecretUsage entity
SecretUsage _createTestSecretUsage() {
  return SecretUsage(
    id: SecretUsageId(1),
    fingerprint: Fingerprint.fromHex('12345678'),
    consumer: WalletConsumer('test-consumer'),
    createdAt: DateTime.now(),
  );
}
