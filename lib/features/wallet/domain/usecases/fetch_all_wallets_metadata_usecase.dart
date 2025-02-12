import 'package:bb_mobile/features/wallet/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/features/wallet/domain/repositories/wallet_metadata_repository.dart';

class FetchAllWalletsMetadataUseCase {
  final WalletMetadataRepository _walletMetadataRepository;

  FetchAllWalletsMetadataUseCase({
    required WalletMetadataRepository walletMetadataRepository,
  }) : _walletMetadataRepository = walletMetadataRepository;

  Future<List<WalletMetadata>> execute() async {
    //final wallets = await _walletMetadataRepository.getAllWallets();
    // TODO: filter by network environment, maybe by a query parameter in the repo instead of here

    return [];
  }
}
