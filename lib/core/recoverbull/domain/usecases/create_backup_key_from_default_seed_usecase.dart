import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/recoverbull_bip85.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';

class CreateBackupKeyFromDefaultSeedUsecase {
  final SeedRepository _seed;
  final WalletRepository _wallet;

  CreateBackupKeyFromDefaultSeedUsecase({
    required SeedRepository seedRepository,
    required WalletRepository walletRepository,
  }) : _seed = seedRepository,
       _wallet = walletRepository;

  Future<String> execute(String derivationPath) async {
    try {
      // The default wallet is used to derive the backup key
      final defaultWallets = await _wallet.getWallets(
        onlyDefaults: true,
        onlyBitcoin: true,
        environment: Environment.mainnet,
      );

      if (defaultWallets.isEmpty) {
        throw Exception('No default wallet found');
      }

      final defaultWallet = defaultWallets[0];
      final defaultFingerprint = defaultWallet.masterFingerprint;
      final defaultSeed = await _seed.get(defaultFingerprint);

      final defaultXprv = Bip32Derivation.getXprvFromSeed(
        defaultSeed.bytes,
        defaultWallet.network,
      );

      final backupKey = RecoverbullBip85Utils.deriveBackupKey(
        defaultXprv,
        derivationPath,
      );

      return backupKey;
    } catch (e) {
      log.severe('$CreateBackupKeyFromDefaultSeedUsecase: $e');
      throw CreateBackupKeyFromDefaultSeedException(e.toString());
    }
  }
}

class CreateBackupKeyFromDefaultSeedException implements Exception {
  final String message;

  CreateBackupKeyFromDefaultSeedException(this.message);
}
