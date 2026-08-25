import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/app_startup/domain/app_startup_wallet_port.dart';

final class WalletStartupAdapter implements AppStartupWalletPort {
  final WalletRepository _walletRepository;

  const WalletStartupAdapter(this._walletRepository);

  @override
  Future<bool> hasMainnetBitcoinEncryptedBackup() async {
    final wallets = await _walletRepository.getWallets(
      onlyDefaults: true,
      onlyBitcoin: true,
      environment: Environment.mainnet,
    );
    return wallets.isNotEmpty && wallets.first.latestEncryptedBackup != null;
  }

  @override
  Future<bool> hasTestedRecoverBullBackup() async {
    final wallets = await _walletRepository.getWallets(
      onlyDefaults: true,
      onlyBitcoin: true,
      environment: Environment.mainnet,
    );
    return wallets.any((wallet) => wallet.isEncryptedVaultTested);
  }
}
