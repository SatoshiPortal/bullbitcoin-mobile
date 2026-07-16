import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_backup_wallet.dart';

final class KeychainManifestBackupWalletAdapter
    implements KeychainManifestBackupWalletPort {
  final GetSettingsUsecase getSettings;
  final WalletRepository wallets;
  final SeedRepository seeds;

  const KeychainManifestBackupWalletAdapter({
    required this.getSettings,
    required this.wallets,
    required this.seeds,
  });

  @override
  Future<KeychainManifestBackupWallet> deriveDefaultWallet() async {
    final settings = await getSettings.execute();
    final defaults = await wallets.getWallets(
      environment: settings.environment,
      onlyDefaults: true,
      onlyBitcoin: true,
    );
    if (defaults.length != 1) {
      throw StateError('backup requires exactly one default wallet');
    }
    final wallet = defaults.single;
    final seed = await seeds.get(wallet.masterFingerprint);
    return KeychainManifestBackupWallet(
      xprvBase58: Bip32Derivation.getXprvFromSeed(seed.bytes, wallet.network),
      parentFingerprint: wallet.masterFingerprint,
    );
  }
}
