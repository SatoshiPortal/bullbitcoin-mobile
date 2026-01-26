import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/secrets/domain/entities/secret_usage_entity.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/fingerprint.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/secret_consumer.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/secret_usage_id.dart';

enum SecretConsumerType { wallet, bip85 }

extension SecretUsageRowMappersX on SecretUsageRow {
  SecretUsage toDomain() {
    final consumer = switch (consumerType) {
      SecretConsumerType.wallet => WalletConsumer(walletId!),
      SecretConsumerType.bip85 => Bip85Consumer(bip85Path!),
    };
    return SecretUsage(
      id: SecretUsageId(id),
      consumer: consumer,
      fingerprint: Fingerprint.fromHex(fingerprint),
      createdAt: createdAt,
    );
  }
}

extension SecretUsageMappersX on SecretUsage {
  SecretUsageRow toRow() {
    final consumerType = switch (consumer) {
      WalletConsumer() => SecretConsumerType.wallet,
      Bip85Consumer() => SecretConsumerType.bip85,
    };
    final walletId = switch (consumer) {
      WalletConsumer c => c.walletId,
      Bip85Consumer() => null,
    };
    final bip85Path = switch (consumer) {
      Bip85Consumer c => c.bip85Path,
      WalletConsumer() => null,
    };
    return SecretUsageRow(
      id: id.value,
      consumerType: consumerType,
      fingerprint: fingerprint.value,
      walletId: walletId,
      bip85Path: bip85Path,
      createdAt: createdAt,
    );
  }
}
