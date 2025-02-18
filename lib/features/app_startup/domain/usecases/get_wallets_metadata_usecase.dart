import 'package:bb_mobile/core/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/core/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/core/domain/repositories/wallet_metadata_repository.dart';

class GetWalletsMetadataUseCase {
  // Todo: add final EnvironmentRepository _environmentRepository;
  final WalletMetadataRepository _walletMetadataRepository;
  final SeedRepository _seedRepository;

  GetWalletsMetadataUseCase({
    required WalletMetadataRepository walletMetadataRepository,
    required SeedRepository seedRepository,
  })  : _walletMetadataRepository = walletMetadataRepository,
        _seedRepository = seedRepository;

  Future<List<WalletMetadata>> execute(
      /*{
    Environment environment = Environment.mainnet,
  }*/
      ) async {
    // TODO: filter by environment, maybe by a query parameter in the repo instead of here
    final wallets = await _walletMetadataRepository.getAllWalletsMetadata();
    final usableWallets = <WalletMetadata>[];

    for (final wallet in wallets) {
      switch (wallet.source) {
        case WalletSource.mnemonic:
          // We need to check if the seed exists for the mnemonic wallet so we are
          //  sure the creation went right and the wallet is usable
          final hasSeed =
              await _seedRepository.hasSeed(wallet.masterFingerprint);
          if (hasSeed) {
            usableWallets.add(wallet);
          }
        case WalletSource.descriptors:
          // Descriptors are required fields and thus included in the wallet
          //  metadata, so nothing else needed to be usable
          usableWallets.add(wallet);
        case WalletSource.xpub:
          // xpub is a required field and thus included in the wallet metadata,
          //  so nothing else needed to be usable
          usableWallets.add(wallet);
        case WalletSource.coldcard:
          // TODO: check if any other data is needed for a Coldcard wallet to be
          //  usable
          usableWallets.add(wallet);
      }
    }

    return usableWallets;
  }
}
