import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';

class CheckForTorInitializationOnStartupUsecase {
  final WalletRepository _wallet;

  CheckForTorInitializationOnStartupUsecase({
    required WalletRepository walletRepository,
  }) : _wallet = walletRepository;

  Future<bool> execute() async {
    try {
      final defaultWallets = await _wallet.getWallets(
        onlyDefaults: true,
        onlyBitcoin: true,
        environment: Environment.mainnet,
      );

      if (defaultWallets.isEmpty) {
        return false;
      }

      return defaultWallets[0].latestEncryptedBackup != null;
    } catch (e) {
      // Handle any exceptions that may occur
      return false;
    }
  }
}
