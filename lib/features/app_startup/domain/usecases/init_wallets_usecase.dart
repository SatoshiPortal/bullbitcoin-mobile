
import 'package:bb_mobile/core/wallet/domain/services/wallet_manager_service.dart';

class InitExistingWalletsUsecase {
  final WalletManagerService _walletManager;

  InitExistingWalletsUsecase({
    required WalletManagerService walletManager,
  }) : _walletManager = walletManager;

  Future<void> execute() async {
    try {
      await _walletManager.initExistingWallets();
    } catch (e) {
      throw InitExistingWalletsException(e.toString());
    }
  }
}

class InitExistingWalletsException implements Exception {
  final String message;

  InitExistingWalletsException(this.message);
}
