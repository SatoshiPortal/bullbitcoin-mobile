import 'dart:convert';

import 'package:bb_mobile/core/data/datasources/key_value_storage_data_source.dart';
import 'package:bb_mobile/core/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/core/domain/repositories/wallet_metadata_repository.dart';

class HiveWalletMetadataRepositoryImpl implements WalletMetadataRepository {
  final KeyValueStorageDataSource<String> _storage;

  const HiveWalletMetadataRepositoryImpl(this._storage);

  @override
  Future<void> storeWalletMetadata(WalletMetadata metadata) async {
    final model = WalletMetadataModel.fromEntity(metadata);
    final value = jsonEncode(model.toJson());
    await _storage.saveValue(key: metadata.id, value: value);
  }

  @override
  Future<WalletMetadata?> getWalletMetadata(String walletId) async {
    final value = await _storage.getValue(walletId);

    if (value == null) {
      return null;
    }

    final json = jsonDecode(value) as Map<String, dynamic>;
    final model = WalletMetadataModel.fromJson(json);
    final metadata = model.toEntity();

    return metadata;
  }

  @override
  Future<List<WalletMetadata>> getAllWalletsMetadata() async {
    final map = await _storage.getAll();

    return map.values
        .map((value) => jsonDecode(value) as Map<String, dynamic>)
        .map((json) => WalletMetadataModel.fromJson(json).toEntity())
        .toList();
  }

  @override
  Future<void> deleteWalletMetadata(String walletId) {
    return _storage.deleteValue(walletId);
  }
}
