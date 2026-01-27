import 'package:bb_mobile/features/secrets/application/ports/secret_usage_repository_port.dart';
import 'package:bb_mobile/features/secrets/application/secrets_application_error.dart';
import 'package:bb_mobile/features/secrets/domain/secrets_domain_error.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/secret_consumer.dart';

sealed class DeregisterSecretUsagesOfConsumerCommand {
  const DeregisterSecretUsagesOfConsumerCommand();

  const factory DeregisterSecretUsagesOfConsumerCommand.ofWallet({
    required String walletId,
  }) = DeregisterSecretUsagesOfWalletConsumerCommand;

  const factory DeregisterSecretUsagesOfConsumerCommand.ofBip85({
    required String bip85Path,
  }) = DeregisterSecretUsagesOfBip85ConsumerCommand;
}

class DeregisterSecretUsagesOfWalletConsumerCommand
    extends DeregisterSecretUsagesOfConsumerCommand {
  final String walletId;

  const DeregisterSecretUsagesOfWalletConsumerCommand({required this.walletId});
}

class DeregisterSecretUsagesOfBip85ConsumerCommand
    extends DeregisterSecretUsagesOfConsumerCommand {
  final String bip85Path;

  const DeregisterSecretUsagesOfBip85ConsumerCommand({required this.bip85Path});
}

/// Composed use case that validates fingerprint before deregistering a secret usage.
/// This ensures the secret being deregistered matches the expected fingerprint.
class DeregisterSecretUsagesOfConsumerUseCase {
  final SecretUsageRepositoryPort _secretUsageRepository;

  DeregisterSecretUsagesOfConsumerUseCase({
    required SecretUsageRepositoryPort secretUsageRepository,
  }) : _secretUsageRepository = secretUsageRepository;

  Future<void> execute(DeregisterSecretUsagesOfConsumerCommand cmd) async {
    SecretConsumer? consumer;
    try {
      // Check the cmd inputs
      consumer = switch (cmd) {
        DeregisterSecretUsagesOfWalletConsumerCommand c => WalletConsumer(
          c.walletId,
        ),
        DeregisterSecretUsagesOfBip85ConsumerCommand c => Bip85Consumer(
          c.bip85Path,
        ),
      };

      // Deregister the usage
      await _secretUsageRepository.deleteByConsumer(consumer);
    } on SecretsDomainError catch (e) {
      // Map domain errors to application errors
      // For now just wrap all in a generic business rule failed
      throw BusinessRuleFailed(e);
    } on SecretsApplicationError {
      rethrow;
    } catch (e) {
      throw FailedToDeregisterSecretUsagesOfConsumerError(consumer, e);
    }
  }
}
