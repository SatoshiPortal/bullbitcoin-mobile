import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/recoverbull_bip85.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';

class BackupKeyService {
  final SeedRepository _seedRepository;
  final WalletRepository _walletRepository;

  BackupKeyService({
    required SeedRepository seedRepository,
    required WalletRepository walletRepository,
  }) : _seedRepository = seedRepository,
       _walletRepository = walletRepository;

  Future<String> deriveBackupKeyFromDefaultSeed({required String? path}) async {
    try {
      if (path == null) throw 'Missing bip85 path';

      final defaultWallets = await _walletRepository.getWallets(
        onlyDefaults: true,
        onlyBitcoin: true,
        environment: Environment.mainnet,
      );

      if (defaultWallets.isEmpty) {
        throw 'No default Bitcoin wallet found';
      }

      final defaultWallet = defaultWallets.first;
      final defaultSeed = await _seedRepository.get(
        defaultWallet.masterFingerprint,
      );
      final xprv = Bip32Derivation.getXprvFromSeed(
        defaultSeed.bytes,
        defaultWallet.network,
      );

      return RecoverbullBip85Utils.deriveBackupKey(xprv, path);
    } catch (e) {
      throw BackupKeyServiceException(e.toString());
    }
  }
}

class BackupKeyServiceException implements Exception {
  final String message;

  BackupKeyServiceException(this.message);
}
