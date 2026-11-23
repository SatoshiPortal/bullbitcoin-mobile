import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/wallet/data/wallet_registrations.dart';
import 'package:bb_mobile/features/wallet/data/wallet_sync_binding.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

final class MemoryWalletRegistrations implements WalletRegistrations {
  final Map<String, WalletMetadataModel> rows = {};

  @override
  Future<void> insert(WalletMetadataModel metadata) async {
    if (rows.containsKey(metadata.id)) {
      throw WalletAlreadyExistsException(metadata.id);
    }
    rows[metadata.id] = metadata;
  }

  @override
  Future<WalletMetadataModel?> fetch(String id) async => rows[id];

  @override
  Future<List<WalletMetadataModel>> fetchAll() async => rows.values.toList();

  @override
  Future<void> delete(String id) async => rows.remove(id);

  @override
  Future<void> recordBackup(WalletMetadataModel metadata) async {
    rows[metadata.id] = metadata;
  }

  @override
  Future<void> recordSyncTime(String id, DateTime time) async {
    final metadata = rows[id];
    if (metadata != null) rows[id] = metadata.copyWith(syncedAt: time);
  }
}

final class TestWalletCatalog implements WalletCatalogPort {
  final WalletRegistrations registrations;

  TestWalletCatalog(this.registrations);

  @override
  Future<Result<List<PublicWalletDescriptor>, SyncFailure>> list() async {
    try {
      final result = <PublicWalletDescriptor>[];
      for (final row in await registrations.fetchAll()) {
        if (WalletSyncBinding.descriptorFromMetadata(row) case Ok(
          :final value,
        )) {
          result.add(value);
        }
      }
      return Ok(List.unmodifiable(result));
    } on Exception {
      return const Err(SyncStorageFailure());
    }
  }

  @override
  Future<Result<PublicWalletDescriptor, SyncFailure>> find(
    WalletKey key,
  ) async {
    try {
      final row = await registrations.fetch(key.id);
      if (row == null) return const Err(SyncNotFoundFailure());
      final result = WalletSyncBinding.descriptorFromMetadata(row);
      if (result case Ok(:final value) when value.key != key) {
        return const Err(SyncNotFoundFailure());
      }
      return result;
    } on Exception {
      return const Err(SyncStorageFailure());
    }
  }
}
