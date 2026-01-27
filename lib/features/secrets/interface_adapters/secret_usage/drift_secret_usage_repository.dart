import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_usage_repository_port.dart';
import 'package:bb_mobile/features/secrets/domain/entities/secret_usage_entity.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/fingerprint.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/secret_consumer.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/secret_usage_id.dart';
import 'package:bb_mobile/features/secrets/interface_adapters/secret_usage/secret_usage_mappers.dart';
import 'package:drift/drift.dart';

class DriftSecretUsageRepository implements SecretUsageRepositoryPort {
  final SqliteDatabase _database;

  DriftSecretUsageRepository({required SqliteDatabase database})
    : _database = database;

  @override
  Future<SecretUsage> add({
    required Fingerprint fingerprint,
    required SecretConsumer consumer,
  }) async {
    final consumerType = switch (consumer) {
      WalletConsumer() => SecretConsumerType.wallet,
      Bip85Consumer() => SecretConsumerType.bip85,
    };
    final seedUsageRow = await _database.managers.secretUsages.createReturning(
      (o) => o(
        fingerprint: fingerprint.value,
        consumerType: consumerType,
        walletId: consumer is WalletConsumer
            ? Value(consumer.walletId)
            : Value.absent(),
        bip85Path: consumer is Bip85Consumer
            ? Value(consumer.bip85Path)
            : Value.absent(),
      ),
    );

    return seedUsageRow.toDomain();
  }

  @override
  Future<bool> isUsed(Fingerprint fingerprint) async {
    final count = await _database.managers.secretUsages
        .filter((f) => f.fingerprint(fingerprint.value))
        .count();

    return count > 0;
  }

  @override
  Future<List<SecretUsage>> getByConsumer(SecretConsumer consumer) async {
    final consumerType = switch (consumer) {
      WalletConsumer() => SecretConsumerType.wallet,
      Bip85Consumer() => SecretConsumerType.bip85,
    };
    final walletId = consumer is WalletConsumer ? consumer.walletId : null;
    final bip85Path = consumer is Bip85Consumer ? consumer.bip85Path : null;

    final row = await _database.managers.secretUsages
        .filter(
          (f) =>
              f.consumerType(consumerType) &
              f.walletId(walletId) &
              f.bip85Path(bip85Path),
        )
        .get();
    return row.map((r) => r.toDomain()).toList();
  }

  @override
  Future<List<SecretUsage>> getAll() async {
    final rows = await _database.managers.secretUsages.get();
    return rows.map((row) => row.toDomain()).toList();
  }

  @override
  Future<void> deleteById(SecretUsageId id) async {
    await _database.managers.secretUsages
        .filter((f) => f.id(id.value))
        .delete();
  }

  @override
  Future<void> deleteByConsumer(SecretConsumer consumer) {
    final consumerType = switch (consumer) {
      WalletConsumer() => SecretConsumerType.wallet,
      Bip85Consumer() => SecretConsumerType.bip85,
    };
    final walletId = consumer is WalletConsumer ? consumer.walletId : null;
    final bip85Path = consumer is Bip85Consumer ? consumer.bip85Path : null;

    return _database.managers.secretUsages
        .filter(
          (f) =>
              f.consumerType(consumerType) &
              f.walletId(walletId) &
              f.bip85Path(bip85Path),
        )
        .delete();
  }
}
