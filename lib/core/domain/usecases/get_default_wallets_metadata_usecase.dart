import 'package:bb_mobile/core/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/core/domain/repositories/wallet_metadata_repository.dart';

class GetDefaultWalletsMetadataUseCase {
  final WalletMetadataRepository _walletMetadataRepository;

  GetDefaultWalletsMetadataUseCase(
      {required WalletMetadataRepository walletMetadataRepository})
      : _walletMetadataRepository = walletMetadataRepository;

  Future<List<WalletMetadata>> execute() async {
    final wallets = await _walletMetadataRepository.getAllWalletsMetadata();

    // TODO: filter for default wallets, add a flag to metadata for this

    return wallets;
  }
}
