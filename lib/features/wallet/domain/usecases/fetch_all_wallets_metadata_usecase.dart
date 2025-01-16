import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/wallet/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/features/wallet/domain/repositories/wallet_metadata_repository.dart';

class FetchAllWalletsMetadataUseCase {
  final WalletMetadataRepository _walletMetadataRepository;

  FetchAllWalletsMetadataUseCase({
    required WalletMetadataRepository walletMetadataRepository,
  }) : _walletMetadataRepository = walletMetadataRepository;

  Future<List<WalletMetadata>> execute() async {
    final models = <WalletMetadataModel>[];
    // TODO: await _walletMetadataRepository.getAllWallets();
    return models.map((model) => model.toDomain()).toList();
  }
}
