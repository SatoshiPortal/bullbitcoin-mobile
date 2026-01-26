import 'dart:typed_data';

import 'package:bb_mobile/features/secrets/domain/entities/secret_entity.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/fingerprint.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/secret_consumer.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/secret_usage_id.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_crypto_port.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_store_port.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_usage_repository_port.dart';
import 'package:bb_mobile/features/secrets/application/secrets_application_error.dart';
import 'package:bb_mobile/features/secrets/application/usecases/import_seed_secret_usecase.dart';
import 'package:bb_mobile/features/secrets/domain/entities/secret_usage_entity.dart';
import 'package:bb_mobile/features/secrets/domain/secrets_domain_error.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'import_seed_secret_usecase_test.mocks.dart';

@GenerateMocks([SecretCryptoPort, SecretStorePort, SecretUsageRepositoryPort])
void main() {
  late ImportSeedSecretUseCase useCase;
  late MockSecretCryptoPort mockSecretCrypto;
  late MockSecretStorePort mockSecretStore;
  late MockSecretUsageRepositoryPort mockSecretUsageRepository;

  final testFingerprint = Fingerprint.fromHex('deadbeef');
  final testSecretBytes = Uint8List.fromList(
    List.generate(32, (index) => index),
  );

  setUp(() {
    mockSecretCrypto = MockSecretCryptoPort();
    mockSecretStore = MockSecretStorePort();
    mockSecretUsageRepository = MockSecretUsageRepositoryPort();

    useCase = ImportSeedSecretUseCase(
      secretCrypto: mockSecretCrypto,
      secretStore: mockSecretStore,
      secretUsageRepository: mockSecretUsageRepository,
    );
  });

  group('ImportSeedSecretUseCase - Happy Path', () {
    test('should successfully import seed from bytes', () async {
      // Arrange
      final command = ImportSeedSecretCommand.forWallet(
        walletId: 'wallet-456',
        bytes: testSecretBytes,
      );

      when(
        mockSecretCrypto.getFingerprintFromSeedBytes(any),
      ).thenReturn(testFingerprint);
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
      expect(result.fingerprint, testFingerprint);

      verify(
        mockSecretStore.save(
          argThat(
            isA<SeedSecret>().having(
              (s) => s.bytes.value,
              'bytes',
              testSecretBytes,
            ),
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
              'wallet-456',
            ),
            named: 'consumer',
          ),
        ),
      ).called(1);
    });
  });

  group('ImportSeedSecretUseCase - Input Validation', () {
    test('should throw InvalidSeedInputError when byte length is 15', () async {
      // Arrange
      final invalidBytes = Uint8List.fromList(List.generate(15, (i) => i));
      final command = ImportSeedSecretCommand.forWallet(
        walletId: 'wallet-456',
        bytes: invalidBytes,
      );

      // Act & Assert
      await expectLater(
        () => useCase.execute(command),
        throwsA(
          isA<InvalidSeedInputError>()
              .having((e) => e.byteLength, 'byteLength', 15)
              .having(
                (e) => e.message,
                'message',
                contains('Invalid seed length'),
              ),
        ),
      );

      // Verify no ports were called (validation happens first)
      verifyNever(mockSecretCrypto.getFingerprintFromSeedBytes(any));
      verifyNever(mockSecretStore.save(any));
      verifyNever(
        mockSecretUsageRepository.add(
          fingerprint: anyNamed('fingerprint'),
          consumer: anyNamed('consumer'),
        ),
      );
    });

    test('should throw InvalidSeedInputError when byte length is 17', () async {
      // Arrange
      final invalidBytes = Uint8List.fromList(List.generate(17, (i) => i));
      final command = ImportSeedSecretCommand.forWallet(
        walletId: 'wallet-456',
        bytes: invalidBytes,
      );

      // Act & Assert
      await expectLater(
        () => useCase.execute(command),
        throwsA(
          isA<InvalidSeedInputError>()
              .having((e) => e.byteLength, 'byteLength', 17)
              .having(
                (e) => e.message,
                'message',
                contains('Invalid seed length'),
              ),
        ),
      );

      verifyNever(mockSecretCrypto.getFingerprintFromSeedBytes(any));
    });

    test('should throw InvalidSeedInputError when byte length is 31', () async {
      // Arrange
      final invalidBytes = Uint8List.fromList(List.generate(31, (i) => i));
      final command = ImportSeedSecretCommand.forWallet(
        walletId: 'wallet-456',
        bytes: invalidBytes,
      );

      // Act & Assert
      await expectLater(
        () => useCase.execute(command),
        throwsA(
          isA<InvalidSeedInputError>()
              .having((e) => e.byteLength, 'byteLength', 31)
              .having(
                (e) => e.message,
                'message',
                contains('Invalid seed length'),
              ),
        ),
      );

      verifyNever(mockSecretCrypto.getFingerprintFromSeedBytes(any));
    });

    test('should throw InvalidSeedInputError when byte length is 33', () async {
      // Arrange
      final invalidBytes = Uint8List.fromList(List.generate(33, (i) => i));
      final command = ImportSeedSecretCommand.forWallet(
        walletId: 'wallet-456',
        bytes: invalidBytes,
      );

      // Act & Assert
      await expectLater(
        () => useCase.execute(command),
        throwsA(
          isA<InvalidSeedInputError>()
              .having((e) => e.byteLength, 'byteLength', 33)
              .having(
                (e) => e.message,
                'message',
                contains('Invalid seed length'),
              ),
        ),
      );

      verifyNever(mockSecretCrypto.getFingerprintFromSeedBytes(any));
    });

    test('should throw InvalidSeedInputError when byte length is 63', () async {
      // Arrange
      final invalidBytes = Uint8List.fromList(List.generate(63, (i) => i));
      final command = ImportSeedSecretCommand.forWallet(
        walletId: 'wallet-456',
        bytes: invalidBytes,
      );

      // Act & Assert
      await expectLater(
        () => useCase.execute(command),
        throwsA(
          isA<InvalidSeedInputError>()
              .having((e) => e.byteLength, 'byteLength', 63)
              .having(
                (e) => e.message,
                'message',
                contains('Invalid seed length'),
              ),
        ),
      );

      verifyNever(mockSecretCrypto.getFingerprintFromSeedBytes(any));
    });

    test('should throw InvalidSeedInputError when byte length is 65', () async {
      // Arrange
      final invalidBytes = Uint8List.fromList(List.generate(65, (i) => i));
      final command = ImportSeedSecretCommand.forWallet(
        walletId: 'wallet-456',
        bytes: invalidBytes,
      );

      // Act & Assert
      await expectLater(
        () => useCase.execute(command),
        throwsA(
          isA<InvalidSeedInputError>()
              .having((e) => e.byteLength, 'byteLength', 65)
              .having(
                (e) => e.message,
                'message',
                contains('Invalid seed length'),
              ),
        ),
      );

      verifyNever(mockSecretCrypto.getFingerprintFromSeedBytes(any));
    });

    test('should throw InvalidSeedInputError when byte length is 1', () async {
      // Arrange
      final invalidBytes = Uint8List.fromList([0]);
      final command = ImportSeedSecretCommand.forWallet(
        walletId: 'wallet-456',
        bytes: invalidBytes,
      );

      // Act & Assert
      await expectLater(
        () => useCase.execute(command),
        throwsA(
          isA<InvalidSeedInputError>()
              .having((e) => e.byteLength, 'byteLength', 1)
              .having(
                (e) => e.message,
                'message',
                contains('Invalid seed length'),
              ),
        ),
      );

      verifyNever(mockSecretCrypto.getFingerprintFromSeedBytes(any));
    });

    test(
      'should throw InvalidSeedInputError when byte length is 100',
      () async {
        // Arrange
        final invalidBytes = Uint8List.fromList(List.generate(100, (i) => i));
        final command = ImportSeedSecretCommand.forWallet(
          walletId: 'wallet-456',
          bytes: invalidBytes,
        );

        // Act & Assert
        await expectLater(
          () => useCase.execute(command),
          throwsA(
            isA<InvalidSeedInputError>()
                .having((e) => e.byteLength, 'byteLength', 100)
                .having(
                  (e) => e.message,
                  'message',
                  contains('Invalid seed length'),
                ),
          ),
        );

        verifyNever(mockSecretCrypto.getFingerprintFromSeedBytes(any));
      },
    );
  });

  group('ImportSeedSecretUseCase - Error Scenarios', () {
    test(
      'should throw BusinessRuleFailed when fingerprint calculation throws domain error',
      () async {
        // Arrange
        final command = ImportSeedSecretCommand.forWallet(
          walletId: 'wallet-456',
          bytes: testSecretBytes,
        );

        final domainError = TestSecretsDomainError('Invalid seed bytes');
        when(
          mockSecretCrypto.getFingerprintFromSeedBytes(any),
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
      },
    );

    test('should throw FailedToImportSeedError when storage fails', () async {
      // Arrange
      final command = ImportSeedSecretCommand.forWallet(
        walletId: 'wallet-456',
        bytes: testSecretBytes,
      );

      final storageError = Exception('Storage unavailable');
      when(
        mockSecretCrypto.getFingerprintFromSeedBytes(any),
      ).thenReturn(testFingerprint);
      when(mockSecretStore.save(any)).thenThrow(storageError);

      // Act & Assert
      await expectLater(
        () => useCase.execute(command),
        throwsA(
          isA<FailedToImportSeedSecretError>().having(
            (e) => e.cause,
            'cause',
            storageError,
          ),
        ),
      );
    });

    test(
      'should throw FailedToImportSeedSecretError when repository add fails',
      () async {
        // Arrange
        final command = ImportSeedSecretCommand.forWallet(
          walletId: 'wallet-456',
          bytes: testSecretBytes,
        );

        final repositoryError = Exception('Database error');
        when(
          mockSecretCrypto.getFingerprintFromSeedBytes(any),
        ).thenReturn(testFingerprint);
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
            isA<FailedToImportSeedSecretError>().having(
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
      final command = ImportSeedSecretCommand.forWallet(
        walletId: 'wallet-456',
        bytes: testSecretBytes,
      );

      final appError = SecretInUseError('existing-fp');
      when(
        mockSecretCrypto.getFingerprintFromSeedBytes(any),
      ).thenThrow(appError);

      // Act & Assert
      await expectLater(
        () => useCase.execute(command),
        throwsA(isA<SecretInUseError>()),
      );
    });
  });

  group('ImportSecretBytesUseCase - Verification Tests', () {
    test('should call ports in correct sequence', () async {
      // Arrange
      final command = ImportSeedSecretCommand.forWallet(
        walletId: 'wallet-456',
        bytes: testSecretBytes,
      );

      final callOrder = <String>[];

      when(mockSecretCrypto.getFingerprintFromSeedBytes(any)).thenAnswer((_) {
        callOrder.add('getFingerprintFromSeedBytes');
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

      // Assert
      expect(callOrder, ['getFingerprintFromSeedBytes', 'save', 'add']);
    });
  });
}

SecretUsage _createTestSecretUsage() {
  return SecretUsage(
    id: SecretUsageId(1),
    fingerprint: Fingerprint.fromHex('deadbeef'),
    consumer: WalletConsumer('test-consumer'),
    createdAt: DateTime.now(),
  );
}
