import 'package:bb_mobile/_core/domain/repositories/wallet_manager_repository.dart';

class InitExistingWalletsUseCase {
  final WalletManagerRepository _walletManager;

  InitExistingWalletsUseCase({
    required WalletManagerRepository walletManager,
  }) : _walletManager = walletManager;

  Future<void> execute() async {
    await _walletManager.initExistingWallets();
  }
}
