import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';

class CheckTorRequiredOnStartupUsecase {
  final WalletRepository _wallet;

  CheckTorRequiredOnStartupUsecase({required WalletRepository walletRepository})
    : _wallet = walletRepository;

  Future<bool> execute() async {
    try {
      final defaultWallets = await _wallet.getWallets(
        onlyDefaults: true,
        onlyBitcoin: true,
        environment: Environment.mainnet,
      );

      if (defaultWallets.isEmpty) return false;

      return defaultWallets[0].latestEncryptedBackup != null;
    } catch (e) {
      log.severe('CheckTorRequiredOnStartupUsecase: $e');
      return false;
    }
  }
}
