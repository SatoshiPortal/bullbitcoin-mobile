import 'package:bb_mobile/core/seed/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/core/settings/domain/entity/settings.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/bip85_derivation.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';
import 'package:flutter/foundation.dart';

class CreateBackupKeyFromDefaultSeedUsecase {
  final SeedRepository _seed;
  final WalletRepository _wallet;

  CreateBackupKeyFromDefaultSeedUsecase({
    required SeedRepository seedRepository,
    required WalletRepository walletRepository,
  })  : _seed = seedRepository,
        _wallet = walletRepository;

  Future<String> execute(String derivationPath) async {
    try {
      // The default wallet is used to derive the backup key
      final defaultWallets = await _wallet.getWallets(
        onlyDefaults: true,
        onlyBitcoin: true,
        environment: Environment.mainnet,
        sync: false,
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

      final backupKey =
          Bip85Derivation.deriveBackupKey(defaultXprv, derivationPath);

      return backupKey;
    } catch (e) {
      debugPrint('$CreateBackupKeyFromDefaultSeedUsecase: $e');
      throw CreateBackupKeyFromDefaultSeedException(e.toString());
    }
  }
}

class CreateBackupKeyFromDefaultSeedException implements Exception {
  final String message;

  CreateBackupKeyFromDefaultSeedException(this.message);
}
