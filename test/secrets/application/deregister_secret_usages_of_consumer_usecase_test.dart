import 'package:bb_mobile/features/secrets/application/ports/secret_usage_repository_port.dart';
import 'package:bb_mobile/features/secrets/application/secrets_application_error.dart';
import 'package:bb_mobile/features/secrets/application/usecases/deregister_secret_usages_of_consumer_usecase.dart';
import 'package:bb_mobile/features/secrets/domain/secrets_domain_error.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/secret_consumer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'deregister_secret_usages_of_consumer_usecase_test.mocks.dart';

@GenerateMocks([SecretUsageRepositoryPort])
void main() {
  late DeregisterSecretUsagesOfConsumerUseCase useCase;
  late MockSecretUsageRepositoryPort mockSecretUsageRepository;

  // Test data
  const testWalletId = 'wallet-123';
  const testBip85Path = "m/83696968'/0'/0'";

  setUp(() {
    mockSecretUsageRepository = MockSecretUsageRepositoryPort();

    useCase = DeregisterSecretUsagesOfConsumerUseCase(
      secretUsageRepository: mockSecretUsageRepository,
    );
  });

  group('DeregisterSecretUsagesOfConsumerUseCase - Happy Path', () {
    test('should successfully deregister usages for WalletConsumer', () async {
      // Arrange
      final command = DeregisterSecretUsagesOfConsumerCommand.ofWallet(
        walletId: testWalletId,
      );

      when(mockSecretUsageRepository.deleteByConsumer(any))
          .thenAnswer((_) async {});

      // Act
      await useCase.execute(command);

      // Assert - verify port interactions
      final captured = verify(
        mockSecretUsageRepository.deleteByConsumer(captureAny),
      ).captured.single as SecretConsumer;
      expect(captured, isA<WalletConsumer>());
      expect((captured as WalletConsumer).walletId, testWalletId);
    });

    test('should successfully deregister usages for Bip85Consumer', () async {
      // Arrange
      final command = DeregisterSecretUsagesOfConsumerCommand.ofBip85(
        bip85Path: testBip85Path,
      );

      when(mockSecretUsageRepository.deleteByConsumer(any))
          .thenAnswer((_) async {});

      // Act
      await useCase.execute(command);

      // Assert - verify port interactions
      final captured = verify(
        mockSecretUsageRepository.deleteByConsumer(captureAny),
      ).captured.single as SecretConsumer;
      expect(captured, isA<Bip85Consumer>());
      expect((captured as Bip85Consumer).bip85Path, testBip85Path);
    });

    test('should succeed when no usages exist (idempotent)', () async {
      // Arrange
      final command = DeregisterSecretUsagesOfConsumerCommand.ofWallet(
        walletId: testWalletId,
      );

      // deleteByConsumer succeeds even if no records exist
      when(mockSecretUsageRepository.deleteByConsumer(any))
          .thenAnswer((_) async {});

      // Act
      await useCase.execute(command);

      // Assert - should complete successfully
      verify(mockSecretUsageRepository.deleteByConsumer(any)).called(1);
    });

    test('should handle different wallet IDs correctly', () async {
      // Arrange
      const wallet1 = 'wallet-first';
      const wallet2 = 'wallet-second';

      final command1 = DeregisterSecretUsagesOfConsumerCommand.ofWallet(
        walletId: wallet1,
      );
      final command2 = DeregisterSecretUsagesOfConsumerCommand.ofWallet(
        walletId: wallet2,
      );

      when(mockSecretUsageRepository.deleteByConsumer(any))
          .thenAnswer((_) async {});

      // Act
      await useCase.execute(command1);
      await useCase.execute(command2);

      // Assert
      final capturedConsumers = verify(
        mockSecretUsageRepository.deleteByConsumer(captureAny),
      ).captured;

      expect(capturedConsumers, hasLength(2));
      expect((capturedConsumers[0] as WalletConsumer).walletId, wallet1);
      expect((capturedConsumers[1] as WalletConsumer).walletId, wallet2);
    });

    test('should handle different BIP85 paths correctly', () async {
      // Arrange
      const path1 = "m/83696968'/0'/0'";
      const path2 = "m/83696968'/0'/1'";

      final command1 = DeregisterSecretUsagesOfConsumerCommand.ofBip85(
        bip85Path: path1,
      );
      final command2 = DeregisterSecretUsagesOfConsumerCommand.ofBip85(
        bip85Path: path2,
      );

      when(mockSecretUsageRepository.deleteByConsumer(any))
          .thenAnswer((_) async {});

      // Act
      await useCase.execute(command1);
      await useCase.execute(command2);

      // Assert
      final capturedConsumers = verify(
        mockSecretUsageRepository.deleteByConsumer(captureAny),
      ).captured;

      expect(capturedConsumers, hasLength(2));
      expect((capturedConsumers[0] as Bip85Consumer).bip85Path, path1);
      expect((capturedConsumers[1] as Bip85Consumer).bip85Path, path2);
    });

    test('should call deleteByConsumer exactly once', () async {
      // Arrange
      final command = DeregisterSecretUsagesOfConsumerCommand.ofWallet(
        walletId: testWalletId,
      );

      when(mockSecretUsageRepository.deleteByConsumer(any))
          .thenAnswer((_) async {});

      // Act
      await useCase.execute(command);

      // Assert - verify exactly one call
      verify(mockSecretUsageRepository.deleteByConsumer(any)).called(1);

      // Verify no other interactions
      verifyNoMoreInteractions(mockSecretUsageRepository);
    });
  });

  group('DeregisterSecretUsagesOfConsumerUseCase - Error Scenarios', () {
    test(
      'should throw BusinessRuleFailed when deleteByConsumer throws domain error',
      () async {
        // Arrange
        final command = DeregisterSecretUsagesOfConsumerCommand.ofWallet(
          walletId: testWalletId,
        );

        final domainError = TestSecretsDomainError('Invalid consumer format');
        when(mockSecretUsageRepository.deleteByConsumer(any))
            .thenThrow(domainError);

        // Act & Assert
        await expectLater(
          () => useCase.execute(command),
          throwsA(
            isA<BusinessRuleFailed>()
                .having((e) => e.domainError, 'domainError', domainError)
                .having((e) => e.cause, 'cause', domainError),
          ),
        );

        // Verify deleteByConsumer was called
        verify(mockSecretUsageRepository.deleteByConsumer(any)).called(1);
      },
    );

    test(
      'should throw FailedToDeregisterSecretUsagesOfConsumerError when deleteByConsumer fails',
      () async {
        // Arrange
        final command = DeregisterSecretUsagesOfConsumerCommand.ofWallet(
          walletId: testWalletId,
        );

        final repositoryError = Exception('Database deletion failed');
        when(mockSecretUsageRepository.deleteByConsumer(any))
            .thenThrow(repositoryError);

        // Act & Assert
        await expectLater(
          () => useCase.execute(command),
          throwsA(
            isA<FailedToDeregisterSecretUsagesOfConsumerError>()
                .having((e) => e.consumer, 'consumer', isA<WalletConsumer>())
                .having((e) => e.cause, 'cause', repositoryError),
          ),
        );

        // Verify deleteByConsumer was called
        verify(mockSecretUsageRepository.deleteByConsumer(any)).called(1);
      },
    );

    test(
      'should throw FailedToDeregisterSecretUsagesOfConsumerError with Bip85Consumer when command is ofBip85',
      () async {
        // Arrange
        final command = DeregisterSecretUsagesOfConsumerCommand.ofBip85(
          bip85Path: testBip85Path,
        );

        final repositoryError = Exception('Deletion operation failed');
        when(mockSecretUsageRepository.deleteByConsumer(any))
            .thenThrow(repositoryError);

        // Act & Assert
        await expectLater(
          () => useCase.execute(command),
          throwsA(
            isA<FailedToDeregisterSecretUsagesOfConsumerError>()
                .having((e) => e.consumer, 'consumer', isA<Bip85Consumer>())
                .having((e) => e.cause, 'cause', repositoryError),
          ),
        );
      },
    );

    test('should rethrow application errors without wrapping', () async {
      // Arrange
      final command = DeregisterSecretUsagesOfConsumerCommand.ofWallet(
        walletId: testWalletId,
      );

      final appError = SecretInUseError('test-fingerprint');
      when(mockSecretUsageRepository.deleteByConsumer(any))
          .thenThrow(appError);

      // Act & Assert
      await expectLater(
        () => useCase.execute(command),
        throwsA(
          isA<SecretInUseError>().having(
            (e) => e.fingerprint,
            'fingerprint',
            'test-fingerprint',
          ),
        ),
      );
    });

    test('should handle database connection errors', () async {
      // Arrange
      final command = DeregisterSecretUsagesOfConsumerCommand.ofWallet(
        walletId: testWalletId,
      );

      final connectionError = Exception('Database connection lost');
      when(mockSecretUsageRepository.deleteByConsumer(any))
          .thenThrow(connectionError);

      // Act & Assert
      await expectLater(
        () => useCase.execute(command),
        throwsA(
          isA<FailedToDeregisterSecretUsagesOfConsumerError>()
              .having((e) => e.cause, 'cause', connectionError),
        ),
      );
    });

    test('should handle timeout errors', () async {
      // Arrange
      final command = DeregisterSecretUsagesOfConsumerCommand.ofWallet(
        walletId: testWalletId,
      );

      final timeoutError = Exception('Operation timeout');
      when(mockSecretUsageRepository.deleteByConsumer(any))
          .thenThrow(timeoutError);

      // Act & Assert
      await expectLater(
        () => useCase.execute(command),
        throwsA(
          isA<FailedToDeregisterSecretUsagesOfConsumerError>()
              .having((e) => e.cause, 'cause', timeoutError),
        ),
      );
    });

    test(
      'should handle domain error thrown during consumer creation',
      () async {
        // Arrange - This tests the switch statement error handling
        final command = DeregisterSecretUsagesOfConsumerCommand.ofWallet(
          walletId: testWalletId,
        );

        final domainError = TestSecretsDomainError('Invalid wallet ID format');
        when(mockSecretUsageRepository.deleteByConsumer(any))
            .thenThrow(domainError);

        // Act & Assert
        await expectLater(
          () => useCase.execute(command),
          throwsA(isA<BusinessRuleFailed>()),
        );
      },
    );
  });

  group('DeregisterSecretUsagesOfConsumerUseCase - Verification Tests', () {
    test('should pass correct WalletConsumer to repository', () async {
      // Arrange
      const customWalletId = 'custom-wallet-xyz';
      final command = DeregisterSecretUsagesOfConsumerCommand.ofWallet(
        walletId: customWalletId,
      );

      when(mockSecretUsageRepository.deleteByConsumer(any))
          .thenAnswer((_) async {});

      // Act
      await useCase.execute(command);

      // Assert
      final captured = verify(
        mockSecretUsageRepository.deleteByConsumer(captureAny),
      ).captured.single as SecretConsumer;
      expect(captured, isA<WalletConsumer>());
      expect((captured as WalletConsumer).walletId, customWalletId);
    });

    test('should pass correct Bip85Consumer to repository', () async {
      // Arrange
      const customPath = "m/83696968'/1'/2'";
      final command = DeregisterSecretUsagesOfConsumerCommand.ofBip85(
        bip85Path: customPath,
      );

      when(mockSecretUsageRepository.deleteByConsumer(any))
          .thenAnswer((_) async {});

      // Act
      await useCase.execute(command);

      // Assert
      final captured = verify(
        mockSecretUsageRepository.deleteByConsumer(captureAny),
      ).captured.single as SecretConsumer;
      expect(captured, isA<Bip85Consumer>());
      expect((captured as Bip85Consumer).bip85Path, customPath);
    });

    test('should capture correct consumer in deletion call', () async {
      // Arrange
      const captureWalletId = 'capture-test-wallet';
      final command = DeregisterSecretUsagesOfConsumerCommand.ofWallet(
        walletId: captureWalletId,
      );

      SecretConsumer? capturedConsumer;
      when(mockSecretUsageRepository.deleteByConsumer(any))
          .thenAnswer((invocation) async {
        capturedConsumer = invocation.positionalArguments[0] as SecretConsumer;
      });

      // Act
      await useCase.execute(command);

      // Assert
      expect(capturedConsumer, isA<WalletConsumer>());
      expect(
        (capturedConsumer as WalletConsumer).walletId,
        captureWalletId,
      );
    });

    test('should handle consumer with special characters in wallet ID',
        () async {
      // Arrange
      const specialWalletId = 'wallet-!@#\$%^&*()_+-=[]{}|;:,.<>?';
      final command = DeregisterSecretUsagesOfConsumerCommand.ofWallet(
        walletId: specialWalletId,
      );

      when(mockSecretUsageRepository.deleteByConsumer(any))
          .thenAnswer((_) async {});

      // Act
      await useCase.execute(command);

      // Assert
      final captured = verify(
        mockSecretUsageRepository.deleteByConsumer(captureAny),
      ).captured.single as WalletConsumer;
      expect(captured.walletId, specialWalletId);
    });

    test('should handle consumer with unicode characters in BIP85 path',
        () async {
      // Arrange
      const unicodePath = "m/83696968'/0'/测试'";
      final command = DeregisterSecretUsagesOfConsumerCommand.ofBip85(
        bip85Path: unicodePath,
      );

      when(mockSecretUsageRepository.deleteByConsumer(any))
          .thenAnswer((_) async {});

      // Act
      await useCase.execute(command);

      // Assert
      final captured = verify(
        mockSecretUsageRepository.deleteByConsumer(captureAny),
      ).captured.single as Bip85Consumer;
      expect(captured.bip85Path, unicodePath);
    });

    test('should handle empty wallet ID', () async {
      // Arrange
      const emptyWalletId = '';
      final command = DeregisterSecretUsagesOfConsumerCommand.ofWallet(
        walletId: emptyWalletId,
      );

      when(mockSecretUsageRepository.deleteByConsumer(any))
          .thenAnswer((_) async {});

      // Act
      await useCase.execute(command);

      // Assert
      final captured = verify(
        mockSecretUsageRepository.deleteByConsumer(captureAny),
      ).captured.single as WalletConsumer;
      expect(captured.walletId, emptyWalletId);
    });

    test('should handle very long wallet ID', () async {
      // Arrange
      final longWalletId = 'wallet-' + 'x' * 1000;
      final command = DeregisterSecretUsagesOfConsumerCommand.ofWallet(
        walletId: longWalletId,
      );

      when(mockSecretUsageRepository.deleteByConsumer(any))
          .thenAnswer((_) async {});

      // Act
      await useCase.execute(command);

      // Assert
      final captured = verify(
        mockSecretUsageRepository.deleteByConsumer(captureAny),
      ).captured.single as WalletConsumer;
      expect(captured.walletId, longWalletId);
      expect(captured.walletId.length, 1007); // 'wallet-' + 1000 'x's
    });
  });

  group('DeregisterSecretUsagesOfConsumerUseCase - Command Type Tests', () {
    test('should correctly distinguish between command types', () async {
      // Arrange
      final walletCommand = DeregisterSecretUsagesOfConsumerCommand.ofWallet(
        walletId: testWalletId,
      );
      final bip85Command = DeregisterSecretUsagesOfConsumerCommand.ofBip85(
        bip85Path: testBip85Path,
      );

      when(mockSecretUsageRepository.deleteByConsumer(any))
          .thenAnswer((_) async {});

      // Act
      await useCase.execute(walletCommand);
      await useCase.execute(bip85Command);

      // Assert
      final capturedConsumers = verify(
        mockSecretUsageRepository.deleteByConsumer(captureAny),
      ).captured;

      expect(capturedConsumers, hasLength(2));
      expect(capturedConsumers[0], isA<WalletConsumer>());
      expect(capturedConsumers[1], isA<Bip85Consumer>());
    });

    test('should handle command switching correctly', () async {
      // Arrange
      when(mockSecretUsageRepository.deleteByConsumer(any))
          .thenAnswer((_) async {});

      // Act - Execute multiple commands in sequence
      await useCase.execute(
        DeregisterSecretUsagesOfConsumerCommand.ofWallet(
          walletId: 'wallet-1',
        ),
      );
      await useCase.execute(
        DeregisterSecretUsagesOfConsumerCommand.ofBip85(
          bip85Path: "m/83696968'/0'/0'",
        ),
      );
      await useCase.execute(
        DeregisterSecretUsagesOfConsumerCommand.ofWallet(
          walletId: 'wallet-2',
        ),
      );

      // Assert
      final capturedConsumers = verify(
        mockSecretUsageRepository.deleteByConsumer(captureAny),
      ).captured;

      expect(capturedConsumers, hasLength(3));
      expect(capturedConsumers[0], isA<WalletConsumer>());
      expect((capturedConsumers[0] as WalletConsumer).walletId, 'wallet-1');
      expect(capturedConsumers[1], isA<Bip85Consumer>());
      expect(
        (capturedConsumers[1] as Bip85Consumer).bip85Path,
        "m/83696968'/0'/0'",
      );
      expect(capturedConsumers[2], isA<WalletConsumer>());
      expect((capturedConsumers[2] as WalletConsumer).walletId, 'wallet-2');
    });

    test('should handle multiple deletions for same consumer type', () async {
      // Arrange
      when(mockSecretUsageRepository.deleteByConsumer(any))
          .thenAnswer((_) async {});

      final walletIds = ['wallet-a', 'wallet-b', 'wallet-c'];

      // Act
      for (final walletId in walletIds) {
        await useCase.execute(
          DeregisterSecretUsagesOfConsumerCommand.ofWallet(
            walletId: walletId,
          ),
        );
      }

      // Assert
      final capturedConsumers = verify(
        mockSecretUsageRepository.deleteByConsumer(captureAny),
      ).captured;

      expect(capturedConsumers, hasLength(3));
      for (int i = 0; i < walletIds.length; i++) {
        expect(capturedConsumers[i], isA<WalletConsumer>());
        expect(
          (capturedConsumers[i] as WalletConsumer).walletId,
          walletIds[i],
        );
      }
    });
  });

  group(
      'DeregisterSecretUsagesOfConsumerUseCase - Idempotency and Edge Cases',
      () {
    test('should be idempotent - multiple calls should succeed', () async {
      // Arrange
      final command = DeregisterSecretUsagesOfConsumerCommand.ofWallet(
        walletId: testWalletId,
      );

      when(mockSecretUsageRepository.deleteByConsumer(any))
          .thenAnswer((_) async {});

      // Act - Call multiple times
      await useCase.execute(command);
      await useCase.execute(command);
      await useCase.execute(command);

      // Assert - all calls should succeed
      verify(mockSecretUsageRepository.deleteByConsumer(any)).called(3);
    });

    test('should handle concurrent execution gracefully', () async {
      // Arrange
      final commands = [
        DeregisterSecretUsagesOfConsumerCommand.ofWallet(
          walletId: 'wallet-1',
        ),
        DeregisterSecretUsagesOfConsumerCommand.ofWallet(
          walletId: 'wallet-2',
        ),
        DeregisterSecretUsagesOfConsumerCommand.ofBip85(
          bip85Path: "m/83696968'/0'/0'",
        ),
      ];

      when(mockSecretUsageRepository.deleteByConsumer(any))
          .thenAnswer((_) async {
        // Simulate some async delay
        await Future.delayed(Duration(milliseconds: 10));
      });

      // Act - Execute concurrently
      await Future.wait(commands.map((cmd) => useCase.execute(cmd)));

      // Assert
      verify(mockSecretUsageRepository.deleteByConsumer(any)).called(3);
    });

    test('should not interfere with other consumers when deleting', () async {
      // Arrange
      final wallet1Command = DeregisterSecretUsagesOfConsumerCommand.ofWallet(
        walletId: 'wallet-1',
      );
      final wallet2Command = DeregisterSecretUsagesOfConsumerCommand.ofWallet(
        walletId: 'wallet-2',
      );

      final capturedConsumers = <SecretConsumer>[];
      when(mockSecretUsageRepository.deleteByConsumer(any))
          .thenAnswer((invocation) async {
        capturedConsumers.add(invocation.positionalArguments[0] as SecretConsumer);
      });

      // Act - Execute both commands
      await useCase.execute(wallet1Command);
      await useCase.execute(wallet2Command);

      // Assert - both consumers should be deleted in separate calls
      expect(capturedConsumers, hasLength(2));
      expect(capturedConsumers[0], isA<WalletConsumer>());
      expect((capturedConsumers[0] as WalletConsumer).walletId, 'wallet-1');
      expect(capturedConsumers[1], isA<WalletConsumer>());
      expect((capturedConsumers[1] as WalletConsumer).walletId, 'wallet-2');

      // Verify the repository was called twice
      verify(mockSecretUsageRepository.deleteByConsumer(any)).called(2);
    });
  });
}
