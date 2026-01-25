import 'package:bb_mobile/features/secrets/application/ports/secret_usage_repository_port.dart';
import 'package:bb_mobile/features/secrets/application/secrets_application_error.dart';
import 'package:bb_mobile/features/secrets/domain/entities/secret_usage_entity.dart';
import 'package:bb_mobile/features/secrets/domain/secrets_domain_error.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/secret_consumer.dart';

sealed class GetSecretUsagesByConsumerQuery {
  const GetSecretUsagesByConsumerQuery();

  const factory GetSecretUsagesByConsumerQuery.byWallet({
    required String walletId,
  }) = GetSecretUsagesByWalletConsumerQuery;

  const factory GetSecretUsagesByConsumerQuery.byBip85({
    required String bip85Path,
  }) = GetSecretUsagesByBip85ConsumerQuery;
}

class GetSecretUsagesByWalletConsumerQuery
    extends GetSecretUsagesByConsumerQuery {
  final String walletId;

  const GetSecretUsagesByWalletConsumerQuery({required this.walletId});
}

class GetSecretUsagesByBip85ConsumerQuery
    extends GetSecretUsagesByConsumerQuery {
  final String bip85Path;

  const GetSecretUsagesByBip85ConsumerQuery({required this.bip85Path});
}

class GetSecretUsagesByConsumerResult {
  final List<SecretUsage> usages;

  GetSecretUsagesByConsumerResult({required this.usages});
}

class GetSecretUsagesByConsumerUseCase {
  final SecretUsageRepositoryPort _secretUsageRepository;

  GetSecretUsagesByConsumerUseCase({
    required SecretUsageRepositoryPort secretUsageRepository,
  }) : _secretUsageRepository = secretUsageRepository;

  Future<GetSecretUsagesByConsumerResult> execute(
    GetSecretUsagesByConsumerQuery query,
  ) async {
    SecretConsumer? consumer;
    try {
      // Check the query inputs
      consumer = switch (query) {
        GetSecretUsagesByWalletConsumerQuery c => WalletConsumer(c.walletId),
        GetSecretUsagesByBip85ConsumerQuery c => Bip85Consumer(c.bip85Path),
      };

      final usages = await _secretUsageRepository.getByConsumer(consumer);

      return GetSecretUsagesByConsumerResult(usages: usages);
    } on SecretsDomainError catch (e) {
      // Map domain errors to application errors
      // For now just wrap all in a generic business rule failed
      throw BusinessRuleFailed(e);
    } on SecretsApplicationError {
      rethrow;
    } catch (e) {
      throw FailedToGetSecretUsagesByConsumerError(
        consumer: consumer,
        cause: e,
      );
    }
  }
}
