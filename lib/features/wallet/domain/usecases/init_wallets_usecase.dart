import 'package:bb_mobile/features/wallet/data/repositories/bdk_wallet_repository.dart';
import 'package:bb_mobile/features/wallet/data/repositories/lwk_wallet_repository.dart';
import 'package:bb_mobile/features/wallet/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/features/wallet/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:get_it/get_it.dart';

class InitWalletsUseCase {
  final SeedRepository _seedRepository;
  final GetIt _getIt;

  InitWalletsUseCase({
    required SeedRepository seedRepository,
    required GetIt getIt,
  })  : _seedRepository = seedRepository,
        _getIt = getIt;

  Future<void> execute(List<WalletMetadata> walletsMetadata) async {
    for (final metadata in walletsMetadata) {
      // Fetch the seed for the wallet
      final seed = "";
      // TODO: await _seedRepository.getSeed(metadata.walletId);

      if (metadata.type == WalletType.bdk) {
        _getIt.registerLazySingleton<WalletRepository>(
          () => BdkWalletRepository(metadata: metadata, seed: seed),
          instanceName: metadata.id,
        );
      } else if (metadata.type == WalletType.lwk) {
        _getIt.registerLazySingleton<WalletRepository>(
          () => LwkWalletRepository(metadata: metadata, seed: seed),
          instanceName: metadata.id,
        );
      }
    }
  }
}
