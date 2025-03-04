import 'package:bb_mobile/_core/data/datasources/wallet_metadata_data_source.dart';
import 'package:bb_mobile/_core/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/_core/domain/entities/seed.dart';
import 'package:bb_mobile/_core/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/_core/domain/repositories/wallet_metadata_repository.dart';

class WalletMetadataRepositoryImpl implements WalletMetadataRepository {
  final WalletMetadataDataSource _source;

  WalletMetadataRepositoryImpl({required WalletMetadataDataSource source})
      : _source = source;

  @override
  Future<WalletMetadata> deriveFromSeed({
    required Seed seed,
    required Network network,
    required ScriptType scriptType,
    String label = '',
    bool isDefault = true,
  }) async {
    final model = await _source.deriveFromSeed(
      seed: seed,
      network: network,
      scriptType: scriptType,
      label: label,
      isDefault: isDefault,
    );

    return model.toEntity();
  }

  @override
  Future<WalletMetadata> deriveFromXpub({
    required String xpub,
    required Network network,
    required ScriptType scriptType,
    String label = '',
  }) async {
    final model = await _source.deriveFromXpub(
      xpub: xpub,
      network: network,
      scriptType: scriptType,
      label: label,
    );

    return model.toEntity();
  }

  @override
  Future<void> store(WalletMetadata metadata) async {
    final model = WalletMetadataModel.fromEntity(metadata);
    return _source.store(model);
  }

  @override
  Future<WalletMetadata?> get(String walletId) async {
    final model = await _source.get(walletId);
    if (model == null) {
      return null;
    }
    return model.toEntity();
  }

  @override
  Future<List<WalletMetadata>> getAll() async {
    final models = await _source.getAll();
    return Future.value(models.map((e) => e.toEntity()).toList());
  }

  @override
  Future<void> delete(String walletId) {
    return _source.delete(walletId);
  }
}
