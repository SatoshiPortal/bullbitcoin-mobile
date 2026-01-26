import 'package:bb_mobile/features/secrets/domain/entities/secret_entity.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/fingerprint.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/mnemonic_words.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/passphrase.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/secret_consumer.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/secret_usage_id.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_crypto_port.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_store_port.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_usage_repository_port.dart';
import 'package:bb_mobile/features/secrets/application/secrets_application_error.dart';
import 'package:bb_mobile/features/secrets/application/usecases/import_mnemonic_secret_usecase.dart';
import 'package:bb_mobile/features/secrets/domain/entities/secret_usage_entity.dart';
import 'package:bb_mobile/features/secrets/domain/secrets_domain_error.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'import_mnemonic_secret_usecase_test.mocks.dart';

@GenerateMocks([SecretCryptoPort, SecretStorePort, SecretUsageRepositoryPort])
void main() {
  late ImportMnemonicSecretUseCase useCase;
  late MockSecretCryptoPort mockSecretCrypto;
  late MockSecretStorePort mockSecretStore;
  late MockSecretUsageRepositoryPort mockSecretUsageRepository;

  final testFingerprint = Fingerprint('test-fingerprint-abc');
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
    mockSecretCrypto = MockSecretCryptoPort();
    mockSecretStore = MockSecretStorePort();
    mockSecretUsageRepository = MockSecretUsageRepositoryPort();

    useCase = ImportMnemonicSecretUseCase(
      secretCrypto: mockSecretCrypto,
      secretStore: mockSecretStore,
      secretUsageRepository: mockSecretUsageRepository,
    );
  });

  group('ImportMnemonicSecretUseCase - Happy Path', () {
    test('should successfully import secret without passphrase', () async {
      // Arrange
      final command = ImportMnemonicSecretCommand.forWallet(
        walletId: 'wallet-123',
        mnemonicWords: testMnemonicWords,
      );

      when(
        mockSecretCrypto.getFingerprintFromMnemonic(
          mnemonicWords: anyNamed('mnemonicWords'),
          passphrase: anyNamed('passphrase'),
        ),
      ).thenReturn(testFingerprint);
      when(mockSecretStore.save(any)).thenAnswer((_) async {
        return null;
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
      expect(result.fingerprint, testFingerprint);

      // Verify the secret was saved
      verify(
        mockSecretStore.save(argThat(
          isA<MnemonicSecret>()
              .having((s) => s.words.value, 'words', testMnemonicWords)
              .having((s) => s.passphrase, 'passphrase', isNull),
        )),
      ).called(1);

      verify(
        mockSecretUsageRepository.add(
          fingerprint: testFingerprint,
          consumer: argThat(
            isA<WalletConsumer>()
                .having((c) => c.walletId, 'walletId', 'wallet-123'),
            named: 'consumer',
          ),
        ),
      ).called(1);
    });

    test('should successfully import secret with passphrase', () async {
      // Arrange
      const testPassphrase = 'my-secret-passphrase';
      final command = ImportMnemonicSecretCommand.forBip85(
        bip85Path: "m/83696968'/0'/0'",
        mnemonicWords: testMnemonicWords,
        passphrase: testPassphrase,
      );

      when(
        mockSecretCrypto.getFingerprintFromMnemonic(
          mnemonicWords: anyNamed('mnemonicWords'),
          passphrase: anyNamed('passphrase'),
        ),
      ).thenReturn(testFingerprint);
      when(mockSecretStore.save(any)).thenAnswer((_) async {
        return null;
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
      expect(result.fingerprint, testFingerprint);

      verify(
        mockSecretStore.save(argThat(
          isA<MnemonicSecret>()
              .having((s) => s.words.value, 'words', testMnemonicWords)
              .having(
                (s) => s.passphrase?.value,
                'passphrase',
                testPassphrase,
              ),
        )),
      ).called(1);
    });
  });

  group('ImportMnemonicSecretUseCase - Input Validation', () {
    test(
      'should throw InvalidMnemonicInputError when word count is 11',
      () async {
        // Arrange
        final invalidMnemonic = List.generate(11, (i) => 'word$i');
        final command = ImportMnemonicSecretCommand.forWallet(
          walletId: 'wallet-123',
          mnemonicWords: invalidMnemonic,
        );

        // Act & Assert
        await expectLater(
          () => useCase.execute(command),
          throwsA(
            isA<InvalidMnemonicInputError>()
                .having((e) => e.wordCount, 'wordCount', 11)
                .having(
                  (e) => e.message,
                  'message',
                  contains('Invalid mnemonic'),
                ),
          ),
        );

        // Verify no ports were called (validation happens first)
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
      'should throw InvalidMnemonicInputError when word count is 13',
      () async {
        // Arrange
        final invalidMnemonic = List.generate(13, (i) => 'word$i');
        final command = ImportMnemonicSecretCommand.forWallet(
          walletId: 'wallet-123',
          mnemonicWords: invalidMnemonic,
        );

        // Act & Assert
        await expectLater(
          () => useCase.execute(command),
          throwsA(
            isA<InvalidMnemonicInputError>()
                .having((e) => e.wordCount, 'wordCount', 13)
                .having(
                  (e) => e.message,
                  'message',
                  contains('Invalid mnemonic'),
                ),
          ),
        );

        verifyNever(
          mockSecretCrypto.getFingerprintFromMnemonic(
            mnemonicWords: anyNamed('mnemonicWords'),
            passphrase: anyNamed('passphrase'),
          ),
        );
      },
    );

    test(
      'should throw InvalidMnemonicInputError when word count is 25',
      () async {
        // Arrange
        final invalidMnemonic = List.generate(25, (i) => 'word$i');
        final command = ImportMnemonicSecretCommand.forWallet(
          walletId: 'wallet-123',
          mnemonicWords: invalidMnemonic,
        );

        // Act & Assert
        await expectLater(
          () => useCase.execute(command),
          throwsA(
            isA<InvalidMnemonicInputError>()
                .having((e) => e.wordCount, 'wordCount', 25)
                .having(
                  (e) => e.message,
                  'message',
                  contains('Invalid mnemonic'),
                ),
          ),
        );

        verifyNever(
          mockSecretCrypto.getFingerprintFromMnemonic(
            mnemonicWords: anyNamed('mnemonicWords'),
            passphrase: anyNamed('passphrase'),
          ),
        );
      },
    );

    test(
      'should throw InvalidMnemonicInputError when word count is 1',
      () async {
        // Arrange
        final invalidMnemonic = ['word'];
        final command = ImportMnemonicSecretCommand.forWallet(
          walletId: 'wallet-123',
          mnemonicWords: invalidMnemonic,
        );

        // Act & Assert
        await expectLater(
          () => useCase.execute(command),
          throwsA(
            isA<InvalidMnemonicInputError>()
                .having((e) => e.wordCount, 'wordCount', 1)
                .having(
                  (e) => e.message,
                  'message',
                  contains('Invalid mnemonic'),
                ),
          ),
        );

        verifyNever(
          mockSecretCrypto.getFingerprintFromMnemonic(
            mnemonicWords: anyNamed('mnemonicWords'),
            passphrase: anyNamed('passphrase'),
          ),
        );
      },
    );

    test(
      'should throw InvalidMnemonicInputError when word count is 100',
      () async {
        // Arrange
        final invalidMnemonic = List.generate(100, (i) => 'word$i');
        final command = ImportMnemonicSecretCommand.forWallet(
          walletId: 'wallet-123',
          mnemonicWords: invalidMnemonic,
        );

        // Act & Assert
        await expectLater(
          () => useCase.execute(command),
          throwsA(
            isA<InvalidMnemonicInputError>()
                .having((e) => e.wordCount, 'wordCount', 100)
                .having(
                  (e) => e.message,
                  'message',
                  contains('Invalid mnemonic'),
                ),
          ),
        );

        verifyNever(
          mockSecretCrypto.getFingerprintFromMnemonic(
            mnemonicWords: anyNamed('mnemonicWords'),
            passphrase: anyNamed('passphrase'),
          ),
        );
      },
    );

    test(
      'should throw InvalidPassphraseInputError when passphrase is 257 characters',
      () async {
        // Arrange
        final longPassphrase = 'a' * 257;
        final command = ImportMnemonicSecretCommand.forWallet(
          walletId: 'wallet-123',
          mnemonicWords: testMnemonicWords,
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
      'should throw InvalidPassphraseInputError when passphrase is 300 characters',
      () async {
        // Arrange
        final longPassphrase = 'a' * 300;
        final command = ImportMnemonicSecretCommand.forWallet(
          walletId: 'wallet-123',
          mnemonicWords: testMnemonicWords,
          passphrase: longPassphrase,
        );

        // Act & Assert
        await expectLater(
          () => useCase.execute(command),
          throwsA(
            isA<InvalidPassphraseInputError>()
                .having((e) => e.length, 'length', 300)
                .having(
                  (e) => e.message,
                  'message',
                  contains('Passphrase too long'),
                ),
          ),
        );

        verifyNever(
          mockSecretCrypto.getFingerprintFromMnemonic(
            mnemonicWords: anyNamed('mnemonicWords'),
            passphrase: anyNamed('passphrase'),
          ),
        );
      },
    );

    test(
      'should accept passphrase at exactly 256 characters',
      () async {
        // Arrange
        final maxPassphrase = 'a' * 256;
        final command = ImportMnemonicSecretCommand.forWallet(
          walletId: 'wallet-123',
          mnemonicWords: testMnemonicWords,
          passphrase: maxPassphrase,
        );

        when(
          mockSecretCrypto.getFingerprintFromMnemonic(
            mnemonicWords: anyNamed('mnemonicWords'),
            passphrase: anyNamed('passphrase'),
          ),
        ).thenReturn(testFingerprint);
        when(mockSecretStore.save(any)).thenAnswer((_) async {
          return null;
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
        expect(result.fingerprint, testFingerprint);

        // Verify the passphrase was passed correctly
        verify(
          mockSecretStore.save(argThat(
            isA<MnemonicSecret>().having(
              (s) => s.passphrase?.value,
              'passphrase',
              maxPassphrase,
            ),
          )),
        ).called(1);
      },
    );
  });

  group('ImportMnemonicSecretUseCase - Error Scenarios', () {
    test(
      'should throw BusinessRuleFailed when fingerprint calculation throws domain error',
      () async {
        // Arrange
        final command = ImportMnemonicSecretCommand.forWallet(
          walletId: 'wallet-123',
          mnemonicWords: testMnemonicWords,
        );

        final domainError = TestSecretsDomainError('Invalid mnemonic');
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
            isA<BusinessRuleFailed>().having(
              (e) => e.domainError,
              'domainError',
              domainError,
            ),
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
      'should throw FailedToImportMnemonicSecretError when storage fails',
      () async {
        // Arrange
        final command = ImportMnemonicSecretCommand.forWallet(
          walletId: 'wallet-123',
          mnemonicWords: testMnemonicWords,
        );

        final storageError = Exception('Storage unavailable');
        when(
          mockSecretCrypto.getFingerprintFromMnemonic(
            mnemonicWords: anyNamed('mnemonicWords'),
            passphrase: anyNamed('passphrase'),
          ),
        ).thenReturn(testFingerprint);
        when(mockSecretStore.save(any)).thenThrow(storageError);

        // Act & Assert
        await expectLater(
          () => useCase.execute(command),
          throwsA(
            isA<FailedToImportMnemonicSecretError>().having(
              (e) => e.cause,
              'cause',
              storageError,
            ),
          ),
        );

        verifyNever(
          mockSecretUsageRepository.add(
            fingerprint: anyNamed('fingerprint'),
            consumer: anyNamed('consumer'),
          ),
        );
      },
    );

    test(
      'should throw FailedToImportMnemonicSecretError when repository add fails',
      () async {
        // Arrange
        final command = ImportMnemonicSecretCommand.forWallet(
          walletId: 'wallet-123',
          mnemonicWords: testMnemonicWords,
        );

        final repositoryError = Exception('Database error');
        when(
          mockSecretCrypto.getFingerprintFromMnemonic(
            mnemonicWords: anyNamed('mnemonicWords'),
            passphrase: anyNamed('passphrase'),
          ),
        ).thenReturn(testFingerprint);
        when(mockSecretStore.save(any)).thenAnswer((_) async {
          return null;
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
            isA<FailedToImportMnemonicSecretError>().having(
              (e) => e.cause,
              'cause',
              repositoryError,
            ),
          ),
        );
      },
    );

    test('should rethrow application errors without wrapping', () async {
      // Arrange
      final command = ImportMnemonicSecretCommand.forWallet(
        walletId: 'wallet-123',
        mnemonicWords: testMnemonicWords,
      );

      final appError = SecretInUseError('existing-fp');
      when(
        mockSecretCrypto.getFingerprintFromMnemonic(
          mnemonicWords: anyNamed('mnemonicWords'),
          passphrase: anyNamed('passphrase'),
        ),
      ).thenThrow(appError);

      // Act & Assert
      await expectLater(
        () => useCase.execute(command),
        throwsA(isA<SecretInUseError>()),
      );
    });
  });

  group('ImportMnemonicSecretUseCase - Verification Tests', () {
    test('should call ports in correct sequence', () async {
      // Arrange
      final command = ImportMnemonicSecretCommand.forWallet(
        walletId: 'wallet-123',
        mnemonicWords: testMnemonicWords,
      );

      final callOrder = <String>[];

      when(
        mockSecretCrypto.getFingerprintFromMnemonic(
          mnemonicWords: anyNamed('mnemonicWords'),
          passphrase: anyNamed('passphrase'),
        ),
      ).thenAnswer((
        _,
      ) {
        callOrder.add('getFingerprintFromMnemonic');
        return testFingerprint;
      });
      when(mockSecretStore.save(any)).thenAnswer((_) async {
        callOrder.add('save');
        return null;
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

      // Assert
      expect(callOrder, ['getFingerprintFromMnemonic', 'save', 'add']);
    });

    test('should call each port exactly once in happy path', () async {
      // Arrange
      final command = ImportMnemonicSecretCommand.forWallet(
        walletId: 'wallet-123',
        mnemonicWords: testMnemonicWords,
      );

      when(
        mockSecretCrypto.getFingerprintFromMnemonic(
          mnemonicWords: anyNamed('mnemonicWords'),
          passphrase: anyNamed('passphrase'),
        ),
      ).thenReturn(testFingerprint);
      when(mockSecretStore.save(any)).thenAnswer((_) async {
        return null;
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

      verifyNoMoreInteractions(mockSecretCrypto);
      verifyNoMoreInteractions(mockSecretStore);
      verifyNoMoreInteractions(mockSecretUsageRepository);
    });
  });
}

SecretUsage _createTestSecretUsage() {
  return SecretUsage(
    id: SecretUsageId(1),
    fingerprint: Fingerprint('test-fingerprint-abc'),
    consumer: WalletConsumer('test-consumer'),
    createdAt: DateTime.now(),
  );
}
