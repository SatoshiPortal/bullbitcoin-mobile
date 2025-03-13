import 'package:bb_mobile/_core/domain/services/wallet_manager_service.dart';

class InitExistingWalletsUseCase {
  final WalletManagerService _walletManager;

  InitExistingWalletsUseCase({
    required WalletManagerService walletManager,
  }) : _walletManager = walletManager;

  Future<void> execute() async {
    await _walletManager.initExistingWallets();
  }
}
