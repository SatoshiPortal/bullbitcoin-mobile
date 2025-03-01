import 'package:bb_mobile/_core/domain/services/wallet_manager.dart';

class InitExistingWalletsUseCase {
  final WalletManager _walletManager;

  InitExistingWalletsUseCase({
    required WalletManager walletManager,
  }) : _walletManager = walletManager;

  Future<void> execute() async {
    await _walletManager.initExistingWallets();
  }
}
