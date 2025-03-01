import 'package:bb_mobile/_core/domain/services/wallet_manager.dart';

class CheckForExistingDefaultWalletsUseCase {
  final WalletManager _walletManager;

  CheckForExistingDefaultWalletsUseCase({
    required WalletManager walletManager,
  }) : _walletManager = walletManager;

  Future<bool> execute() async {
    return _walletManager.doDefaultWalletsExist();
  }
}
